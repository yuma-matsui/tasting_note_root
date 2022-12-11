# --------------------------
# Cluster
# --------------------------
resource "aws_ecs_cluster" "tasting_note" {
  name = "${var.project}-cluster"
}
# --------------------------
# task difinition
# --------------------------
resource "aws_ecs_task_definition" "rails_task" {
  family                   = "${var.project}-task"
  cpu                      = 256
  memory                   = 512
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  execution_role_arn = aws_iam_role.ecs_task_execution.arn
  task_role_arn      = aws_iam_role.ecs_task_execution.arn

  container_definitions = data.template_file.container_definitions.rendered
}
data "template_file" "container_definitions" {
  template = file("./task_definitions/rails_container_definitions.json")

  vars = {
    project               = var.project
    image                 = aws_ecr_repository.tasting_note.repository_url
    aws_ssm_parameter_arn = data.aws_ssm_parameter.rails_master_key.arn
  }
}
# --------------------------
# service
# --------------------------
resource "aws_ecs_service" "tasting-note" {
  name                              = "${var.project}-service"
  cluster                           = aws_ecs_cluster.tasting_note.arn
  task_definition                   = aws_ecs_task_definition.rails_task.arn
  desired_count                     = 2
  launch_type                       = "FARGATE"
  platform_version                  = "1.4.0"
  health_check_grace_period_seconds = 60

  network_configuration {
    assign_public_ip = true
    security_groups  = [aws_security_group.ecs_sg.id]

    subnets = [
      aws_subnet.public_1a.id,
      aws_subnet.public_1c.id
    ]
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.ecs_target_group.arn
    container_name   = "${var.project}-container"
    container_port   = 3000
  }

  lifecycle {
    ignore_changes = [
      task_definition
    ]
  }
}
