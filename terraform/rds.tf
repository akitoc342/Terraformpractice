# ---------------------------------------------
# RDS parameter group
# ---------------------------------------------
resource "aws_db_parameter_group" "mysql_parametergroup" {
  name   = "${var.project}-${var.environment}-mysql-parametergroup"
  family = "mysql8.0"

  parameter {
    name  = "character_set_database"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }
}


# ---------------------------------------------
# RDS option group
# ---------------------------------------------
resource "aws_db_option_group" "mysql_optiongroup" {
  name                 = "${var.project}-${var.environment}-mysql-optiongroup"
  engine_name          = "mysql"
  major_engine_version = "8.0"
}


# ---------------------------------------------
# RDS subnet group
# ---------------------------------------------
resource "aws_db_subnet_group" "mysql_subnetgroup" {
  name = "${var.project}-${var.environment}-subnetgroup"
  subnet_ids = [
    aws_subnet.private_subnet_1a.id,
    aws_subnet.private_subnet_1c.id
  ]

  tags = {
    Name    = "${var.project}-${var.environment}-mysql-subnetgroup"
    Project = var.project
    Env     = var.environment
  }
}


# ---------------------------------------------
# RDS instance add randompassword
# ---------------------------------------------
resource "random_string" "db_password" {
  length  = 16
  special = false
}

resource "aws_db_instance" "mysql" {
  engine         = "mysql"
  engine_version = "8.0"

  identifier = "${var.project}-${var.environment}-mysql"

  username = "admin"
  password = random_string.db_password.result

  instance_class = "db.t2.micro"

  allocated_storage     = 10
  max_allocated_storage = 20
  storage_type          = "gp2"
  storage_encrypted     = false

  multi_az               = true
  db_subnet_group_name   = aws_db_subnet_group.mysql_subnetgroup.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  publicly_accessible    = false
  port                   = 3306

  name                       = "terraformRDS"
  parameter_group_name       = aws_db_parameter_group.mysql_parametergroup.name
  option_group_name          = aws_db_option_group.mysql_optiongroup.name

  backup_window              = "04:00-05:00"
  backup_retention_period    = 7
  maintenance_window         = "Mon:05:00-Mon:08:00"
  auto_minor_version_upgrade = false

  deletion_protection = false
  skip_final_snapshot = true

  apply_immediately = true

  tags = {
    Name    = "${var.project}-${var.environment}-mysql"
    Project = var.project
    Env     = var.environment
  }
}