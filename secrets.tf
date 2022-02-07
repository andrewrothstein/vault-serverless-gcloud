resource "google_secret_manager_secret" "vault_server_config" {
  project = google_project.vault_tenant.id
  secret_id = "vault-server-config"
  replication {
    automatic = true
  }
  labels = var.resource_labels
}

resource "google_secret_manager_secret_iam_member" "vault_server_secret_accessor" {
  project     = google_project.vault_tenant.id
  secret_id   = google_secret_manager_secret.vault_server_config.secret_id
  role = "roles/secretmanager.secretAccessor"
  member = "serviceAccount:${google_service_account.vault_server.email}"
}

resource "google_secret_manager_secret_version" "vault_secret_v1" {
  secret = google_secret_manager_secret.vault_server_config.id
  secret_data = file("vault-server.hcl")
}
