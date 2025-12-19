module "task-grafana" {
  source                    = "git::https://github.com/keepmycloudcom/modules-ecs.git//task?ref=v1.0.0"
  aws_region                = var.aws_region
  project_env               = var.project_env
  basename                  = local.basename
  name                      = "grafana"
  task_container_image      = "grafana/grafana"
  container_name            = "grafana"
  task_definition_cpu       = 1024
  task_definition_memory    = 1024
  docker_labels = {
    "SERVICE_NAME"                                             = "grafana",
    "traefik.enable"                                           = "true",
    "traefik.http.routers.grafana.entrypoints"                 = "websecure",
    "traefik.http.routers.grafana.tls.certresolver"            = "letsencrypt",
    "traefik.http.routers.grafana.service"                     = "grafana",
    "traefik.http.routers.grafana.rule"                        = "Host(`grafana.${var.project_domain}`) && PathPrefix(`/`)",
    "traefik.http.services.grafana.loadbalancer.server.port"   = "3000",
    "traefik.http.services.grafana.loadbalancer.server.scheme" = "http"
  }
  network_mode = "bridge"
  task_environment = [
    {
      name  = "AWS_DEFAULT_REGION"
      value = "${var.aws_region}"
  }]

  volume = {
    grafana = {
      name = "grafana"
      docker_volume_configuration = [{
        scope         = "shared"
        autoprovision = true
        driver        = "local"
      }]
    }
  }
  task_mount_points = [
    {
      containerPath = "/var/lib/grafana"
      readOnly      = false
      sourceVolume  = "grafana"
  }]
  tags = local.base_tags
}

# Service
module "service-grafana" {
  source      = "git::https://github.com/keepmycloudcom/modules-ecs.git//service?ref=v1.0.0"
  aws_region  = var.aws_region
  project_env = var.project_env

  name                = "grafana"
  ecs_cluster         = module.ecs.id
  container_name      = "grafana"
  scheduling_strategy = "REPLICA"

  ecs_task_definition = module.task-grafana.arn

  tags = local.base_tags
}
