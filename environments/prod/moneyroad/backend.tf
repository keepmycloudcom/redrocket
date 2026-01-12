### Get secrets from AWS Secrets store 
data "aws_secretsmanager_secret" "backend-secrets" {
  arn = "arn:aws:secretsmanager:eu-central-1:218885890069:secret:prod/moneyroad/backend-oFQhbV"
}

data "aws_secretsmanager_secret_version" "backend-current" {
  secret_id = data.aws_secretsmanager_secret.backend-secrets.id
}

locals {
  backend_task_environment = [
    for k, v in jsondecode(data.aws_secretsmanager_secret_version.backend-current.secret_string) : {
      name  = k
      value = v
    }
  ]
}

### ECR
module "ecr-backend" {
  source   = "git::https://github.com/keepmycloudcom/modules-ecr.git?ref=v1.0.0"
  basename = local.basename
  names    = ["backend"]
  tags     = local.base_tags
}

### Codepipeline 
module "codepipeline-backend" {
  source      = "git::https://github.com/keepmycloudcom/modules-codepipeline.git?ref=v1.0.1"
  name        = "${local.basename}-backend"
  project_env = var.project_env
  secret_environment = [
    {
      name  = "SERVICE_NAME"
      value = "backend"
    },
    {
      name  = "STAND"
      value = "${var.project_env}"
    },
    {
      name  = "AWS_DEFAULT_REGION"
      value = "${var.aws_region}"
    },
    {
      name  = "ENVIRONMENT"
      value = "${var.project_env}"
    },
    { name  = "AWS_ACCOUNT_ID"
      value = "${var.aws_account}"
    },
    {
      name  = "IMAGE_REPO_NAME"
      value = "${var.project_name}-${var.project_env}-backend"
    },
    { name  = "CONTEXT"
      value = "backend"
    },
    {
      name  = "BUILD_PATH"
      value = "."
    },
    { name  = "DOCKERFILE_PATH"
      value = "./Dockerfile"
  }]
  project_name      = var.project_name
  repo_name         = "red-rocket-software/swapscout-be"
  codestar_conector = "redrocket"
  service_name      = "backend"
  ecs_cluster       = module.ecs.cluster_name
  aws_account       = var.aws_account
  aws_region        = var.aws_region
  tags              = local.base_tags
}


module "task-backend" {
  source                    = "git::https://github.com/keepmycloudcom/modules-ecs.git//task?ref=v1.0.0"
  aws_region                = var.aws_region
  project_env               = var.project_env
  basename                  = local.basename
  name                      = "backend"
  task_container_image      = "${var.aws_account}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.project_name}-${var.project_env}-backend:${var.project_env}-latest"
  cloudwatch_log_group_name = "/${var.project_env}/${var.project_name}/backend"
  container_name            = "backend"
  task_definition_cpu       = 512
  task_definition_memory    = 1024
  task_environment          = local.backend_task_environment
  docker_labels = {
    "SERVICE_NAME"                                             = "backend",
    "traefik.enable"                                           = "true",
    "traefik.http.routers.backend.entrypoints"                 = "websecure",
    "traefik.http.routers.backend.tls.certresolver"            = "letsencrypt",
    "traefik.http.routers.backend.service"                     = "backend",
    "traefik.http.routers.backend.rule"                        = "Host(`api.${var.project_domain}`) && PathPrefix(`/`)",
    "traefik.http.services.backend.loadbalancer.server.port"   = "3000",
    "traefik.http.services.backend.loadbalancer.server.scheme" = "http"
  }
  #  task_health_check = {
  #    "retries" = "3",
  #    "command" : [
  #      "CMD-SHELL",
  #      "curl -f -k http://localhost:3000/ || exit 1"
  #    ],
  #    "timeout" : 5,
  #    "interval" : 30,
  #    "startPeriod" : 5
  #  }
  network_mode = "bridge"


  tags = local.base_tags
}

# Service
module "service-backend" {
  source      = "git::https://github.com/keepmycloudcom/modules-ecs.git//service?ref=v1.0.0"
  aws_region  = var.aws_region
  project_env = var.project_env

  name                = "backend"
  ecs_cluster         = module.ecs.id
  container_name      = "backend"
  scheduling_strategy = "REPLICA"

  ecs_task_definition = module.task-backend.arn

  tags = local.base_tags
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "backend-loggroup" {
  name              = "/${var.project_env}/${var.project_name}/backend"
  retention_in_days = "3"
  tags = merge(local.base_tags, {
    Name = "/${var.project_env}/${var.project_name}/backend"
  })
}
