# Configure the Amazon AWS Provider
provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "${var.region}"
}

data "aws_availability_zones" "available" {}

module "aws-vpc" {
  source = "modules/vpc"

  aws_cluster_name         = "${var.aws_cluster_name}"
  aws_vpc_cidr_block       = "${var.aws_vpc_cidr_block}"
  aws_avail_zones          = "${slice(data.aws_availability_zones.available.names,0,2)}"
  aws_cidr_subnets_private = "${var.aws_cidr_subnets_private}"
  aws_cidr_subnets_public  = "${var.aws_cidr_subnets_public}"
  default_tags             = "${var.default_tags}"
}

module "aws-iam" {
  source = "modules/iam"

  aws_cluster_name = "${var.aws_cluster_name}"
}

variable "aws_access_key" {
  default     = "xxx"
  description = "Amazon AWS Access Key"
}

variable "aws_secret_key" {
  default     = "xxx"
  description = "Amazon AWS Secret Key"
}

variable "prefix" {
  default     = "yourname"
  description = "Cluster Prefix - All resources created by Terraform have this prefix prepended to them"
}

variable "rancher_version" {
  default     = "latest"
  description = "Rancher Server Version"
}

variable "count_agent_all_nodes" {
  default     = "1"
  description = "Number of Agent All Designation Nodes"
}

variable "count_agent_etcd_nodes" {
  default     = "0"
  description = "Number of ETCD Nodes"
}

variable "count_agent_controlplane_nodes" {
  default     = "0"
  description = "Number of K8s Control Plane Nodes"
}

variable "count_agent_worker_nodes" {
  default     = "0"
  description = "Number of Worker Nodes"
}

variable "admin_password" {
  default     = "admin"
  description = "Password to set for the admin account in Rancher"
}

variable "cluster_name" {
  default     = "quickstart"
  description = "Kubernetes Cluster Name"
}

variable "region" {
  default     = "us-west-2"
  description = "Amazon AWS Region for deployment"
}

variable "type" {
  default     = "t3.medium"
  description = "Amazon AWS Instance Type"
}

variable "docker_version_server" {
  default     = "18.09"
  description = "Docker Version to run on Rancher Server"
}

variable "docker_version_agent" {
  default     = "18.09"
  description = "Docker Version to run on Kubernetes Nodes"
}

variable "ssh_key_name" {
  default     = ""
  description = "Amazon AWS Key Pair Name"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "rancher_sg_allowall" {
  name = "${var.prefix}-allowall"

  ingress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = "${merge(var.default_tags, map(
      "Name", "${var.prefix}-allowall",
      "kubernetes.io/cluster/${var.aws_cluster_name}", "owned"
    ))}"
}

data "template_cloudinit_config" "rancherserver-cloudinit" {
  part {
    content_type = "text/cloud-config"
    content      = "hostname: ${var.prefix}-rancherserver\nmanage_etc_hosts: true"
  }

  part {
    content_type = "text/x-shellscript"
    content      = "${data.template_file.userdata_server.rendered}"
  }
}

resource "aws_instance" "rancherserver" {
  ami                         = "${data.aws_ami.ubuntu.id}"
  instance_type               = "${var.type}"
  key_name                    = "${var.ssh_key_name}"
  associate_public_ip_address = true
  vpc_security_group_ids      = ["${module.aws-vpc.aws_security_group}"]
  user_data                   = "${data.template_cloudinit_config.rancherserver-cloudinit.rendered}"
  availability_zone           = "${element(slice(data.aws_availability_zones.available.names,0,2),count.index)}"
  subnet_id                   = "${element(module.aws-vpc.aws_subnet_ids_public,count.index)}"

  tags = "${merge(var.default_tags, map(
      "Name", "${var.prefix}-rancherserver",
      "kubernetes.io/cluster/${var.aws_cluster_name}", "owned"
    ))}"
}

data "template_cloudinit_config" "rancheragent-all-cloudinit" {
  count = "${var.count_agent_all_nodes}"

  part {
    content_type = "text/cloud-config"
    content      = "hostname: ${var.prefix}-rancheragent-${count.index}-all\nmanage_etc_hosts: true"
  }

  part {
    content_type = "text/x-shellscript"
    content      = "${data.template_file.userdata_agent.rendered}"
  }
}

resource "aws_instance" "rancheragent-all" {
  count                       = "${var.count_agent_all_nodes}"
  ami                         = "${data.aws_ami.ubuntu.id}"
  instance_type               = "${var.type}"
  key_name                    = "${var.ssh_key_name}"
  associate_public_ip_address = true
  vpc_security_group_ids      = ["${module.aws-vpc.aws_security_group}"]
  user_data                   = "${data.template_cloudinit_config.rancheragent-all-cloudinit.*.rendered[count.index]}"
  availability_zone           = "${element(slice(data.aws_availability_zones.available.names,0,2),count.index)}"
  subnet_id                   = "${element(module.aws-vpc.aws_subnet_ids_public,count.index)}"
  iam_instance_profile        = "${module.aws-iam.kube-master-profile}"

  tags = "${merge(var.default_tags, map(
      "Name", "${var.prefix}-rancheragent-${count.index}-all",
      "kubernetes.io/cluster/${var.aws_cluster_name}", "owned"
    ))}"
}

data "template_cloudinit_config" "rancheragent-etcd-cloudinit" {
  count = "${var.count_agent_etcd_nodes}"

  part {
    content_type = "text/cloud-config"
    content      = "hostname: ${var.prefix}-rancheragent-${count.index}-etcd\nmanage_etc_hosts: true"
  }

  part {
    content_type = "text/x-shellscript"
    content      = "${data.template_file.userdata_agent.rendered}"
  }
}

resource "aws_instance" "rancheragent-etcd" {
  count                       = "${var.count_agent_etcd_nodes}"
  ami                         = "${data.aws_ami.ubuntu.id}"
  instance_type               = "${var.type}"
  key_name                    = "${var.ssh_key_name}"
  associate_public_ip_address = true
  vpc_security_group_ids      = ["${module.aws-vpc.aws_security_group}"]
  user_data                   = "${data.template_cloudinit_config.rancheragent-etcd-cloudinit.*.rendered[count.index]}"
  availability_zone           = "${element(slice(data.aws_availability_zones.available.names,0,2),count.index)}"
  subnet_id                   = "${element(module.aws-vpc.aws_subnet_ids_public,count.index)}"
  iam_instance_profile        = "${module.aws-iam.kube-worker-profile}"

  tags = "${merge(var.default_tags, map(
      "Name", "${var.prefix}-rancheragent-${count.index}-etcd",
      "kubernetes.io/cluster/${var.aws_cluster_name}", "owned"
    ))}"
}

data "template_cloudinit_config" "rancheragent-controlplane-cloudinit" {
  count = "${var.count_agent_controlplane_nodes}"

  part {
    content_type = "text/cloud-config"
    content      = "hostname: ${var.prefix}-rancheragent-${count.index}-controlplane\nmanage_etc_hosts: true"
  }

  part {
    content_type = "text/x-shellscript"
    content      = "${data.template_file.userdata_agent.rendered}"
  }
}

resource "aws_instance" "rancheragent-controlplane" {
  count                       = "${var.count_agent_controlplane_nodes}"
  ami                         = "${data.aws_ami.ubuntu.id}"
  instance_type               = "${var.type}"
  key_name                    = "${var.ssh_key_name}"
  associate_public_ip_address = true
  vpc_security_group_ids      = ["${module.aws-vpc.aws_security_group}"]
  user_data                   = "${data.template_cloudinit_config.rancheragent-controlplane-cloudinit.*.rendered[count.index]}"
  availability_zone           = "${element(slice(data.aws_availability_zones.available.names,0,2),count.index)}"
  subnet_id                   = "${element(module.aws-vpc.aws_subnet_ids_public,count.index)}"
  iam_instance_profile        = "${module.aws-iam.kube-master-profile}"

  tags = "${merge(var.default_tags, map(
      "Name", "${var.prefix}-rancheragent-${count.index}-controlplane",
      "kubernetes.io/cluster/${var.aws_cluster_name}", "owned"
    ))}"
}

data "template_cloudinit_config" "rancheragent-worker-cloudinit" {
  count = "${var.count_agent_worker_nodes}"

  part {
    content_type = "text/cloud-config"
    content      = "hostname: ${var.prefix}-rancheragent-${count.index}-worker\nmanage_etc_hosts: true"
  }

  part {
    content_type = "text/x-shellscript"
    content      = "${data.template_file.userdata_agent.rendered}"
  }
}

resource "aws_instance" "rancheragent-worker" {
  count                       = "${var.count_agent_worker_nodes}"
  ami                         = "${data.aws_ami.ubuntu.id}"
  instance_type               = "${var.type}"
  key_name                    = "${var.ssh_key_name}"
  associate_public_ip_address = true
  vpc_security_group_ids      = ["${module.aws-vpc.aws_security_group}"]
  user_data                   = "${data.template_cloudinit_config.rancheragent-worker-cloudinit.*.rendered[count.index]}"
  availability_zone           = "${element(slice(data.aws_availability_zones.available.names,0,2),count.index)}"
  subnet_id                   = "${element(module.aws-vpc.aws_subnet_ids_public,count.index)}"
  iam_instance_profile        = "${module.aws-iam.kube-worker-profile}"

  tags = "${merge(var.default_tags, map(
      "Name", "${var.prefix}-rancheragent-${count.index}-worker",
      "kubernetes.io/cluster/${var.aws_cluster_name}", "owned"
    ))}"
}

data "template_file" "userdata_server" {
  template = "${file("files/userdata_server")}"

  vars {
    admin_password        = "${var.admin_password}"
    cluster_name          = "${var.cluster_name}"
    docker_version_server = "${var.docker_version_server}"
    rancher_version       = "${var.rancher_version}"
  }
}

data "template_file" "userdata_agent" {
  template = "${file("files/userdata_agent")}"

  vars {
    admin_password       = "${var.admin_password}"
    cluster_name         = "${var.cluster_name}"
    docker_version_agent = "${var.docker_version_agent}"
    rancher_version      = "${var.rancher_version}"
    server_address       = "${aws_instance.rancherserver.public_ip}"
  }
}

resource "aws_key_pair" "rancher" {
  key_name   = "vpc-rancher"
  public_key = "${var.public_key}" // your public_key
}

output "rancher-url" {
  value = ["https://${aws_instance.rancherserver.public_ip}"]
}

output "all" {
  value = "${join("\n", aws_instance.rancheragent-all.*.private_ip)}"
}

output "controlplanes" {
  value = "${join("\n", aws_instance.rancheragent-controlplane.*.private_ip)}"
}

output "workers" {
  value = "${join("\n", aws_instance.rancheragent-worker.*.private_ip)}"
}

output "etcd" {
  value = "${join("\n", aws_instance.rancheragent-etcd.*.private_ip)}"
}
