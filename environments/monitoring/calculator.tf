### ECR
module "ecr-calculator" {
  source   = "git::https://github.com/keepmycloudcom/modules-ecr.git?ref=v1.0.0"
  basename = local.basename
  names    = ["calculator"]
  tags     = local.base_tags
}

module "task-calculator" {
  source                    = "git::https://github.com/keepmycloudcom/modules-ecs.git//task?ref=v1.0.0"
  aws_region                = var.aws_region
  project_env               = var.project_env
  basename                  = local.basename
  name                      = "calculator"
  task_container_image      = "${var.aws_account}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.project_name}-${var.project_env}-calculator:${var.project_env}-2"
  container_name            = "calculator"
  task_definition_cpu       = 128
  task_definition_memory    = 128
  docker_labels = {
    "SERVICE_NAME" = "calculator"
  }
  network_mode = "bridge"
  task_environment = [
    {
      name  = "AWS_DEFAULT_REGION"
      value = "${var.aws_region}"
    },
    {
      name  = "CLIENT_RATE"
      value = "7.2"
    },
    {
      name  = "TAXES"
      value = "0.2"
    },
    {
      name  = "UPDATE_PERIOD"
      value = "43200"
    },
    {
      name  = "PORT"
      value = "8000"
  }]

  volume = {
    calculator = {
      name = "calculator"
      docker_volume_configuration = [{
        scope         = "shared"
        autoprovision = true
        driver        = "local"
      }]
    }
  }
  task_mount_points = [
    {
      containerPath = "/root/.calculator"
      readOnly      = false
      sourceVolume  = "calculator"
  }]
  tags = local.base_tags
}

# Service
module "service-calculator" {
  source      = "git::https://github.com/keepmycloudcom/modules-ecs.git//service?ref=v1.0.0"
  aws_region  = var.aws_region
  project_env = var.project_env

  name                = "calculator"
  ecs_cluster         = module.ecs.id
  container_name      = "calculator"
  scheduling_strategy = "DAEMON"
  ecs_desired_count   = 1
  ecs_task_definition = module.task-calculator.arn

  tags = local.base_tags
}

resource "aws_iam_role_policy_attachment" "calculator_billing_access" {
  role       = module.task-calculator.task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSBillingReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "calculator_ecs_access" {
  role       = module.task-calculator.task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonECS_FullAccess"
}