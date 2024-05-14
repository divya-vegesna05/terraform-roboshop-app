resource "aws_lb_target_group" "Component" {
  name     = "${var.Project_name}-${var.Environment}-${var.tags.Component}"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  deregistration_delay = 60
   health_check {
      healthy_threshold   = 2
      interval            = 10
      unhealthy_threshold = 3
      timeout             = 5
      path                = "/health"
      port                = 8080
      matcher             = "200-299" 
  }
}
module "Component"{
    source = "terraform-aws-modules/ec2-instance/aws"
    name = "${local.name}-${var.tags.Component}"
    ami = data.aws_ami.centos8.id
    instance_type          = "t2.micro"
    vpc_security_group_ids = [var.component_security_group_id]
    subnet_id              = element(var.private_subnet_id,0)
    iam_instance_profile = var.iam_instance_profile
    tags = merge(var.common_tags,var.tags)
    }
resource "null_resource" "Component" {
  # Changes to any instance of the cluster requires re-provisioning
  triggers = {
    instance_id = module.Component.id
  }
    connection {
    type     = "ssh"
    user     = "centos"
    password = "DevOps321"
    host     = module.Component.private_ip
  }
provisioner "file" {
    source      = "bootstrap.sh"
    destination = "/tmp/bootstrap.sh"
  }
provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/bootstrap.sh",
      "sudo sh /tmp/bootstrap.sh ${var.tags.Component} ${var.Environment} ${var.app_version}",
    ]
  }
}
resource "aws_ec2_instance_state" "stop-Component" {
  instance_id = module.Component.id
  state       = "stopped"
   depends_on = [
    null_resource.Component
  ]
}
resource "aws_ami_from_instance" "Component" {
  name               = "${local.name}-${var.tags.Component}-${local.current_time}"
  source_instance_id = module.Component.id
  depends_on = [
    aws_ec2_instance_state.stop-Component
  ]
}
resource "null_resource" "Component-delete" {
  # Changes to any instance of the cluster requires re-provisioning
  triggers = {
    instance_id = module.Component.id
  }
  provisioner "local-exec" {
    command = "aws ec2 terminate-instances --instance-ids ${module.Component.id}"
  }
depends_on = [
    aws_ami_from_instance.Component
  ]
}
resource "aws_launch_template" "Component" {
  name = "${local.name}-${var.tags.Component}"
  image_id = aws_ami_from_instance.Component.id
  instance_initiated_shutdown_behavior = "terminate"
  instance_type = "t2.micro"
  vpc_security_group_ids = [var.component_security_group_id]
  update_default_version = true
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${local.name}-${var.tags.Component}"
    }
  }
}
resource "aws_autoscaling_group" "Component" {
  name                      = "${local.name}-${var.tags.Component}"
  max_size                  = 3
  min_size                  = 1
  health_check_grace_period = 60
  health_check_type         = "ELB"
  desired_capacity          = 2
  launch_template {
    id      = aws_launch_template.Component.id
    version = aws_launch_template.Component.latest_version
  }
  vpc_zone_identifier = var.private_subnet_id
  target_group_arns = [ aws_lb_target_group.Component.arn ]
 instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
    triggers = ["launch_template"]
  }
  tag {
    key                 = "Name"
    value               = "${local.name}-${var.tags.Component}"
    propagate_at_launch = true
  }

  timeouts {
    delete = "15m"
  }
}
resource "aws_autoscaling_policy" "Component" {
    name                   = "${local.name}-${var.tags.Component}"
    autoscaling_group_name = aws_autoscaling_group.Component.name
    policy_type            = "TargetTrackingScaling"
    target_tracking_configuration {
      predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 5.0
  }
}

resource "aws_lb_listener_rule" "Component" {
  listener_arn = var.app_alb_listener_arn
  priority     = var.priority
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.Component.arn
  }
  condition {
    host_header {
      values = ["${var.tags.Component}.app-${var.Environment}.${var.zone_name}"]
    }
  }
}

