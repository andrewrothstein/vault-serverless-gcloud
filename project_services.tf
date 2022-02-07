resource "google_folder" "vault_tenants" {
  display_name = "vault-tentants"
  parent       = "organizations/${var.organization_id}"
}

resource "google_project" "vault_tenant" {
  folder_id = google_folder.vault_tenants.name
  name = var.tenant_project_name
  project_id = var.tenant_project_id
}

resource "google_project_service" "enable_project_services" {
  project  = google_project.vault_tenant.id
  for_each = toset([
    "cloudkms.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "storage.googleapis.com"
  ])
  service  = each.key

  timeouts {
    create = "30m"
    update = "40m"
  }

  disable_dependent_services = true
}

