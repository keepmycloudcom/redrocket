### Get secrets from AWS Secrets store 
data "aws_secretsmanager_secret" "api-gateway-secrets" {
  arn = "arn:aws:secretsmanager:eu-central-1:218885890069:secret:prod/nms/backend-772mCx"
}

data "aws_secretsmanager_secret_version" "api-gateway-current" {
  secret_id = data.aws_secretsmanager_secret.api-gateway-secrets.id
}

locals {
  api-gateway_task_environment = [
    for k, v in jsondecode(data.aws_secretsmanager_secret_version.api-gateway-current.secret_string) : {
      name  = k
      value = v
    }
  ]
}

### ECR
module "ecr-api-gateway" {
  source   = "git::https://github.com/keepmycloudcom/modules-ecr.git?ref=v1.0.0"
  basename = local.basename
  names    = ["api-gateway"]
  tags     = local.base_tags
}

### Codepipeline 
module "codepipeline-api-gateway" {
  source      = "git::https://github.com/keepmycloudcom/modules-codepipeline.git?ref=v1.0.1"
  name        = "${local.basename}-api-gateway"
  project_env = var.project_env
  secret_environment = [
    {
      name  = "SERVICE_NAME"
      value = "api-gateway"
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
      value = "${var.project_name}-${var.project_env}-api-gateway"
    },
    { name  = "CONTEXT"
      value = "api-gateway"
    },
    {
      name  = "BUILD_PATH"
      value = "."
    },
    { name  = "DOCKERFILE_PATH"
      value = "./Dockerfile.api-gateway"
  }]
  project_name      = var.project_name
  repo_name         = "red-rocket-software/nms-backend"
  codestar_conector = "redrocket"
  service_name      = "api-gateway"
  ecs_cluster       = module.ecs.cluster_name
  aws_account       = var.aws_account
  aws_region        = var.aws_region
  tags              = local.base_tags
}


module "task-api-gateway" {
  source                    = "git::https://github.com/keepmycloudcom/modules-ecs.git//task?ref=v1.0.0"
  aws_region                = var.aws_region
  project_env               = var.project_env
  basename                  = local.basename
  name                      = "api-gateway"
  task_container_image      = "${var.aws_account}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.project_name}-${var.project_env}-api-gateway:${var.project_env}-latest"
  cloudwatch_log_group_name = "/${var.project_env}/${var.project_name}/api-gateway"
  container_name            = "api-gateway"
  task_definition_cpu       = 512  
  task_definition_memory    = 1024
  task_environment = local.api-gateway_task_environment
  docker_labels = {
    "SERVICE_NAME"                                                 = "api-gateway",
    "traefik.enable"                                               = "true",
    "traefik.http.routers.api-gateway.entrypoints"                 = "websecure",
    "traefik.http.routers.api-gateway.tls.certresolver"            = "letsencrypt",
    "traefik.http.routers.api-gateway.service"                     = "api-gateway",
    "traefik.http.routers.api-gateway.rule"                        = "Host(`api-gateway.${var.project_domain}`) && PathPrefix(`/`)",
    "traefik.http.services.api-gateway.loadbalancer.server.port"   = "3000",
    "traefik.http.services.api-gateway.loadbalancer.server.scheme" = "http"
  }
  task_health_check = {
    "retries" = "3",
    "command" : [
      "CMD-SHELL",
      "curl -f -k http://localhost:3000/ || exit 1"
    ],
    "timeout" : 5,
    "interval" : 30,
    "startPeriod" : 5
  }
  network_mode = "bridge"


  tags = local.base_tags
}

# Service
module "service-api-gateway" {
  source      = "git::https://github.com/keepmycloudcom/modules-ecs.git//service?ref=v1.0.0"
  aws_region  = var.aws_region
  project_env = var.project_env

  name                = "api-gateway"
  ecs_cluster         = module.ecs.id
  container_name      = "api-gateway"
  scheduling_strategy = "REPLICA"

  ecs_task_definition = module.task-api-gateway.arn

  tags = local.base_tags
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "api-gateway-loggroup" {
  name              = "/${var.project_env}/${var.project_name}/api-gateway"
  retention_in_days = "3"
  tags = merge(local.base_tags, {
    Name = "/${var.project_env}/${var.project_name}/api-gateway"
  })
}
