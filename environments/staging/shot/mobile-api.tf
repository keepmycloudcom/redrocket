### Get secrets from AWS Secrets store 
data "aws_secretsmanager_secret" "mobile-api-secrets" {
  arn = "arn:aws:secretsmanager:eu-central-1:218885890069:secret:staging/shot/mobile-api-vcvk57"
}

data "aws_secretsmanager_secret_version" "mobile-api-current" {
  secret_id = data.aws_secretsmanager_secret.mobile-api-secrets.id
}

locals {
  mobile-api_task_environment = [
    for k, v in jsondecode(data.aws_secretsmanager_secret_version.mobile-api-current.secret_string) : {
      name  = k
      value = v
    }
  ]
}

### ECR
module "ecr-mobile-api" {
  source   = "git::https://github.com/keepmycloudcom/modules-ecr.git?ref=v1.0.0"
  basename = local.basename
  names    = ["mobile-api"]
  tags     = local.base_tags
}

### Codepipeline 
module "codepipeline-mobile-api" {
  source      = "git::https://github.com/keepmycloudcom/modules-codepipeline.git?ref=v1.0.1"
  name        = "${local.basename}-mobile-api"
  project_env = var.project_env
  secret_environment = [
    {
      name  = "SERVICE_NAME"
      value = "mobile-api"
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
      value = "${var.project_name}-${var.project_env}-mobile-api"
    },
    { name  = "CONTEXT"
      value = "mobile-api"
    },
    {
      name  = "BUILD_PATH"
      value = "."
    },
    { name  = "DOCKERFILE_PATH"
      value = "./Dockerfile"
  }]
  project_name      = var.project_name
  repo_name         = "vlukianenko-hub/redrocket-backend"
  codestar_conector = "redrocket"
  service_name      = "mobile-api"
  ecs_cluster       = module.ecs.cluster_name
  aws_account       = var.aws_account
  aws_region        = var.aws_region
  tags              = local.base_tags
}


module "task-mobile-api" {
  source                    = "git::https://github.com/keepmycloudcom/modules-ecs.git//task?ref=v1.0.0"
  aws_region                = var.aws_region
  project_env               = var.project_env
  basename                  = local.basename
  name                      = "mobile-api"
  task_container_image      = "${var.aws_account}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.project_name}-${var.project_env}-mobile-api:${var.project_env}-latest"
  cloudwatch_log_group_name = "/${var.project_env}/${var.project_name}/mobile-api"
  container_name            = "mobile-api"
  task_definition_cpu       = 512
  task_definition_memory    = 1024
  task_environment          = local.mobile-api_task_environment
  docker_labels = {
    "SERVICE_NAME"                                                = "mobile-api",
    "traefik.enable"                                              = "true",
    "traefik.http.routers.mobile-api.entrypoints"                 = "websecure",
    "traefik.http.routers.mobile-api.tls.certresolver"            = "letsencrypt",
    "traefik.http.routers.mobile-api.service"                     = "mobile-api",
    "traefik.http.routers.mobile-api.rule"                        = "Host(`api.${var.project_domain}`) && PathPrefix(`/`)",
    "traefik.http.services.mobile-api.loadbalancer.server.port"   = "3000",
    "traefik.http.services.mobile-api.loadbalancer.server.scheme" = "http"
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
module "service-mobile-api" {
  source      = "git::https://github.com/keepmycloudcom/modules-ecs.git//service?ref=v1.0.0"
  aws_region  = var.aws_region
  project_env = var.project_env

  name                = "mobile-api"
  ecs_cluster         = module.ecs.id
  container_name      = "mobile-api"
  scheduling_strategy = "REPLICA"

  ecs_task_definition = module.task-mobile-api.arn

  tags = local.base_tags
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "mobile-api-loggroup" {
  name              = "/${var.project_env}/${var.project_name}/mobile-api"
  retention_in_days = "3"
  tags = merge(local.base_tags, {
    Name = "/${var.project_env}/${var.project_name}/mobile-api"
  })
}
