locals {
  enabled_apis = [
    "artifactregistry.googleapis.com",
    "bigquery.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "config.googleapis.com",
    "container.googleapis.com",
    "eventarc.googleapis.com",
    "gkeconnect.googleapis.com",
    "gkehub.googleapis.com",
    "iamcredentials.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "multiclustermetering.googleapis.com",
    "pubsub.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "source.googleapis.com",
  ]
}

resource "google_project_service" "gcp_services" {
  for_each = toset(local.enabled_apis)
  project  = var.project_id
  service  = each.key
  disable_on_destroy = false
}