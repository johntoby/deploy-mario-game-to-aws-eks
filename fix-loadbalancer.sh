#!/bin/bash

echo "Fixing Load Balancer Issues..."

# Step 1: Update kubeconfig
echo "Step 1: Updating kubeconfig..."
aws eks update-kubeconfig --region us-west-1 --name super-mario-cluster

# Step 2: Apply Terraform changes
echo "Step 2: Applying Terraform changes..."
terraform apply -auto-approve

# Step 3: Install cert-manager
echo "Step 3: Installing cert-manager..."
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.5.4/cert-manager.yaml
sleep 30

# Step 4: Install AWS Load Balancer Controller
echo "Step 4: Installing AWS Load Balancer Controller..."
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.1/docs/install/iam_policy.json

# Get account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create service account
eksctl create iamserviceaccount \
  --cluster=super-mario-cluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name "AmazonEKSLoadBalancerControllerRole" \
  --attach-policy-arn=arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve

# Install controller
kubectl apply -f https://github.com/kubernetes-sigs/aws-load-balancer-controller/releases/download/v2.4.1/v2_4_1_full.yaml

# Patch deployment
kubectl patch deployment aws-load-balancer-controller -n kube-system -p '{"spec":{"template":{"spec":{"containers":[{"name":"controller","args":["--cluster-name=super-mario-cluster","--ingress-class=alb"]}]}}}}'

# Step 5: Redeploy application
echo "Step 5: Redeploying application..."
kubectl delete -f deployment.yaml --ignore-not-found
kubectl delete -f service.yaml --ignore-not-found
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml

# Step 6: Check status
echo "Step 6: Checking status..."
kubectl get pods -n kube-system | grep aws-load-balancer-controller
kubectl get svc super-mario-service
kubectl get events --sort-by=.metadata.creationTimestamp | tail -10

echo "Done! Wait 2-3 minutes then check: kubectl get svc super-mario-service"