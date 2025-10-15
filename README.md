# 🚀 Scalable Hextris – Deployment Guide

This repository demonstrates a complete **DevOps pipeline** for deploying a **scalable web application (Hextris)** on Kubernetes — either **locally**, **on a remote VM with Terraform**, or **automatically via Jenkins CI/CD**.

---

## 🧩 Project Structure

```
Scalable_Hextris/
├── Dockerfile
├── helm/
│   └── hextris/             # Helm chart for Kubernetes deployment
├── terraform/
│   ├── main.tf              # Terraform logic to run remote setup
│   ├── variables.tf
│   ├── outputs.tf
│   └── scripts/
│       └── setup_minikube.sh  # Remote setup script (Minikube + Helm)
├── Jenkinsfile              # Full CI/CD pipeline
└── README.md                # This file
```

---

## 🧰 1. Prerequisites

### 🧑‍💻 Local deployment (Minikube)
You’ll need the following installed on your system:

| Tool | Version | Installation Command |
|------|----------|----------------------|
| **Docker** | ≥ 20.x | [Install Docker](https://docs.docker.com/engine/install/) |
| **Kubectl** | ≥ 1.28 | `curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl && sudo install kubectl /usr/local/bin/` |
| **Minikube** | ≥ 1.30 | `curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 && sudo install minikube-linux-amd64 /usr/local/bin/minikube` |
| **Helm** | ≥ 3.x | `curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash` |

Make sure:
- You have **at least 4 GB RAM** free.  
- **Port 8080** is accessible (for testing locally).  
- Docker is **running** before starting Minikube.  

---

## ⚙️ 2. Local Deployment

### Step 1 — Clone the Repository
```bash
git clone https://github.com/Raouf-Sahel/Scalable_Hextris.git
cd Scalable_Hextris
```

### Step 2 — Start Minikube
```bash
minikube start --driver=docker --cpus=2 --memory=4096
minikube addons enable ingress
```

### Step 3 — Build the Docker Image
```bash
eval $(minikube docker-env)
docker build -t hextris:latest .
```

### Step 4 — Deploy with Helm
```bash
helm upgrade --install hextris ./helm/hextris   --set ingress.enabled=true   --set ingress.host="hextris.local"
```

### Step 5 — Access the Application
Add an entry to your `/etc/hosts` file:
```bash
echo "$(minikube ip) hextris.local" | sudo tee -a /etc/hosts
```

Then open:
👉 [http://hextris.local](http://hextris.local)

---

## ☁️ 3. Remote Deployment using Terraform

This mode installs everything (Docker, Minikube, Helm, Hextris) on a remote **Ubuntu VM**.

### VM Requirements
- Ubuntu 22.04+  
- Open ports:
  - `22` → SSH  
  - `8080` → Hextris public access  
- Access via **SSH private key (.pem)**  

> ⚠️ The Terraform variable `ssh_private_key` is automatically passed by Jenkins from the Jenkins credential **`vm_ssh_key`**.  
> Make sure to **replace this credential with your own SSH key** to connect to your VM.

---

### Step 1 — Install Terraform
```bash
sudo apt-get update -y
sudo apt-get install -y unzip curl
curl -Lo terraform.zip "https://releases.hashicorp.com/terraform/1.9.5/terraform_1.9.5_linux_amd64.zip"
unzip terraform.zip
sudo install terraform /usr/local/bin/terraform
```

### Step 2 — Initialize and Apply Terraform
```bash
cd terraform
terraform init

terraform apply   -var="remote_host=<YOUR_VM_PUBLIC_IP>"   -var="ssh_user=ubuntu"   -var="ssh_private_key=$(cat ~/.ssh/mykey.pem)"   -auto-approve
```

Once the deployment completes, the output will include:
```
app_url = "http://<YOUR_VM_PUBLIC_IP>:8080"
```

---

## 🤖 4. Jenkins CI/CD Pipeline

The Jenkins pipeline automates the entire process — from provisioning to deployment.

### Requirements
- Jenkins running in Kubernetes  
- Kubernetes plugin enabled  
- Jenkins credential `vm_ssh_key` of type **SSH Private Key**  
  - Replace it with your actual VM key  
- Network access from Jenkins to your VM

---

### Pipeline Parameters
| Parameter | Description |
|------------|-------------|
| `REMOTE_HOST` | Public IP of your target VM |
| `SSH_USER` | SSH username (`ubuntu` by default) |

---

### What the Pipeline Does
1. **Checkout code** from GitHub  
2. **Run Terraform** to connect to the remote VM and execute `setup_minikube.sh`  
3. **Wait for installation** (Docker, Minikube, Helm, Hextris)  
4. **Retrieve setup logs** from `/var/log/hextris_setup.log`  
5. **Archive logs** into Jenkins artifacts  
6. **Output** the public URL:  
   👉 `http://<REMOTE_HOST>:8080`

---

## 🔍 5. Post-Deployment Validation

On the target VM:
```bash
kubectl get pods
kubectl get svc
kubectl get ingress
```

Expected output:
```
NAME                           READY   STATUS    RESTARTS   AGE
pod/hextris-699dc8d75b-vprn8   1/1     Running   0          2m
```

---

## 🧹 6. Cleanup

### Local environment
```bash
helm uninstall hextris
minikube delete
```

### Remote VM (Terraform)
```bash
cd terraform
terraform destroy -auto-approve
```

---

## ⚠️ 7. Common Issues & Fixes

| Issue | Cause | Fix |
|-------|--------|-----|
| `ImagePullBackOff` | Image not found in Minikube | Run `eval $(minikube docker-env)` before `docker build` |
| `Ingress invalid host` | IP address used instead of DNS name | Use `nip.io` hostname: `hextris.<IP>.nip.io` |
| `Minikube stopped` | VM rebooted or resource limit | Run `sudo minikube start --force` |
| `Permission denied` in `/var/log/` | Script writing without privileges | Fixed in latest `setup_minikube.sh` (uses `sudo`) |
| `Port 8080 not reachable` | Security group or firewall blocked | Open port 8080 in your VM’s inbound rules |

---

## ✅ 8. Quick Summary

| Mode | Command | Access URL |
|------|----------|------------|
| **Local (Minikube)** | `helm upgrade --install hextris ./helm/hextris` | `http://hextris.local` |
| **Terraform (VM)** | `terraform apply -auto-approve` | `http://<YOUR_VM_PUBLIC_IP>:8080` |
| **Jenkins CI/CD** | Jenkins pipeline “Hextris Deployment” | `http://<REMOTE_HOST>:8080` |
