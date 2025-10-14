#!/bin/bash
set -euo pipefail

LOG="/var/log/hextris_setup.log"
exec > >(tee -a "$LOG") 2>&1

echo "=== Hextris setup started: $(date -u) ==="

# --- Prerequisites ---
sudo apt-get update -y
sudo apt-get install -y docker.io curl apt-transport-https ca-certificates conntrack git unzip

# --- kubectl ---
KREL=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)
curl -sLO "https://storage.googleapis.com/kubernetes-release/release/${KREL}/bin/linux/amd64/kubectl"
sudo install kubectl /usr/local/bin/kubectl

# --- Helm ---
curl -s https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# --- Minikube ---
if ! command -v minikube >/dev/null 2>&1; then
  curl -sLo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
  sudo install minikube /usr/local/bin/minikube
fi

# --- Terraform (useful for self-managed automation) ---
TF_VERSION="1.9.5"
curl -sLo terraform.zip "https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip"
unzip -o terraform.zip
sudo install terraform /usr/local/bin/terraform
rm -f terraform.zip terraform

# --- Start Minikube and enable Ingress ---
if ! kubectl get nodes >/dev/null 2>&1; then
  sudo minikube start --driver=docker --cpus=2 --memory=4096
fi
sudo minikube addons enable ingress || true

# --- Clone Git repo ---
WORKDIR="/opt/scalable_hextris"
REPO_URL="https://github.com/Raouf-Sahel/Scalable_Hextris.git"

sudo mkdir -p "$WORKDIR"
sudo chown -R "$USER:$USER" "$WORKDIR"
cd "$WORKDIR"

if [ ! -d "$WORKDIR/Scalable_Hextris/.git" ]; then
  git clone "$REPO_URL" Scalable_Hextris
else
  cd Scalable_Hextris
  git fetch --all
  git reset --hard origin/main
fi
cd Scalable_Hextris

# --- Build Docker image inside Minikube's Docker environment ---
eval $(sudo minikube docker-env)
docker build -t hextris:latest .

# --- Deploy Helm chart ---
INGRESS_HOST="${INGRESS_HOST:-$(hostname -I | awk '{print $1}')}"
helm upgrade --install hextris ./helm/hextris --set ingress.host="${INGRESS_HOST}"

echo "=== Hextris setup finished successfully at $(date -u) ==="

