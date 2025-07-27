#!/bin/bash

# Quick fix for load balancer issue
aws eks update-kubeconfig --region us-west-1 --name super-mario-cluster

# Apply terraform changes
terraform apply -auto-approve

# Install AWS Load Balancer Controller using Helm
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=super-mario-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

# Redeploy app
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml

# Check status
kubectl get svc super-mario-service