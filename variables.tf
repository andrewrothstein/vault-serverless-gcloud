variable project_id {
  type        = string
  description = "gcloud PROJECT_ID"
}

variable resource_labels {
  type = map
  description = "labels for the cloud resources"
}

variable location {
  type = string
  description = "gcloud location"
}

variable admin_email {
  type = string
  default = "andrew.rothstein@gmail.com"
}