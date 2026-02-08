resource "google_pubsub_topic" "resource_audit_topic" {
  labels = {
    managed-by-cnrm = "true"
  }

  name    = "resource-audit-topic"
  project = var.project_id
}

resource "google_pubsub_subscription" "im_global_auditor_subscription" {
  ack_deadline_seconds = 600
  message_retention_duration = "86400s"
  name                       = "im-global-auditor-subscription"
  project                    = var.project_id
  topic                      = google_pubsub_topic.resource_audit_topic.name

  push_config {
    oidc_token {
      audience              = google_cloudfunctions2_function.auditor_function.service_config[0].uri
      service_account_email = google_service_account.custom_sas["im-auditor-sa"].email
    }

    push_endpoint = "${google_cloudfunctions2_function.auditor_function.service_config[0].uri}?__GCP_CloudEventsMode=CUSTOM_PUBSUB_projects%2F${var.project_id}%2Ftopics%2F${google_pubsub_topic.resource_audit_topic.name}"
  }

  retry_policy {
    maximum_backoff = "600s"
    minimum_backoff = "10s"
  }

  depends_on = [ google_cloudfunctions2_function.auditor_function ]
}