### Get secrets from AWS Secrets store 
data "aws_secretsmanager_secret" "postgres-secrets" {
  arn = "arn:aws:secretsmanager:eu-central-1:218885890069:secret:staging/shot/postgres-u3AcMt"
}

data "aws_secretsmanager_secret_version" "postgres-current" {
  secret_id = data.aws_secretsmanager_secret.postgres-secrets.id
}

locals {
  postgres_task_environment = [
    for k, v in jsondecode(data.aws_secretsmanager_secret_version.postgres-current.secret_string) : {
      name  = k
      value = v
    }
  ]
}

module "task-postgres" {
  source                 = "git::https://github.com/keepmycloudcom/modules-ecs.git//task?ref=v1.0.0"
  aws_region             = var.aws_region
  project_env            = var.project_env
  basename               = local.basename
  name                   = "postgres"
  task_container_image   = "postgres:15-alpine"
  container_name         = "postgres"
  task_definition_cpu    = 512
  task_definition_memory = 1024
  docker_labels = {
    "SERVICE_NAME" = "postgres"
  }
  network_mode     = "bridge"
  task_environment = local.postgres_task_environment
  volume = {
    letsencrypt = {
      name = "postgres"
      docker_volume_configuration = [{
        scope         = "shared"
        autoprovision = true
        driver        = "local"
      }]
    }
  }
  task_mount_points = [
    {
      containerPath = "/var/lib/postgresql/data"
      readOnly      = false
      sourceVolume  = "postgres"
  }]
  tags = local.base_tags
}

# Service
module "service-postgres" {
  source      = "git::https://github.com/keepmycloudcom/modules-ecs.git//service?ref=v1.0.0"
  aws_region  = var.aws_region
  project_env = var.project_env

  name                = "postgres"
  ecs_cluster         = module.ecs.id
  container_name      = "postgres"
  scheduling_strategy = "DAEMON"

  ecs_task_definition = module.task-postgres.arn

  tags = local.base_tags
}

module "task-postgres-exporter" {
  source                 = "git::https://github.com/keepmycloudcom/modules-ecs.git//task?ref=v1.0.0"
  aws_region             = var.aws_region
  project_env            = var.project_env
  basename               = local.basename
  name                   = "postgres-exporter"
  task_container_image   = "prometheuscommunity/postgres-exporter"
  container_name         = "postgres-exporter"
  task_definition_cpu    = 128
  task_definition_memory = 128
  task_environment       = local.postgres_task_environment
  docker_labels = {
    "SERVICE_NAME" = "postgres-exporter"
  }
  network_mode = "host"
  privileged   = true

  tags = local.base_tags
}

# Service
module "service-postgres-exporter" {
  source      = "git::https://github.com/keepmycloudcom/modules-ecs.git//service?ref=v1.0.0"
  aws_region  = var.aws_region
  project_env = var.project_env

  name                = "postgres-exporter"
  ecs_cluster         = module.ecs.id
  container_name      = "postgres-exporter"
  scheduling_strategy = "DAEMON"
  ecs_launch_type     = "EXTERNAL"
  ecs_desired_count   = "1"
  ecs_task_definition = module.task-postgres-exporter.arn

  tags = local.base_tags
}
