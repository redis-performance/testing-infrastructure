#!/bin/bash

# Update your kubeconfig for the EKS cluster
aws eks update-kubeconfig --region us-east-2 --name re-eks-cluster-5-nodes-r7i-16xlarge

# Deploy Redis Enterprise Cluster on EKS
kubectl create namespace rec-large-scale
kubectl config set-context --current --namespace=rec-large-scale

VERSION=7.22.0-7
kubectl apply -f https://raw.githubusercontent.com/RedisLabs/redis-enterprise-k8s-docs/$VERSION/bundle.yaml


kubectl get deployment redis-enterprise-operator
