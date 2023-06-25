# ---------------------------------------------
# key pairの登録
# ---------------------------------------------
resource "aws_key_pair" "keypair" {
  key_name   = "${var.project}-${var.environment}-keypair"
  public_key = file("./src/terraform-dev-keypair.pub")

  tags = {
    Name    = "${var.project}-${var.environment}-keypair"
    Project = var.project
    Env     = var.environment
  }
}

# ---------------------------------------------
# SSM Parameter Store
# ---------------------------------------------
resource "aws_ssm_parameter" "host" {
  name  = "/${var.project}/${var.environment}/app/MYSQL_HOST"
  type  = "String"
  value = aws_db_instance.mysql.address
}

resource "aws_ssm_parameter" "port" {
  name  = "/${var.project}/${var.environment}/app/MYSQL_PORT"
  type  = "String"
  value = aws_db_instance.mysql.port
}

resource "aws_ssm_parameter" "database" {
  name  = "/${var.project}/${var.environment}/app/MYSQL_DATABASE"
  type  = "String"
  value = aws_db_instance.mysql.name
}

resource "aws_ssm_parameter" "username" {
  name  = "/${var.project}/${var.environment}/app/MYSQL_USERNAME"
  type  = "SecureString"
  value = aws_db_instance.mysql.username
}

resource "aws_ssm_parameter" "password" {
  name  = "/${var.project}/${var.environment}/app/MYSQL_PASSWORD"
  type  = "SecureString"
  value = random_string.db_password.result
}


# ---------------------------------------------
# EC2 Instance (AutoScalinggroup設定の為コメントアウト)
# ---------------------------------------------
#resource "aws_instance" "app_server" {
#  ami                         = data.aws_ami.app.id
#  instance_type               = "t2.micro"
#  subnet_id                   = aws_subnet.public_subnet_1a.id
#  associate_public_ip_address = true
#  # iam_instance_profile        = aws_iam_instance_profile.app_ec2_profile.name
#  vpc_security_group_ids = [
#    aws_security_group.app_sg.id,
#    aws_security_group.opmng_sg.id
#  ]
#  key_name = aws_key_pair.keypair.key_name
#  # user_data                   = file("./src/initialize.sh")
#
#  tags = {
#    Name    = "${var.project}-${var.environment}-app-ec2"
#    Project = var.project
#    Env     = var.environment
#    Type    = "app"
#  }
#}

# ---------------------------------------------
# launch template
# ---------------------------------------------
resource "aws_launch_template" "app_lt" {
  update_default_version = true

  name = "${var.project}-${var.environment}-app-lt"

  image_id = data.aws_ami.app.id

  key_name = aws_key_pair.keypair.key_name

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name    = "${var.project}-${var.environment}-app-ec2"
      Project = var.project
      Env     = var.environment
      Type    = "app"
    }
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups = [
      aws_security_group.app_sg.id,
      aws_security_group.opmng_sg.id,
    ]
    delete_on_termination = true
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.app_ec2_profile.name
  }

}

# ---------------------------------------------
# auto scaling group
# ---------------------------------------------
resource "aws_autoscaling_group" "app_asg" {
  name = "${var.project}-${var.environment}-app-asg"

  max_size           = 2
  min_size           = 1
  desired_capacity   = 1

  health_check_grace_period = 300
  health_check_type         = "ELB"

  vpc_zone_identifier = [
    aws_subnet.public_subnet_1a.id,
    aws_subnet.public_subnet_1c.id
  ]

  target_group_arns = [aws_lb_target_group.alb_target_group.arn]

  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.app_lt.id
        version            = "$Latest"
      }

      override {
        instance_type = "t2.micro"
      }
    }
  }
}

# ---------------------------------------------
# auto scaling  policy set
# ---------------------------------------------
resource "aws_autoscaling_policy" "dev_api_scale_out" {
    name = "Instance-ScaleOut-CPU-High"
    scaling_adjustment = 1
    adjustment_type = "ChangeInCapacity"
    cooldown = 300
    autoscaling_group_name = "${aws_autoscaling_group.app_asg.name}"
}

resource "aws_autoscaling_policy" "dev_api_scale_in" {
    name = "Instance-ScaleIn-CPU-Low"
    scaling_adjustment = -1
    adjustment_type = "ChangeInCapacity"
    cooldown = 300
    autoscaling_group_name = "${aws_autoscaling_group.app_asg.name}"
}

resource "aws_cloudwatch_metric_alarm" "dev_api_high" {
    alarm_name = "dev-api-CPU-Utilization-High-70"
    comparison_operator = "GreaterThanOrEqualToThreshold"
    evaluation_periods = "1"
    metric_name = "CPUUtilization"
    namespace = "AWS/EC2"
    period = "300"
    statistic = "Average"
    threshold = "70"
    alarm_actions = ["${aws_autoscaling_policy.dev_api_scale_out.arn}"]
}

resource "aws_cloudwatch_metric_alarm" "dev_api_low" {
    alarm_name = "dev-api-CPU-Utilization-Low-5"
    comparison_operator = "LessThanThreshold"
    evaluation_periods = "1"
    metric_name = "CPUUtilization"
    namespace = "AWS/EC2"
    period = "300"
    statistic = "Average"
    threshold = "5"
    alarm_actions = ["${aws_autoscaling_policy.dev_api_scale_in.arn}"]
}

