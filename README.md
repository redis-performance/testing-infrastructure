# testing-infrastructure
This repo aims to provide severall testing golden images and setups, to ensure the minimum requirements and toolset to be present. 

-------

#### Deployment

##### Deployment Agent Pre-requesites
- awscli installed 
- terraform installed
- ansible installed
- Ansible linux-system-roles.tuned installed ( run setup.sh )

###### ubuntu install
```
# install dependencies
sudo apt install -y awscli ansible zip 

# install terraform
wget https://releases.hashicorp.com/terraform/0.13.5/terraform_0.13.5_linux_amd64.zip
unzip terraform_0.13.5_linux_amd64.zip
sudo mv terraform /usr/local/bin
rm terraform_0.13.5_linux_amd64.zip
terraform --version

git clone https://github.com/RedisLabsModules/testing-infrastructure
cd testing-infrastructure

./setup.sh
```

##### Required env variables

The terraform and ansible scripts expect the following env variables to be filled:
```
export EC2_REGION={ ## INSERT REGION ## }
export EC2_ACCESS_KEY={ ## INSERT EC2 ACCESS KEY ## }
export EC2_SECRET_KEY={ ## INSERT EC2 SECRET KEY ## }
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
export GRAFANA_PASSWORD=perf
export RE_LICENSE="{ ## INSERT RE LICENSE KEY ## }"
```

##### Deployment steps
```bash
terraform plan
terraform apply
```