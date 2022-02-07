resource "google_storage_bucket" "vault_storage" {
  location = var.location
  name     = "${google_project.vault_tenant.id}-data"
  labels   = var.resource_labels
  versioning {
    enabled = true
  }
}

resource "google_storage_bucket_iam_member" "vault_storage_member" {
    bucket = google_storage_bucket.vault_storage.name
    role = "roles/storage.objectAdmin"
    member = "serviceAccount:${google_service_account.vault_server.email}"
}
