# redisai-cuda11-baseimage

Deploy a redisai-cuda11-base image on top of 
AWS Deep Learning AMI (Ubuntu 18.04) Version 36.0, prebuilt with CUDA 10.0, 10.1, 10.2, and 11.0.

-------

#### Deployment

##### Required env variables

The terraform and ansible scripts expect the following env variables to be filled:
```
export EC2_REGION={ ## INSERT REGION ## }
export EC2_ACCESS_KEY={ ## INSERT EC2 ACCESS KEY ## }
export EC2_SECRET_KEY={ ## INSERT EC2 SECRET KEY ## }
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
```

##### Required pub/private keys

The terraform script expects the following public private keys to be present on ~/.ssh/ dir:
```
~/.ssh/perf-cto-joint-tasks.pem
~/.ssh/perf-cto-joint-tasks.pub
```

##### Deployment steps
within project repo

```bash
cd terraform/redisai-cuda11-baseimage
terraform plan
terraform apply
```