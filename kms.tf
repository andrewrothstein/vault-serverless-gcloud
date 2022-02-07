resource "google_kms_key_ring" "vault_unseal_keyring" {
  name     = "vault-server"
  project = google_project.vault_tenant.id
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

resource "google_kms_crypto_key_iam_member" "vault_unseal_key" {
    crypto_key_id = google_kms_crypto_key.vault_unseal_key.id
    member = "serviceAccount:${google_service_account.vault_server.email}"
    role = "roles/cloudkms.cryptoKeyEncrypter"
}

