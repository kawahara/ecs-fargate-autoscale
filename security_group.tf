resource "aws_security_group" "alb" {
  name        = "my-sample-app-alb-${terraform.workspace}"
  description = "security rule for ALB"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name = "my-sample-app-alb-${terraform.workspace}"
  }
}

resource "aws_security_group_rule" "alb_in" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_out" {
  type                     = "egress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = aws_security_group.alb.id
  source_security_group_id = aws_security_group.app.id
}

resource "aws_security_group" "app" {
  name        = "my-sample-app-app-${terraform.workspace}"
  description = "security rule for APP"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name = "my-sample-app-app-${terraform.workspace}"
  }
}

resource "aws_security_group_rule" "app_in" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = aws_security_group.app.id
  source_security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "app_out" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.app.id
}

