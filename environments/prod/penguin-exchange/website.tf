### Get secrets from AWS Secrets store 
data "aws_secretsmanager_secret" "website-secrets" {
  arn = "arn:aws:secretsmanager:eu-central-1:218885890069:secret:prod/penguin-exchange/backend-DAW59B"
}

data "aws_secretsmanager_secret_version" "website-current" {
  secret_id = data.aws_secretsmanager_secret.website-secrets.id
}

locals {
  website_task_environment = [
    for k, v in jsondecode(data.aws_secretsmanager_secret_version.website-current.secret_string) : {
      name  = k
      value = v
    }
  ]
}

### ECR
module "ecr-website" {
  source   = "git::https://github.com/keepmycloudcom/modules-ecr.git?ref=v1.0.0"
  basename = local.basename
  names    = ["website"]
  tags     = local.base_tags
}

### Codepipeline 
module "codepipeline-website" {
  source      = "git::https://github.com/keepmycloudcom/modules-codepipeline.git?ref=v1.0.1"
  name        = "${local.basename}-website"
  project_env = var.project_env
  secret_environment = [
    {
      name  = "SERVICE_NAME"
      value = "website"
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
      value = "${var.project_name}-${var.project_env}-website"
    },
    { name  = "CONTEXT"
      value = "website"
    },
    {
      name  = "BUILD_PATH"
      value = "."
    },
    { name  = "DOCKERFILE_PATH"
      value = "./Dockerfile"
  }]
  project_name      = var.project_name
  repo_name         = "red-rocket-software/Money4u"
  codestar_conector = "redrocket"
  service_name      = "website"
  compute_type      = "BUILD_GENERAL1_LARGE"
  ecs_cluster       = module.ecs.cluster_name
  aws_account       = var.aws_account
  aws_region        = var.aws_region
  tags              = local.base_tags
}


module "task-website" {
  source                    = "git::https://github.com/keepmycloudcom/modules-ecs.git//task?ref=v1.0.0"
  aws_region                = var.aws_region
  project_env               = var.project_env
  basename                  = local.basename
  name                      = "website"
  task_container_image      = "${var.aws_account}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.project_name}-${var.project_env}-website:${var.project_env}-latest"
  cloudwatch_log_group_name = "/${var.project_env}/${var.project_name}/website"
  container_name            = "website"
  task_definition_cpu       = 1024  
  task_definition_memory    = 1024
  task_environment = local.website_task_environment
  docker_labels = {
    "SERVICE_NAME"                                                 = "website",
    "traefik.enable"                                               = "true",
    "traefik.http.routers.website.entrypoints"                 = "websecure",
    "traefik.http.routers.website.tls.certresolver"            = "letsencrypt",
    "traefik.http.routers.website.service"                     = "website",
    "traefik.http.routers.website.rule"                        = "Host(`${var.project_domain}`) && PathPrefix(`/`)",
    "traefik.http.services.website.loadbalancer.server.port"   = "3000",
    "traefik.http.services.website.loadbalancer.server.scheme" = "http"
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
module "service-website" {
  source      = "git::https://github.com/keepmycloudcom/modules-ecs.git//service?ref=v1.0.0"
  aws_region  = var.aws_region
  project_env = var.project_env

  name                = "website"
  ecs_cluster         = module.ecs.id
  container_name      = "website"
  scheduling_strategy = "REPLICA"

  ecs_task_definition = module.task-website.arn

  tags = local.base_tags
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "website-loggroup" {
  name              = "/${var.project_env}/${var.project_name}/website"
  retention_in_days = "3"
  tags = merge(local.base_tags, {
    Name = "/${var.project_env}/${var.project_name}/website"
  })
}
