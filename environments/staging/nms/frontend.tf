### ECR
module "ecr-frontend" {
  source   = "git::https://github.com/keepmycloudcom/modules-ecr.git?ref=v1.0.0"
  basename = local.basename
  names    = ["frontend"]
  tags     = local.base_tags
}

### Codepipeline 
module "codepipeline-frontend" {
  source      = "git::https://github.com/keepmycloudcom/modules-codepipeline.git?ref=v1.0.1"
  name        = "${local.basename}-frontend"
  project_env = var.project_env
  secret_environment = [
    {
      name  = "SERVICE_NAME"
      value = "frontend"
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
      value = "${var.project_name}-${var.project_env}-frontend"
    },
    { name  = "CONTEXT"
      value = "frontend"
    },
    {
      name  = "BUILD_PATH"
      value = "."
    },
    { name  = "VITE_API_BASE_URL"
      value = "https://api-gateway.${var.project_env}.${var.project_domain}"
    },
    { name  = "DOCKERFILE_PATH"
      value = "./Dockerfile"
  }]
  project_name      = var.project_name
  repo_name         = "red-rocket-software/nms-frontend"
  codestar_conector = "redrocket"
  service_name      = "frontend"
  ecs_cluster       = module.ecs.cluster_name
  aws_account       = var.aws_account
  aws_region        = var.aws_region
  tags              = local.base_tags
}


module "task-frontend" {
  source                    = "git::https://github.com/keepmycloudcom/modules-ecs.git//task?ref=v1.0.0"
  aws_region                = var.aws_region
  project_env               = var.project_env
  basename                  = local.basename
  name                      = "frontend"
  task_container_image      = "${var.aws_account}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.project_name}-${var.project_env}-frontend:${var.project_env}-latest"
  cloudwatch_log_group_name = "/${var.project_env}/${var.project_name}/frontend"
  container_name            = "frontend"
  task_definition_cpu       = 512
  task_definition_memory    = 512

  docker_labels = {
    "SERVICE_NAME"                                                    = "frontend",
    "traefik.enable"                                                  = "true",
    "traefik.http.routers.frontend.entrypoints"                 = "websecure",
    "traefik.http.routers.frontend.tls.certresolver"            = "letsencrypt",
    "traefik.http.routers.frontend.service"                     = "frontend",
    "traefik.http.routers.frontend.rule"                        = "Host(`${var.project_env}.${var.project_domain}`) && PathPrefix(`/`)",
    "traefik.http.services.frontend.loadbalancer.server.port"   = "80",
    "traefik.http.services.frontend.loadbalancer.server.scheme" = "http"
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
module "service-frontend" {
  source      = "git::https://github.com/keepmycloudcom/modules-ecs.git//service?ref=v1.0.0"
  aws_region  = var.aws_region
  project_env = var.project_env

  name                = "frontend"
  ecs_cluster         = module.ecs.id
  container_name      = "frontend"
  scheduling_strategy = "REPLICA"

  ecs_task_definition = module.task-frontend.arn

  tags = local.base_tags
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "frontend-loggroup" {
  name              = "/${var.project_env}/${var.project_name}/frontend"
  retention_in_days = "3"
  tags = merge(local.base_tags, {
    Name = "/${var.project_env}/${var.project_name}/frontend"
  })
}
