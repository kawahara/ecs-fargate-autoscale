variable "vpc" {
  type = object({
    cidr       = string
    az1        = string
    az2        = string
    pub_1_cidr = string
    pub_2_cidr = string
    pri_1_cidr = string
    pri_2_cidr = string
  })
  default = {
    cidr       = "10.1.0.0/16"
    az1        = "ap-northeast-1a"
    az2        = "ap-northeast-1c"
    pub_1_cidr = "10.1.192.0/26"
    pub_2_cidr = "10.1.192.64/26"
    pri_1_cidr = "10.1.132.0/24"
    pri_2_cidr = "10.1.133.0/24"
  }
}


variable "ecs_cluster" {
  type = object({
    fargate_weight      = number
    fargate_spot_weight = number
  })
  default = {
    fargate_weight      = 1
    fargate_spot_weight = 1
  }
}

variable "ssm_kms_arn" {
  type = string
}

variable "ecs_task" {
  type = object({
    cpu    = number
    memory = number
  })
  default = {
    cpu    = 256
    memory = 512
  }
}

variable "ecs_autoscale" {
  type = object({
    min = number
    max = number
  })
  default = {
    min = 2
    max = 4
  }
}

