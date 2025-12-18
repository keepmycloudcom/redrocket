module "task-consul" {
  source                    = "git::https://github.com/keepmycloudcom/modules-ecs.git//task?ref=v1.0.0"
  aws_region                = var.aws_region
  project_env               = var.project_env
  #cloudwatch_log_group_name = "/${var.project_env}/${var.project_name}/consul"
  basename                  = local.basename
  name                      = "consul"
  task_container_image      = "hashicorp/consul:1.21.1"
  container_name            = "consul"
  task_definition_cpu       = 128
  task_definition_memory    = 256
  docker_labels = {
    "SERVICE_NAME" = "consul"
  }
  container_port_mappings = [
    {
      hostPort      = 8600
      containerPort = 8600
      protocol      = "tcp"
    },
    {
      hostPort      = 8600
      containerPort = 8600
      protocol      = "udp"
  }]
  task_container_command = ["agent", "-ui", "-server", "-data-dir=/consul/data", "-client={{ GetInterfaceIP \"eth0\" }}", "-bind={{ GetInterfaceIP \"eth0\" }}", "-bootstrap-expect=1", "-recursor=8.8.8.8", "-domain=${var.project_env}.${var.consul_domain}"]
  volume = {
    consul = {
      name = "consul"
      docker_volume_configuration = [{
        scope         = "shared"
        autoprovision = true
        driver        = "local"
      }]
    }
  }
  task_mount_points = [{
    containerPath = "/consul/data"
    readOnly      = false
    sourceVolume  = "consul"
  }]
  network_mode = "bridge"

  tags = local.base_tags
}

# Service
module "service-consul" {
  source      = "git::https://github.com/keepmycloudcom/modules-ecs.git//service?ref=v1.0.0"
  aws_region  = var.aws_region
  project_env = var.project_env

  name                = "consul"
  ecs_cluster         = module.ecs.id
  container_name      = "consul"
  scheduling_strategy = "DAEMON"

  ecs_task_definition = module.task-consul.arn

  tags = local.base_tags
}

module "task-registrator" {
  source                    = "git::https://github.com/keepmycloudcom/modules-ecs.git//task?ref=v1.0.0"
  aws_region                = var.aws_region
  project_env               = var.project_env
  #cloudwatch_log_group_name = "/${var.project_env}/${var.project_name}/consul"
  basename                  = local.basename
  name                      = "registrator"
  task_container_image      = "gliderlabs/registrator:master"
  container_name            = "registrator"
  task_definition_cpu       = 256
  task_definition_memory    = 512

  task_container_command = ["-cleanup=true", "-internal=true", "-explicit=true", "-resync=1000", "consul://consul.service.${var.project_env}.${var.consul_domain}:8500"]
  volume = {
    registrator = {
      name      = "docker-socket"
      host_path = "/var/run/docker.sock"
    }
  }
  task_mount_points = [{
    containerPath = "/tmp/docker.sock"
    sourceVolume  = "docker-socket"
    readOnly      = false
  }]
  network_mode = "bridge"

  tags = local.base_tags
}

# Service
module "service-registrator" {
  source      = "git::https://github.com/keepmycloudcom/modules-ecs.git//service?ref=v1.0.0"
  aws_region  = var.aws_region
  project_env = var.project_env

  name                = "registrator"
  ecs_cluster         = module.ecs.id
  container_name      = "registrator"
  scheduling_strategy = "REPLICA"

  ecs_task_definition = module.task-registrator.arn

  tags = local.base_tags
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "consul-loggroup" {
  name              = "/${var.project_env}/${var.project_name}/consul"
  retention_in_days = "3"
  tags = merge(local.base_tags, {
    Name = "/${var.project_env}/${var.project_name}/consul"
  })
}
