module "task-prometheus" {
  source                    = "git::https://github.com/keepmycloudcom/modules-ecs.git//task?ref=v1.0.0"
  aws_region                = var.aws_region
  project_env               = var.project_env
  basename                  = local.basename
  name                      = "prometheus"
  task_container_image      = "prom/prometheus:v2.31.1"
  container_name            = "prometheus"
  task_definition_cpu       = 1024
  task_definition_memory    = 1024
  task_container_command    = ["--config.file=/etc/prometheus/prometheus.yml", "--storage.tsdb.path=/prometheus", "--storage.tsdb.retention.time=60d", "--web.console.libraries=/usr/share/prometheus/console_libraries", "--web.console.templates=/usr/share/prometheus/consoles"]

  docker_labels = {
    "SERVICE_NAME" = "prometheus"
  }
  network_mode = "bridge"
  task_environment = [
    {
      name  = "AWS_DEFAULT_REGION"
      value = "${var.aws_region}"
  }]

  volume = {
    prometheus = {
      name = "prometheus"
      docker_volume_configuration = [{
        scope         = "shared"
        autoprovision = true
        driver        = "local"
      }]
    },
    prometheus-config = {
      name = "prometheus-config"
      docker_volume_configuration = [{
        scope         = "shared"
        autoprovision = true
        driver        = "local"
      }]
    }
  }
  task_mount_points = [
    {
      containerPath = "/etc/prometheus/"
      sourceVolume  = "prometheus-config"
      readOnly      = false
    },
    {
      containerPath = "/prometheus"
      readOnly      = false
      sourceVolume  = "prometheus"
  }]
  tags = local.base_tags
}

# Service
module "service-prometheus" {
  source      = "git::https://github.com/keepmycloudcom/modules-ecs.git//service?ref=v1.0.0"
  aws_region  = var.aws_region
  project_env = var.project_env

  name                = "prometheus"
  ecs_cluster         = module.ecs.id
  container_name      = "prometheus"
  scheduling_strategy = "DAEMON"

  ecs_task_definition = module.task-prometheus.arn

  tags = local.base_tags
}

