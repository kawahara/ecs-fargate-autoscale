resource "aws_alb" "alb" {
  name            = "my-sample-app-${terraform.workspace}"
  security_groups = [aws_security_group.alb.id]

  subnets = [
    aws_subnet.pub_1.id,
    aws_subnet.pub_2.id,
  ]

  internal                   = false
  enable_deletion_protection = false
}

resource "aws_alb_target_group" "target" {
  name        = "my-sample-app-${terraform.workspace}"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc.id
  target_type = "ip"

  health_check {
    path = "/"
  }
}

resource "aws_alb_listener" "http" {
  load_balancer_arn = aws_alb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.target.arn
    type             = "forward"
  }
}
