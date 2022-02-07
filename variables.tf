variable organization_id {
  type = number
}

variable tenant_project_name { 
  type = string
}

variable tenant_project_id {
  type = string
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