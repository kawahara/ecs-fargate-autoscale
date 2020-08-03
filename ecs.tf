resource "aws_ecr_repository" "repository" {
  name = "my-sample-app/${terraform.workspace}/server"
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "repository" {
  repository = aws_ecr_repository.repository.name
  policy     = <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Keep last 30 images",
            "selection": {
                "tagStatus": "any",
                "countType": "imageCountMoreThan",
                "countNumber": 30
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
}

resource "aws_ecs_cluster" "cluster" {
  name = "my-sample-app-${terraform.workspace}"
  capacity_providers = [
    "FARGATE",
    "FARGATE_SPOT"
  ]
  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = var.ecs_cluster.fargate_weight
  }
  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = var.ecs_cluster.fargate_spot_weight
  }
}

resource "aws_iam_role" "execution" {
  name = "execution"
  path = "/my-sample-app/${terraform.workspace}/ecs/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ExecutionRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "ecs_get_ssm" {
  statement {
    sid = "KSMDecrypt"
    actions = [
      "kms:Decrypt"
    ]
    resources = [
      var.ssm_kms_arn
    ]
  }

  statement {
    sid = "SSMGetParameters"
    actions = [
      "ssm:GetParameters"
    ]
    resources = [
      "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/my-sample-app/${terraform.workspace}/*"
    ]
  }
}

resource "aws_iam_policy" "ecs_execution_ssm" {
  name        = "my-sample-app-execution-ssm-${terraform.workspace}"
  description = "read permission to fetch ssm secret params"
  policy      = data.aws_iam_policy_document.ecs_get_ssm.json
}

resource "aws_iam_role_policy_attachment" "ecs_execution_ssm" {
  role       = aws_iam_role.execution.name
  policy_arn = aws_iam_policy.ecs_execution_ssm.arn
}

data "template_file" "container_definition" {
  template = file("./my-sample-app-task.json")

  vars = {
    env            = terraform.workspace
    image          = aws_ecr_repository.repository.repository_url
    aws_region     = data.aws_region.current.name
    aws_account_id = data.aws_caller_identity.current.account_id
  }
}

resource "aws_ecs_task_definition" "task" {
  family             = "my-sample-app-${terraform.workspace}"
  execution_role_arn = aws_iam_role.execution.arn
  # task_role_arn            = aws_iam_role.task.arn
  cpu                      = var.ecs_task.cpu
  memory                   = var.ecs_task.memory
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  container_definitions    = data.template_file.container_definition.rendered
}

resource "aws_ecs_service" "service" {
  name            = "my-sample-app-${terraform.workspace}"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.task.arn
  desired_count   = 0

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = var.ecs_cluster.fargate_weight
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = var.ecs_cluster.fargate_spot_weight
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.target.arn
    container_name   = "my-sample-app-${terraform.workspace}"
    container_port   = 80
  }

  network_configuration {
    subnets = [
      aws_subnet.pri_1.id,
      aws_subnet.pri_2.id,
    ]

    security_groups = [
      aws_security_group.app.id,
    ]
  }

  depends_on = [
    aws_alb.alb,
  ]

  lifecycle {
    ignore_changes = [
      desired_count,
      task_definition,
      # NOTE: https://github.com/terraform-providers/terraform-provider-aws/issues/11351
      capacity_provider_strategy
    ]
  }
}

resource "aws_appautoscaling_target" "ecs" {
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = var.ecs_autoscale.min
  max_capacity       = var.ecs_autoscale.max
}

resource "aws_appautoscaling_policy" "out" {
  name               = "my-sample-app-out-${terraform.workspace}"
  resource_id        = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.service.name}"
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 300
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = 1
    }
  }

  depends_on = [aws_appautoscaling_target.ecs]
}

resource "aws_appautoscaling_policy" "in" {
  name               = "my-sample-app-in-${terraform.workspace}"
  resource_id        = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.service.name}"
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 300
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = -1
    }
  }

  depends_on = [aws_appautoscaling_target.ecs]
}

resource "aws_cloudwatch_metric_alarm" "out" {
  alarm_name          = "my-sample-app-${terraform.workspace}-ecs-cpu-gt-75"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "75"

  dimensions = {
    ClusterName = aws_ecs_cluster.cluster.name
    ServiceName = aws_ecs_service.service.name
  }

  alarm_actions = [aws_appautoscaling_policy.out.arn]
}

resource "aws_cloudwatch_metric_alarm" "in" {
  alarm_name          = "my-sample-app-${terraform.workspace}-ecs-cpu-lt-25"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "25"

  dimensions = {
    ClusterName = aws_ecs_cluster.cluster.name
    ServiceName = aws_ecs_service.service.name
  }

  alarm_actions = [aws_appautoscaling_policy.in.arn]
}

