#!/usr/bin/env bash
set -e
export DEBIAN_FRONTEND=noninteractive

echo "[1/4] Installing dependencies..."
apt-get update -y
apt-get install -y curl ca-certificates gnupg

echo "[2/4] Installing kubectl..."
K8S_VER=$(curl -L -s https://dl.k8s.io/release/stable.txt)
curl -LO "https://dl.k8s.io/release/${K8S_VER}/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm -f kubectl

echo "[3/4] Installing Node.js 20..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

echo "[4/4] Installing Docker CLI..."
apt-get install -y docker.io

echo "--- Tool Verification inside Jenkins ---"
node --version
kubectl version --client
docker --version
