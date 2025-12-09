### Get secrets from AWS Secrets store 
data "aws_secretsmanager_secret" "status-service-secrets" {
  arn = "arn:aws:secretsmanager:eu-central-1:218885890069:secret:staging/nms/backend-G52G4k"
}

data "aws_secretsmanager_secret_version" "status-service-current" {
  secret_id = data.aws_secretsmanager_secret.status-service-secrets.id
}

locals {
  status-service_task_environment = [
    for k, v in jsondecode(data.aws_secretsmanager_secret_version.status-service-current.secret_string) : {
      name  = k
      value = v
    }
  ]
}

### ECR
module "ecr-status-service" {
  source   = "git::https://github.com/keepmycloudcom/modules-ecr.git?ref=v1.0.0"
  basename = local.basename
  names    = ["status-service"]
  tags     = local.base_tags
}

### Codepipeline 
module "codepipeline-status-service" {
  source      = "git::https://github.com/keepmycloudcom/modules-codepipeline.git?ref=v1.0.1"
  name        = "${local.basename}-status-service"
  project_env = var.project_env
  secret_environment = [
    {
      name  = "SERVICE_NAME"
      value = "status-service"
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
      value = "${var.project_name}-${var.project_env}-status-service"
    },
    { name  = "CONTEXT"
      value = "status-service"
    },
    {
      name  = "BUILD_PATH"
      value = "."
    },
    { name  = "DOCKERFILE_PATH"
      value = "./Dockerfile.status-service"
  }]
  project_name      = var.project_name
  repo_name         = "red-rocket-software/nms-backend"
  codestar_conector = "redrocket"
  service_name      = "status-service"
  ecs_cluster       = module.ecs.cluster_name
  aws_account       = var.aws_account
  aws_region        = var.aws_region
  tags              = local.base_tags
}


module "task-status-service" {
  source                    = "git::https://github.com/keepmycloudcom/modules-ecs.git//task?ref=v1.0.0"
  aws_region                = var.aws_region
  project_env               = var.project_env
  basename                  = local.basename
  name                      = "status-service"
  task_container_image      = "${var.aws_account}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.project_name}-${var.project_env}-status-service:${var.project_env}-latest"
  cloudwatch_log_group_name = "/${var.project_env}/${var.project_name}/status-service"
  container_name            = "status-service"
  task_definition_cpu       = 1000
  task_definition_memory    = 1024
  task_environment = local.status-service_task_environment
  docker_labels = {
    "SERVICE_NAME"                                                    = "status-service",
    "traefik.enable"                                                  = "true",
    "traefik.http.routers.status-service.entrypoints"                 = "websecure",
    "traefik.http.routers.status-service.tls.certresolver"            = "letsencrypt",
    "traefik.http.routers.status-service.service"                     = "status-service",
    "traefik.http.routers.status-service.rule"                        = "Host(`status-service.${var.project_env}.${var.project_domain}`) && PathPrefix(`/`)",
    "traefik.http.services.status-service.loadbalancer.server.port"   = "5001",
    "traefik.http.services.status-service.loadbalancer.server.scheme" = "http"
  }
#  task_health_check = {
#    "retries" = "3",
#    "command" : [
#      "CMD-SHELL",
#      "curl -f -k http://localhost:5001/ || exit 1"
#    ],
#    "timeout" : 5,
#    "interval" : 30,
#    "startPeriod" : 5
#  }
  network_mode = "bridge"


  tags = local.base_tags
}

# Service
module "service-status-service" {
  source      = "git::https://github.com/keepmycloudcom/modules-ecs.git//service?ref=v1.0.0"
  aws_region  = var.aws_region
  project_env = var.project_env

  name                = "status-service"
  ecs_cluster         = module.ecs.id
  container_name      = "status-service"
  scheduling_strategy = "REPLICA"
  ecs_desired_count   = "1"
  ecs_task_definition = module.task-status-service.arn

  tags = local.base_tags
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "status-service-loggroup" {
  name              = "/${var.project_env}/${var.project_name}/status-service"
  retention_in_days = "3"
  tags = merge(local.base_tags, {
    Name = "/${var.project_env}/${var.project_name}/status-service"
  })
}
