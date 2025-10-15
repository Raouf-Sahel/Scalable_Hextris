output "app_url" {
  description = "URL to access the Hextris application"
  value       = "http://${var.remote_host}:8080"
}

output "setup_log_path" {
  description = "Path to the setup log fetched from the VM"
  value       = "${path.module}/setup_log.txt"
}

