#!/bin/bash
set -euo pipefail


LOG="/var/log/hextris_setup.log"
exec > >(tee -a "$LOG") 2>&1

echo "=== Hextris setup started: $(date -u) ==="

# --- Prérequis ---
echo "[+] Installing base dependencies..."
sudo apt-get update -y
sudo apt-get install -y docker.io curl apt-transport-https ca-certificates conntrack git unzip socat

# --- kubectl ---
echo "[+] Installing kubectl..."
KREL=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)
curl -sLO "https://storage.googleapis.com/kubernetes-release/release/${KREL}/bin/linux/amd64/kubectl"
sudo install kubectl /usr/local/bin/kubectl
rm -f kubectl

# --- Helm ---
echo "[+] Installing Helm..."
curl -s https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# --- Minikube ---
echo "[+] Installing Minikube..."
if ! command -v minikube >/dev/null 2>&1; then
  curl -sLo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
  sudo install minikube /usr/local/bin/minikube
  rm -f minikube
fi

# --- Terraform (optionnel pour automatisation locale) ---
echo "[+] Installing Terraform..."
TF_VERSION="1.9.5"
curl -sLo terraform.zip "https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip"
unzip -o terraform.zip
sudo install terraform /usr/local/bin/terraform
rm -f terraform.zip terraform

# --- Autoriser l'utilisateur courant à utiliser Docker ---
echo "[+] Ensuring Docker permissions for user..."
if ! groups $USER | grep -q docker; then
  sudo usermod -aG docker $USER
  echo "[i] Added user to docker group. You may need to log out/in for it to take effect."
fi

# --- Démarrage de Minikube ---
echo "[+] Starting Minikube..."
if ! sudo minikube status >/dev/null 2>&1; then
  # Utilisation du driver "none" pour éviter DRV_AS_ROOT
  sudo minikube start --driver=none --cpus=2 --memory=4096
else
  echo "[✓] Minikube already running."
fi

# --- Activer Ingress ---
echo "[+] Enabling ingress..."
sudo minikube addons enable ingress || true

# --- Cloner le dépôt Git ---
WORKDIR="/opt/scalable_hextris"
REPO_URL="https://github.com/Raouf-Sahel/Scalable_Hextris.git"

echo "[+] Cloning repository..."
sudo mkdir -p "$WORKDIR"
sudo chown -R $(whoami):$(whoami) "$WORKDIR"
cd "$WORKDIR"

if [ ! -d "$WORKDIR/Scalable_Hextris/.git" ]; then
  git clone "$REPO_URL" Scalable_Hextris
else
  cd Scalable_Hextris
  git fetch --all
  git reset --hard origin/main
fi

cd Scalable_Hextris

# --- Construction de l'image Docker ---
echo "[+] Building Docker image inside Minikube..."
eval "$(minikube docker-env)"
docker build -t hextris:latest .

# --- Déploiement avec Helm ---
INGRESS_HOST="${INGRESS_HOST:-$(hostname -I | awk '{print $1}')}"
echo "[+] Deploying Hextris via Helm (host: ${INGRESS_HOST})..."
helm upgrade --install hextris ./helm/hextris --set ingress.host="${INGRESS_HOST}"

# --- Validation du déploiement ---
echo "[+] Waiting for Hextris pods to be ready..."
kubectl rollout status deployment/hextris --timeout=180s || true

echo "=== Hextris setup finished successfully at $(date -u) ==="
