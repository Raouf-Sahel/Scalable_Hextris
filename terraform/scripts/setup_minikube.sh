#!/bin/bash
set -euo pipefail

# --- Logging setup ---
TMPLOG="/tmp/hextris_setup_$(date +%s).log"
LOG="/var/log/hextris_setup.log"

# Try to prepare log location (ignore permission errors)
sudo mkdir -p /var/log 2>/dev/null || true
sudo touch "$LOG" 2>/dev/null || true
sudo chmod 666 "$LOG" 2>/dev/null || true

# Redirect stdout + stderr to a temp log accessible to current user
exec > >(tee -a "$TMPLOG") 2>&1

echo "=== Hextris setup started: $(date -u) ==="

# Finalize logs cleanly at exit
finalize_log() {
  echo "=== Hextris setup finished: $(date -u) ==="
  if sudo test -d /var/log; then
    echo "[+] Copying setup log to $LOG ..."
    sudo cp "$TMPLOG" "$LOG" 2>/dev/null || true
    sudo chmod 644 "$LOG" 2>/dev/null || true
  else
    echo "[!] Could not copy log to /var/log — check $TMPLOG instead"
  fi
}
trap finalize_log EXIT

# --- Step 1: Install dependencies ---
echo "[+] Installing base dependencies..."
sudo apt-get update -y
sudo apt-get install -y docker.io curl apt-transport-https ca-certificates conntrack git unzip

# --- Step 2: Install kubectl ---
echo "[+] Installing kubectl..."
KREL=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)
curl -sLO "https://storage.googleapis.com/kubernetes-release/release/${KREL}/bin/linux/amd64/kubectl"
sudo install kubectl /usr/local/bin/kubectl
rm -f kubectl

# --- Step 3: Install Helm ---
echo "[+] Installing Helm..."
curl -s https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# --- Step 4: Install Minikube ---
echo "[+] Installing Minikube..."
if ! command -v minikube >/dev/null 2>&1; then
  curl -sLo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
  sudo install minikube /usr/local/bin/minikube
  rm -f minikube
fi

# --- Step 5: Install Terraform ---
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
else
  echo "[✓] Minikube already running."
fi

echo "[+]()
