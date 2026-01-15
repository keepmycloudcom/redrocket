module "task-redis" {
  source                 = "git::https://github.com/keepmycloudcom/modules-ecs.git//task?ref=v1.0.0"
  aws_region             = var.aws_region
  project_env            = var.project_env
  basename               = local.basename
  name                   = "redis"
  task_container_image   = "redis"
  container_name         = "redis"
  task_definition_cpu    = 512
  task_definition_memory = 512
  docker_labels = {
    "SERVICE_NAME" = "redis"
  }
  network_mode = "bridge"

  volume = {
    redis = {
      name = "redis"
      docker_volume_configuration = [{
        scope         = "shared"
        autoprovision = true
        driver        = "local"
      }]
    }
  }
  task_mount_points = [
    {
      containerPath = "/data"
      readOnly      = false
      sourceVolume  = "redis"
  }]
  tags = local.base_tags
}

# Service
module "service-redis" {
  source      = "git::https://github.com/keepmycloudcom/modules-ecs.git//service?ref=v1.0.0"
  aws_region  = var.aws_region
  project_env = var.project_env

  name                = "redis"
  ecs_cluster         = module.ecs.id
  container_name      = "redis"
  scheduling_strategy = "DAEMON"

  ecs_task_definition = module.task-redis.arn

  tags = local.base_tags
}
