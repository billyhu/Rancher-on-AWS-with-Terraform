#Credentials
# Amazon AWS Access Key
aws_access_key = ""
# Amazon AWS Secret Key
aws_secret_key = ""
# Amazon AWS Key Pair Name
ssh_key_name = "vpc-rancher"
# Amazon AWS Public Key
public_key = ""

#Global Vars
aws_cluster_name = "rancher"
default_tags = {
  Env = "uat"
  Product = "rancher-cluster"
}

#VPC Vars
aws_vpc_cidr_block = "10.120.128.0/18"
aws_cidr_subnets_private = ["10.120.128.0/20","10.120.144.0/20"]
aws_cidr_subnets_public = ["10.120.160.0/20","10.120.176.0/20"]

# Region where resources should be created
region = "eu-east-1"
# Resources will be prefixed with this to avoid clashing names
prefix = "xxx-rancher"
# Admin password to access Rancher
admin_password = ""
# Name of custom cluster that will be created
cluster_name = "rancher"
# rancher/rancher image tag to use
rancher_version = "latest"
# Count of agent nodes with role all
count_agent_all_nodes = "3"
# Count of agent nodes with role etcd
count_agent_etcd_nodes = "0"
# Count of agent nodes with role controlplane
count_agent_controlplane_nodes = "0"
# Count of agent nodes with role worker
count_agent_worker_nodes = "0"
# Docker version of host running `rancher/rancher`
docker_version_server = "18.09"
# Docker version of host being added to a cluster (running `rancher/rancher-agent`)
docker_version_agent = "18.09"
# AWS Instance Type
type = "m5.xlarge"
