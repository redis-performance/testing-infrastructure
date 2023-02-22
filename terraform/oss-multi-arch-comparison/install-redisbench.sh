#!/bin/bash
sudo apt update -y
sudo apt install python3-pip -y
sudo pip3 install --upgrade pip
sudo pip3 install pyopenssl --upgrade
sudo apt install docker.io -y
docker --version
pip3 install redis-benchmarks-specification  --ignore-installed PyYAML
sudo groupadd docker
sudo usermod -aG docker $USER
docker run hello-world
