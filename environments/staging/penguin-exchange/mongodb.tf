module "task-mongodb" {
  source                    = "git::https://github.com/keepmycloudcom/modules-ecs.git//task?ref=v1.0.0"
  aws_region                = var.aws_region
  project_env               = var.project_env
  cloudwatch_log_group_name = "/${var.project_env}/${var.project_name}/mongodb"
  basename                  = local.basename
  name                      = "mongodb"
  task_container_image      = "mongo:latest"
  container_name            = "mongodb"
  task_definition_cpu       = 1000
  task_definition_memory    = 1000
  network_mode              = "bridge"
  docker_labels = {
    "SERVICE_NAME" = "mongodb"
  }
  volume = {
    mongodb = {
      name = "${local.basename}-mongodb"
      docker_volume_configuration = [{
        scope         = "shared"
        driver        = "local"
        autoprovision = true
      }]
    }
  }
  task_mount_points = [
    {
      containerPath = "/data/db"
      readOnly      = false
      sourceVolume  = "${local.basename}-mongodb"
    }
  ]
}

# Service
module "service-mongodb" {
  source              = "git::https://github.com/keepmycloudcom/modules-ecs.git//service?ref=v1.0.0"
  aws_region          = var.aws_region
  project_env         = var.project_env
  name                = "mongodb"
  ecs_cluster         = module.ecs.id
  container_name      = "mongodb"
  ecs_desired_count   = 1
  scheduling_strategy = "DAEMON"
  ecs_task_definition = module.task-mongodb.arn
  tags = local.base_tags
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "mongodb-loggroup" {
  name              = "/${var.project_env}/${var.project_name}/mongodb"
  retention_in_days = 3
  tags = merge(local.base_tags, {
    Name = "/${var.project_env}/${var.project_name}/mongodb"
  })
}
