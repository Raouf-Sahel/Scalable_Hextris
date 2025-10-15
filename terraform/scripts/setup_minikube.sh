#!/bin/bash
set -euo pipefail

# --- Logging setup ---
TMPLOG="/tmp/hextris_setup_$(date +%s).log"
LOG="/var/log/hextris_setup.log"

# Rediriger la sortie vers un log temporaire (accessible à l'utilisateur non root)
exec > >(tee -a "$TMPLOG") 2>&1

echo "=== Hextris setup started: $(date -u) ==="

# Fonction finale exécutée à la sortie (copie du log + permissions)
finalize_log() {
  echo "=== Hextris setup finished: $(date -u) ==="
  echo "[+] Copying setup log to $LOG ..."
  sudo mkdir -p "$(dirname "$LOG")"
  sudo cp "$TMPLOG" "$LOG"
  sudo chmod 644 "$LOG"
}
trap finalize_log EXIT

# --- Step 1: Prerequisites ---
echo "[+] Installing base dependencies..."
sudo apt-get update -y
sudo apt-get install -y docker.io curl apt-transport-https ca-certificates conntrack git unzip

# --- Step 2: kubectl ---
echo "[+] Installing kubectl..."
KREL=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)
curl -sLO "https://storage.googleapis.com/kubernetes-release/release/${KREL}/bin/linux/amd64/kubectl"
sudo install kubectl /usr/local/bin/kubectl
rm -f kubectl

# --- Step 3: Helm ---
echo "[+] Installing Helm..."
curl -s https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# --- Step 4: Minikube ---
echo "[+] Installing Minikube..."
if ! command -v minikube >/dev/null 2>&1; then
  curl -sLo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
  sudo install minikube /usr/local/bin/minikube
  rm -f minikube
fi

# --- Step 5: Terraform ---
echo "[+] Installing Terraform..."
TF_VERSION="1.9.5"
curl -sLo terraform.zip "https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip"
unzip -o terraform.zip >/dev/null
sudo install terraform /usr/local/bin/terraform
rm -f terraform.zip terraform

# --- Step 6: Start Minikube ---
echo "[+] Starting Minikube..."
if ! sudo minikube status >/dev/null 2>&1; then
  sudo minikube start --driver=docker --cpus=2 --memory=4096
fi

echo "[+] Enabling ingress..."
sudo minikube addons enable ingress || true

# --- Step 7: Clone Git repo ---
WORKDIR="/opt/scalable_hextris"
REPO_URL="https://github.com/Raouf-Sahel/Scalable_Hextris.git"

echo "[+] Cloning repository..."
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

# --- Step 8: Docker image ---
echo "[+] Building Docker image inside Minikube..."
eval "$(sudo minikube docker-env)"
docker build -t hextris:latest .

# --- Step 9: Helm deploy ---
INGRESS_HOST="${INGRESS_HOST:-$(hostname -I | awk '{print $1}')}"
echo "[+] Deploying Hextris via Helm (host: ${INGRESS_HOST})..."
helm upgrade --install hextris ./helm/hextris --set ingress.host="${INGRESS_HOST}"

# --- Step 10: Verify ---
echo "[+] Waiting for pods to be ready..."
kubectl rollout status deployment/hextris --timeout=180s || true

echo "[✓] Hextris setup completed successfully!"
