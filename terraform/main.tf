terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# Force re-run on each execution using timestamp trigger
resource "null_resource" "remote_setup" {
  triggers = {
    remote_host = var.remote_host
    timestamp   = var.timestamp
  }

  # Copy setup script to the remote machine
  provisioner "file" {
    source      = "${path.module}/scripts/setup_minikube.sh"
    destination = "/home/${var.ssh_user}/setup_minikube.sh"
  }

  # Execute setup script remotely and capture logs
  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /var/log",
      "sudo touch /var/log/hextris_setup.log",
      "sudo chown ${var.ssh_user}:${var.ssh_user} /var/log/hextris_setup.log",
      "sudo chmod 666 /var/log/hextris_setup.log",
      "set -e",
      "chmod +x /home/${var.ssh_user}/setup_minikube.sh",
      # Run script and redirect output to log file
      "sudo /home/${var.ssh_user}/setup_minikube.sh > /var/log/hextris_setup.log 2>&1 || true",
      # Mark end of setup with UTC timestamp
      "echo \"SETUP_FINISHED: $(date -u +'%Y-%m-%dT%H:%M:%SZ')\" | sudo tee -a /var/log/hextris_setup.log"
    ]
  }

  connection {
    type        = "ssh"
    host        = var.remote_host
    user        = var.ssh_user
    private_key = var.ssh_private_key
  }
}

# Fetch the remote setup log to local workspace
resource "null_resource" "fetch_log" {
  depends_on = [null_resource.remote_setup]

  provisioner "local-exec" {
    command = <<EOC
TMPKEY=$(mktemp)
echo "${var.ssh_private_key}" > $TMPKEY
chmod 600 $TMPKEY
ssh -o StrictHostKeyChecking=no -i $TMPKEY ${var.ssh_user}@${var.remote_host} 'sudo cat /var/log/hextris_setup.log' > ${path.module}/setup_log.txt || true
rm -f $TMPKEY
EOC
  }
}

