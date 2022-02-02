provider "google" {
  project = var.project_id
  region  = var.location
}

locals {
  gcs_bucket_name = "${var.project_id}-data"
  sa_email        = "vault-server@${var.project_id}.iam.gserviceaccount.com"

  services = toset([
    "cloudkms.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "storage.googleapis.com"
  ])
}

resource "google_project_service" "enable_project_services" {
  project  = var.project_id
  for_each = local.services
  service  = each.key

  timeouts {
    create = "30m"
    update = "40m"
  }

  disable_dependent_services = true
}

resource "google_service_account" "vault_sa" {
  account_id = "vault-server"
  project    = var.project_id
}

resource "google_storage_bucket" "vault_storage" {
  location = var.location
  name     = local.gcs_bucket_name
  labels   = var.resource_labels
  versioning {
    enabled = true
  }
}

output "sa_email" {
  value = local.sa_email
}

output "gcs_bucket_name" {
  value = local.gcs_bucket_name
}

output "admin_email" {
  value = var.admin_email
}

data "google_iam_policy" "vault_storage_admin_policy" {
  binding {
    role = "roles/storage.admin"
    members = [
      "user:${var.admin_email}",
    ]
  }
  binding {
    role = "roles/storage.objectAdmin"
    members = [
      "serviceAccount:${local.sa_email}",
    ]
  }
}

resource "google_storage_bucket_iam_policy" "vault_storage_policy" {
  bucket      = google_storage_bucket.vault_storage.name
  policy_data = data.google_iam_policy.vault_storage_admin_policy.policy_data
}

resource "google_secret_manager_secret" "vault_server_config" {
  secret_id = "vault-server-config"
  replication {
    automatic = true
  }
  labels = var.resource_labels
}

data "google_iam_policy" "vault_secret_admin" {
  binding {
    role = "roles/secretmanager.admin"
    members = [
      "user:${var.admin_email}",
    ]
  }
  binding {
    role = "roles/secretmanager.secretAccessor"
    members = [
      "serviceAccount:${local.sa_email}",
    ]
  }
}

resource "google_secret_manager_secret_iam_policy" "vault_secret_admin" {
  project     = var.project_id
  secret_id   = google_secret_manager_secret.vault_server_config.secret_id
  policy_data = data.google_iam_policy.vault_secret_admin.policy_data
}

resource "google_secret_manager_secret_version" "vault_secret_v1" {
  secret = google_secret_manager_secret.vault_server_config.id
  secret_data = file("vault-server.hcl")
}

resource "google_kms_key_ring" "vault_unseal_keyring" {
  name     = "vault-server"
  location = "global"
}

resource "google_kms_crypto_key" "vault_unseal_key" {
  name     = "seal"
  key_ring = google_kms_key_ring.vault_unseal_keyring.id
  purpose  = "ENCRYPT_DECRYPT"

  lifecycle {
    prevent_destroy = true
  }
}

data "google_iam_policy" "vault_unseal_key" {
  binding {
    role = "roles/cloudkms.admin"
    members = [
      "user:${var.admin_email}",
    ]
  }
  binding {
    role = "roles/cloudkms.cryptoKeyEncrypter"

    members = [
      "serviceAccount:${local.sa_email}",
    ]
  }
}

resource "google_kms_crypto_key_iam_policy" "vault_unseal_key" {
  crypto_key_id = google_kms_crypto_key.vault_unseal_key.id
  policy_data = data.google_iam_policy.vault_unseal_key.policy_data
}

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
      service_account_name = local.sa_email
      containers {
        image = "gcr.io/hightowerlabs/vault:1.7.1"
        env {
          name = "GOOGLE_PROJECT"
          value = var.project_id 
        }
        env {
          name = "GOOGLE_STORAGE_BUCKET"
          value = local.gcs_bucket_name
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