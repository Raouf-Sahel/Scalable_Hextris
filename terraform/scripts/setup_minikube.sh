#!/bin/bash
set -euo pipefail

# --- Logging setup ---
LOG="/var/log/hextris_setup.log"
TMPLOG="/tmp/hextris_setup_$(date +%s).log"

# Rediriger toute la sortie vers un log temporaire accessible par l'utilisateur
exec > >(tee -a "$TMPLOG") 2>&1

echo "=== Hextris setup started: $(date -u) ==="

# Finalisation : copie du log temporaire vers /var/log/ avec les bons droits
finalize_log() {
  echo "=== Hextris setup finished: $(date -u) ==="
  sudo mkdir -p "$(dirname "$LOG")"
  sudo cp "$TMPLOG" "$LOG"
  sudo chmod 644 "$LOG"
}
trap finalize_log EXIT

# --- Étape 1 : Prérequis système ---
echo "[+] Installing base dependencies..."
sudo apt-get update -y
sudo apt-get install -y docker.io curl apt-transport-https ca-certificates conntrack git unzip

# --- Étape 2 : Installation de kubectl ---
echo "[+] Installing kubectl..."
KREL=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)
curl -sLO "https://storage.googleapis.com/kubernetes-release/release/${KREL}/bin/linux/amd64/kubectl"
sudo install kubectl /usr/local/bin/kubectl
rm -f kubectl

# --- Étape 3 : Installation de Helm ---
echo "[+] Installing Helm..."
curl -s https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# --- Étape 4 : Installation de Minikube ---
echo "[+] Installing Minikube..."
if ! command -v minikube >/dev/null 2>&1; then
  curl -sLo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
  sudo install minikube /usr/local/bin/minikube
  rm -f minikube
fi

# --- Étape 5 : Installation de Terraform (utile pour l’automatisation locale) ---
echo "[+] Installing Terraform..."
TF_VERSION="1.9.5"
curl -sLo terraform.zip "https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip"
unzip -o terraform.zip >/dev/null
sudo install terraform /usr/local/bin/terraform
rm -f terraform.zip terraform

# --- Étape 6 : Lancement de Minikube et activation de l’ingress ---
echo "[+] Starting Minikube..."
if ! sudo minikube status >/dev/null 2>&1; then
  sudo minikube start --driver=docker --cpus=2 --memory=4096
fi

echo "[+] Enabling ingress..."
sudo minikube addons enable ingress || true

# --- Étape 7 : Clonage du dépôt Git ---
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

# --- Étape 8 : Construction de l’image Docker dans le contexte Minikube ---
echo "[+] Building Docker image inside Minikube..."
eval "$(sudo minikube docker-env)"
docker build -t hextris:latest .

# --- Étape 9 : Déploiement via Helm ---
INGRESS_HOST="${INGRESS_HOST:-$(hostname -I | awk '{print $1}')}"
echo "[+] Deploying Hextris via Helm (host: ${INGRESS_HOST})..."
helm upgrade --install hextris ./helm/hextris --set ingress.host="${INGRESS_HOST}"

# --- Étape 10 : Vérification du déploiement ---
echo "[+] Waiting for pods to be ready..."
kubectl rollout status deployment/hextris --timeout=180s || true

echo "[✓] Hextris setup completed successfully!"
