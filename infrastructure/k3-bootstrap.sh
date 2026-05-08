# Create the k3s bootstrap script
cat > ~/travelease/infrastructure/k3s-bootstrap.sh << 'EOF'
#!/bin/bash
# This script runs automatically when EC2 starts (UserData)
set -e

# Update system
yum update -y
yum install -y curl wget git

# Install Docker
amazon-linux-extras install docker -y
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user

# Install k3s (lightweight Kubernetes)
# --disable traefik because we use NGINX ingress instead
curl -sfL https://get.k3s.io | sh -s - \
  --disable traefik \
  --write-kubeconfig-mode 644 \
  --node-name travelease-master

# Wait for k3s to be ready
sleep 30

# Install Helm (Kubernetes package manager)
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install NGINX ingress controller via Helm
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=NodePort \
  --set controller.service.nodePorts.http=30080 \
  --set controller.service.nodePorts.https=30443

# Install AWS CLI on the node
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./install

# Save kubeconfig to a known location
mkdir -p /home/ec2-user/.kube
cp /etc/rancher/k3s/k3s.yaml /home/ec2-user/.kube/config
chown ec2-user:ec2-user /home/ec2-user/.kube/config

echo "✅ k3s Kubernetes cluster ready!" >> /var/log/k3s-bootstrap.log
echo "Node status:" >> /var/log/k3s-bootstrap.log
kubectl get nodes >> /var/log/k3s-bootstrap.log
EOF

# Base64 encode it for UserData
USERDATA=$(base64 -i ~/travelease/infrastructure/k3s-bootstrap.sh)
