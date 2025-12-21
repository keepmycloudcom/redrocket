
module "task-kuma" {
  source                 = "git::https://github.com/keepmycloudcom/modules-ecs.git//task?ref=v1.0.0"
  aws_region             = var.aws_region
  project_env            = var.project_env
  basename               = local.basename
  name                   = "kuma"
  task_container_image   = "louislam/uptime-kuma:latest"
  container_name         = "kuma"
  task_definition_cpu    = 512
  task_definition_memory = 512

  docker_labels = {
    "SERVICE_NAME"                                          = "kuma"
    "traefik.enable"                                        = "true",
    "traefik.http.routers.kuma.entrypoints"                 = "websecure",
    "traefik.http.routers.kuma.tls.certresolver"            = "letsencrypt",
    "traefik.http.routers.kuma.service"                     = "kuma",
    "traefik.http.routers.kuma.rule"                        = "Host(`kuma.${var.project_domain}`) && PathPrefix(`/`)",
    "traefik.http.services.kuma.loadbalancer.server.port"   = "3001",
    "traefik.http.services.kuma.loadbalancer.server.scheme" = "http"
  }
  volume = {
    kuma = {
      name = "kuma"
      docker_volume_configuration = [{
        scope         = "shared"
        autoprovision = true
        driver        = "local"
      }]
    }
  }

  task_mount_points = [{
    containerPath = "/app/data"
    readOnly      = false
    sourceVolume  = "kuma"
  }]
  network_mode = "bridge"

  task_environment = [
    {
      name  = "TZ"
      value = "UTC"
    },
    { 
      name = "UMASK", 
      value = "0022" 
    }
  ]

  tags = local.base_tags
}

# Service
module "service-kuma" {
  source      = "git::https://github.com/keepmycloudcom/modules-ecs.git//service?ref=v1.0.0"
  aws_region  = var.aws_region
  project_env = var.project_env

  name                = "kuma"
  ecs_cluster         = module.ecs.id
  container_name      = "kuma"
  scheduling_strategy = "REPLICA"
  ecs_desired_count   = 1
  ecs_task_definition = module.task-kuma.arn

  tags = local.base_tags
}

