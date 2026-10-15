#!/usr/bin/env bash
# ==============================================================================
# AWS EC2 Automated Setup Script: Jenkins, Docker, Minikube & Kubectl
# Designed for: Ubuntu 22.04 / 24.04 LTS on AWS EC2 (t3.medium / t2.medium)
# Author: DevOps Automation Suite (CCA-2)
# ==============================================================================

set -euo pipefail

echo "=========================================================="
echo " Starting Full Automated DevOps Host Installation on EC2 "
echo "=========================================================="

# 1. Update and install basic dependencies
sudo apt-get update -y
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    apt-transport-https \
    git \
    conntrack \
    jq

# 2. Install OpenJDK 17 (Required by Jenkins LTS)
echo "[1/6] Installing OpenJDK 17..."
sudo apt-get install -y openjdk-17-jdk
java -version

# 3. Install Node.js 20 LTS (For local pipeline testing stage)
echo "[2/6] Installing Node.js 20 LTS..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
node --version

# 4. Install Docker Engine
echo "[3/6] Installing Docker Engine..."
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Enable and start Docker service
sudo systemctl enable docker
sudo systemctl start docker

# Add ubuntu user to docker group
sudo usermod -aG docker ubuntu

# 5. Install Jenkins LTS
echo "[4/6] Installing Jenkins LTS..."
sudo wget -O /usr/share/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

sudo apt-get update -y
sudo apt-get install -y jenkins

# Add jenkins user to docker group
sudo usermod -aG docker jenkins

# Restart Jenkins to apply group membership
sudo systemctl enable jenkins
sudo systemctl restart jenkins

# 6. Install kubectl
echo "[5/6] Installing kubectl..."
K8S_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
curl -LO "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl
kubectl version --client

# 7. Install Minikube
echo "[6/6] Installing Minikube..."
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
rm minikube-linux-amd64
minikube version

echo "=========================================================="
echo " Setting up Minikube Cluster and Jenkins Permissions "
echo "=========================================================="

# Start Minikube as user ubuntu using Docker driver
sudo -u ubuntu -H minikube start --driver=docker --cni=bridge

# Wait for cluster readiness
sudo -u ubuntu -H kubectl get nodes

# Configure Kubeconfig for the Jenkins user
echo "[INFO] Granting Jenkins pipeline access to Minikube cluster..."
sudo mkdir -p /var/lib/jenkins/.kube
sudo cp /home/ubuntu/.kube/config /var/lib/jenkins/.kube/config
sudo chown -R jenkins:jenkins /var/lib/jenkins/.kube

# Allow jenkins to read minikube certificates
sudo chmod -R 755 /home/ubuntu/.minikube

# Restart Jenkins to ensure all environment settings are fresh
sudo systemctl restart jenkins

echo "=========================================================="
echo " INSTALLATION COMPLETE! "
echo "=========================================================="
echo "Jenkins Service Status: $(sudo systemctl is-active jenkins)"
echo "Docker Service Status:  $(sudo systemctl is-active docker)"
echo "Minikube Cluster Status: Ready"
echo ""
echo "Initial Jenkins Admin Password:"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
echo "=========================================================="
