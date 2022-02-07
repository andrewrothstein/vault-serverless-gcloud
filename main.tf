resource "google_cloud_run_service" "vault_server" {
  name = "vault-server"
  location = var.location
  template {
    metadata {
      labels = var.resource_labels
      annotations = {
        "autoscaling.knative.dev/minScale" = 1
        "autoscaling.knative.dev/maxScale" = 1
      }
    }
    spec {
      service_account_name = google_service_account.vault_server.email
      containers {
        image = "gcr.io/hightowerlabs/vault:1.7.1"
        env {
          name = "GOOGLE_PROJECT"
          value = google_project.vault_tenant.id 
        }
        env {
          name = "GOOGLE_STORAGE_BUCKET"
          value = google_storage_bucket.vault_storage.name
        }
        volume_mounts {
          name = "vault-server-config"
          mount_path = "/etc/vault"
        }
        ports {
          container_port = 8200
        }
        resources {
          limits = {
            cpu = "2"
            memory = "2G"          
          }
        }
      }
      volumes {
        name = "vault-server-config"
        secret {
          secret_name = google_secret_manager_secret.vault_server_config.secret_id
          items {
            key = "latest"
            path = "config.hcl"
          }
        }
      }
    }
  }
  depends_on = [google_secret_manager_secret_version.vault_secret_v1]
}

resource "google_cloud_run_service_iam_member" "vault-server" {
  location = google_cloud_run_service.vault_server.location
  project = google_cloud_run_service.vault_server.project
  service = google_cloud_run_service.vault_server.name
  role = "roles/run.invoker"
  member = "user:${var.admin_email}"
}

locals {
  vault_addr = google_cloud_run_service.vault_server.status[0].url
}

output "VAULT_ADDR" {
  value = local.vault_addr
}
/*
data "google_service_account_id_token" "oidc" {
  target_audience = local.vault_addr
}

data "http" "seal_status" {
  url = "${local.vault_addr}/v1/sys/seal-status"
  request_headers  = {
    Authorization = "Bearer ${data.google_service_account_id_token.oidc.id_token}"
  }
}

output "seal_status_response" {
  value = data.http.seal_status.body
}
*/