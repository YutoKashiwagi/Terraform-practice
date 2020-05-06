provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region = "ap-northeast-1"
}

resource "aws_vpc" "vue_rails_vpc" {
  cidr_block = "10.1.0.0/16"
  instance_tenancy = "default"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "vue_rails_vpc"
  }
}

resource "aws_subnet" "vue_rails_public_web" {
  vpc_id = "${aws_vpc.vue_rails_vpc.id}"
  cidr_block = "10.1.1.11/24"
  availability_zone = "ap-northeast-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "vue_rails_public_web"
  }
}

resource "aws_subnet" "vue_rails_private_db" {
  vpc_id = "${aws_vpc.vue_rails_vpc.id}"
  cidr_block = "10.1.2.11/24"
  availability_zone = "ap-northeast-1a"
  tags = {
    Name = "vue_rails_private_db"
  }
}

resource "aws_subnet" "vue_rails_multi_az" {
  vpc_id = "${aws_vpc.vue_rails_vpc.id}"
  cidr_block = "10.1.3.11/24"
  availability_zone = "ap-northeast-1c"
  tags = {
    Name = "vue_rails_multi_az"
  }
}

resource "aws_internet_gateway" "vue_rails_gateway" {
  vpc_id = "${aws_vpc.vue_rails_vpc.id}"
  tags = {
    Name = "vue_rails_gateway"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = "${aws_vpc.vue_rails_vpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.vue_rails_gateway.id}"
  }
  tags = {
    Name = "public_route_table"
  }
}

resource "aws_route_table_association" "public_association" {
  subnet_id = "${aws_subnet.vue_rails_public_web.id}"
  route_table_id = "${aws_route_table.public_route_table.id}"
}

resource "aws_security_group" "app" {
  name = "vue_rails_web"
  description = "It is a security group on http of vue_rails_vpc"
  vpc_id = "${aws_vpc.vue_rails_vpc.id}"
  tags = {
    Name = "vue_rails_web"
  }
}

resource "aws_security_group_rule" "ssh" {
  type = "ingress"
  # 22: ssh接続
  from_port = 22
  to_port = 22
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.app.id}"
}

resource "aws_security_group_rule" "web" {
  type = "ingress"
  # 80: インターネットからの接続
  from_port = 80
  to_port = 80
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.app.id}"
}

resource "aws_security_group_rule" "all" {
  type = "egress"
  # 65535: サーバからインターネットへの接続
  from_port = 0
  to_port = 65535
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.app.id}"
}

resource "aws_security_group" "db" {
  name = "db_server"
  description = "It is a security group on db of vue_rails_vpc"
  vpc_id = "${aws_vpc.vue_rails_vpc.id}"
  tags = {
    Name = "vue_rails_db"
  }
}

resource "aws_security_group_rule" "db" {
  type = "ingress"
  # 3306: アプリケーションサーバーの接続
  from_port = 3306
  to_port = 3306
  protocol = "tcp"
  source_security_group_id = "${aws_security_group.app.id}"
  security_group_id = "${aws_security_group.db.id}"
}

resource "aws_db_subnet_group" "main" {
  name = "vue_rails_db_subnet"
  description = "It is a DB subnet group on vue_rails vpc"
  subnet_ids = ["${aws_subnet.vue_rails_private_db.id}", "${aws_subnet.vue_rails_multi_az.id}"]
  tags = {
    Name = "vue_rails_db_subnet"
  }
}

resource "aws_db_instance" "db" {
  identifier = "vuerailsdbinstance"
  allocated_storage = 5
  engine = "mysql"
  engine_version = "5.7.26"
  instance_class = "db.t2.micro"
  storage_type = "gp2"
  username = "${var.aws_db_username}"
  password = "${var.aws_db_password}"
  backup_retention_period = 1
  vpc_security_group_ids = ["${aws_security_group.db.id}"]
  db_subnet_group_name = "${aws_db_subnet_group.main.name}"
}

resource "aws_instance" "web" {
  ami = "ami-052652af12b58691f"
  instance_type = "t2.micro"
  # key_name = "${var.aws_key_name}"
  vpc_security_group_ids = ["${aws_security_group.app.id}"]
  subnet_id = "${aws_subnet.vue_rails_public_web.id}"
  associate_public_ip_address = "true"
  root_block_device {
    volume_type = "gp2"
    volume_size = "20"
  }
  # ebs_block_device {
  #   device_type = "/dev/xvda"
  #   volume_type = "gp2"
  #   volume_size = "100"
  # }
  tags = {
    Name = "vue_rails_instance"
  }
}

resource "aws_eip" "web" {
  instance = "${aws_instance.web.id}"
  vpc = true
}

output "elastic_ip_of_web" {
  value = "${aws_eip.web.public_ip}"
}

variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "aws_db_username" {}
variable "aws_db_password" {}
# variable "aws_key_name" {}
