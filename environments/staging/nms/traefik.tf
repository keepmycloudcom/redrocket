module "task-traefik" {
  source                    = "git::https://github.com/keepmycloudcom/modules-ecs.git//task?ref=v1.0.0"
  aws_region                = var.aws_region
  project_env               = var.project_env
  #cloudwatch_log_group_name = "/${var.project_env}/${var.project_name}/traefik"
  basename                  = local.basename
  name                      = "traefik-proxy"
  task_container_image      = "traefik:v3.6.2"
  container_name            = "traefik-proxy"
  task_container_command    = ["--api.dashboard=true", "--log.level=INFO", "--log.format=json", "--accesslog.format=json", "--accesslog=true", "--providers.docker.network=bridge", "--providers.docker.exposedByDefault=false", "--entrypoints.web.address=:80", "--entrypoints.web.http.redirections.entrypoint.to=websecure", "--entrypoints.websecure.proxyProtocol.trustedIPs=0.0.0.0/0", "--entryPoints.web.http.redirections.entrypoint.scheme=https", "--entrypoints.websecure.address=:443", "--entrypoints.websecure.asDefault=true", "--entrypoints.websecure.http.tls.certresolver=letsencrypt", "--certificatesresolvers.letsencrypt.acme.email=mail@keepmycloud.com", "--certificatesresolvers.letsencrypt.acme.tlschallenge=true", "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json", "--serverstransport.insecureskipverify=true"]
  task_definition_cpu       = 128
  task_definition_memory    = 256

  docker_labels = {
    "traefik.enable"                                  = "true",
    "traefik.http.routers.mydashboard.rule"           = "Host(`traefik.${var.project_domain}`)",
    "traefik.http.routers.mydashboard.service"        = "api@internal",
    "traefik.http.routers.mydashboard.middlewares"    = "myauth",
    "traefik.http.middlewares.myauth.basicauth.users" = "adam:$2y$05$IuhWQCI7VwQCBrAYU/5siet7wBdySzafji5BjK2.z8of3wPNEE6rC"
  }
  container_port_mappings = [{
    hostPort      = 80
    containerPort = 80
    protocol      = "tcp"
    },
    {
      hostPort      = 443
      containerPort = 443
      protocol      = "tcp"
  }]
  volume = {
    letsencrypt = {
      name = "letsencrypt"
      docker_volume_configuration = [{
        scope         = "shared"
        autoprovision = true
        driver        = "local"
      }]
    },
    docker = {
      name      = "docker-socket"
      host_path = "/var/run/docker.sock"
    }
  }
  task_mount_points = [{
    containerPath = "/letsencrypt"
    readOnly      = false
    sourceVolume  = "letsencrypt"
    },
    {
      containerPath = "/var/run/docker.sock"
      sourceVolume  = "docker-socket"
      readOnly      = false
  }]
  network_mode = "bridge"

  tags = local.base_tags
}

# Service
module "service-traefik" {
  source      = "git::https://github.com/keepmycloudcom/modules-ecs.git//service?ref=v1.0.0"
  aws_region  = var.aws_region
  project_env = var.project_env

  name                = "traefik"
  ecs_cluster         = module.ecs.id
  container_name      = "traefik"
  scheduling_strategy = "DAEMON"

  ecs_task_definition = module.task-traefik.arn

  tags = local.base_tags
}


# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "traefik-loggroup" {
  name              = "/${var.project_env}/${var.project_name}/traefik"
  retention_in_days = "3"
  tags = merge(local.base_tags, {
    Name = "/${var.project_env}/${var.project_name}/traefik"
  })
}
