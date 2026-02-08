output "infrastructure_manager_service_account_email" {
  description = "The email of the service account for Infrastructure Manager deployments."
  value       = google_service_account.custom_sas["im-sa"].email
}

output "cloud_build_service_account_email" {
  description = "The email of the service account for Cloud Build triggers."
  value       = google_service_account.custom_sas["cb-sa"].email
}

output "github_connection_name" {
  description = "The name of the Cloud Build v2 GitHub connection."
  value       = google_cloudbuildv2_connection.github_connection.name
}