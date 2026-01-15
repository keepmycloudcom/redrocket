module "task-node-exporter" {
  source                    = "git::https://github.com/keepmycloudcom/modules-ecs.git//task?ref=v1.0.0"
  aws_region                = var.aws_region
  project_env               = var.project_env
  basename                  = local.basename
  name                      = "node-exporter"
  task_container_image      = "prom/node-exporter:latest"
  container_name            = "node-exporter"
  task_definition_cpu       = 128
  task_definition_memory    = 128
  docker_labels = {
    "SERVICE_NAME" = "node-exporter"
  }
  network_mode         = "host"
  privileged           = true
  add_linux_parameters = ["NET_ADMIN", "SYS_ADMIN", "SYS_PTRACE"]  
  volume = {
    proc = {
      name      = "proc"
      host_path = "/proc"
    },
    sys = {
      name      = "sys"
      host_path = "/sys"
    }
  }

  task_mount_points = [
    {
      containerPath = "/sys"
      readOnly      = false
      sourceVolume  = "sys"
    },
    {
      containerPath = "/proc"
      sourceVolume  = "proc"
      readOnly      = false
  }]
  tags = local.base_tags
}

# Service
module "service-node-exporter" {
  source              = "git::https://github.com/keepmycloudcom/modules-ecs.git//service?ref=v1.0.0"
  aws_region          = var.aws_region
  project_env         = var.project_env

  name                = "node-exporter-external"
  ecs_cluster         = module.ecs.id
  container_name      = "node-exporter-external"
  scheduling_strategy = "DAEMON"
  ecs_launch_type     = "EXTERNAL"
  ecs_desired_count   = "1"
  ecs_task_definition = module.task-node-exporter.arn

  tags = local.base_tags
}
