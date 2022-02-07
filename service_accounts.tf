resource "google_service_account" "vault_server" {
  account_id = "vault-server"
  project    = google_project.vault_tenant.id
}

resource "google_service_account" "vault_ops" {
    account_id = "vault-ops"
    project = google_project.vault_tenant.id
}