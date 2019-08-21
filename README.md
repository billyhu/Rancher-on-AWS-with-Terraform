# Rancher-on-AWS-with-Terraform
Launch Rancher on AWS with Terraform and enabled ingress with nginx and ELB

## Amazon AWS

The aws folder contains terraform code to stand up a single Rancher server instance with a 1 node cluster attached to it.

You will need the following:

- An AWS Account with an access key and secret key
- The name of a pre-created AWS Key Pair
- Your desired AWS Deployment Region

This terraform setup will:

- Start an Amazon AWS EC2 instance running `rancher/rancher` version specified in `rancher_version`
- Create a custom cluster called `cluster_name`
- Start `count_agent_all_nodes` amount of AWS EC2 instances and add them to the custom cluster with all roles

### How to use

- Clone this repository and go into the aws subfolder
- Move the file `terraform.tfvars.example` to `terraform.tfvars` and edit (see inline explanation)
- Run `terraform init`
- Run `terraform apply`

When provisioning has finished you will be given the url to connect to the Rancher Server

### How to Remove

To remove the VM's that have been deployed run `terraform destroy --force`

### Optional adding nodes per role
- Start `count_agent_all_nodes` amount of AWS EC2 Instances and add them to the custom cluster with all role
- Start `count_agent_etcd_nodes` amount of AWS EC2 Instances and add them to the custom cluster with etcd role
- Start `count_agent_controlplane_nodes` amount of AWS EC2 Instances and add them to the custom cluster with controlplane role
- Start `count_agent_worker_nodes` amount of AWS EC2 Instances and add them to the custom cluster with worker role

**Please be aware that you will be responsible for the usage charges with Amazon AWS**

## Example commands:

### Generate AWS Key Pair for A Region

### Terraform:
- sudo yum update
- sudo yum install wget unzip
- wget https://releases.hashicorp.com/terraform/0.11.13/terraform_0.11.13_linux_amd64.zip
- sudo unzip ./terraform_0.11.13_linux_amd64.zip -d /usr/local/bin/
- terraform -v

- terraform init
- terraform plan -out=rancher.plan -var 'aws_vpc_cidr_block="xxx.xxx.xxx.xxx/xx"' -var 'aws_cidr_subnets_public=["xxx.xxx.xxx.xxx/xx","xxx.xxx.xxx.xxx/xx"]' -var 'aws_cidr_subnets_private=["xxx.xxx.xxx.xxx/xx","xxx.xxx.xxx.xxx/xx"]' -var 'region="region_id"'
- terraform apply -auto-approve rancher.plan
- terraform output -json > output.json

### Jq
- sudo yum install epel-release -y
- sudo yum install jq -y
- jq --version

### Install Rancher CLI
- wget -O rancher-cli.tar.gz $(curl -s https://api.github.com/repos/rancher/cli/releases/latest | grep browser_download_url | grep 'linux-amd64' | head -n 1 | cut -d '"' -f 4)
- sudo tar -xzvf rancher-cli.tar.gz -C /usr/local/bin --strip-components=2
- rancher -v
- rm rancher-cli.tar.gz -f

### Rancher:
- curl -X POST -H 'content-type: application/json' --data-binary '{"username":"admin","password":"yourpassword"}' --insecure https://YOUR_SERVER/v3-public/localProviders/local?action=login > token.json
- echo "yes" | rancher login --token yourtoken https://YOUR_SERVER

- rancher clusters
- rancher clusters kf CLUSTER_ID CLUSTER_NAME > kubeconfig.yaml
- export KUBECONFIG=$(pwd)/kubeconfig.yaml

- rancher projects create yourproject
- rancher context switch yourproject
- rancher namespaces create yournamespace

- rancher catalog add helm https://kubernetes-charts.storage.googleapis.com/
- rancher catalog refresh -w helm
- rancher apps install cattle-global-data:helm-nginx-ingress nginx-ingress

### kubectl
- curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
- chmod +x ./kubectl
- sudo mv ./kubectl /usr/local/bin/kubectl
- kubectl version

- kubectl create secret docker-registry repo-registry \
- --docker-server=repo-docker-local.jfrog.io \
- --docker-username= \
- --docker-email= \
- --namespace=yournamespace

### Helm:
- curl -L https://git.io/get_helm.sh | bash
- kubectl -n kube-system create serviceaccount tiller

- kubectl -n kube-system create clusterrolebinding tiller \
  --clusterrole=cluster-admin \
  --serviceaccount=kube-system:tiller

- helm init --service-account tiller

<!-- helm install stable/nginx-ingress --name nginx-ingress \
    --set controller.stats.enabled=true \
    --set controller.metrics.enabled=true  -->
