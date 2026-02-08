resource "google_cloudbuildv2_connection" "github_connection" {
  project         = var.project_id
  location        = var.region
  name            = "github-connection" 

  github_config {
    app_installation_id = var.github_app_installation_id 
    
    authorizer_credential {
      oauth_token_secret_version = "projects/${var.project_id}/secrets/${var.github_pat_secret_name}/versions/latest"
    }
  }
}

resource "google_cloudbuildv2_repository" "github_repo" {
  project           = var.project_id
  location          = var.region
  name              = var.deployment_id
  parent_connection = google_cloudbuildv2_connection.github_connection.name
  remote_uri        = var.repo_url

  depends_on = [
    google_cloudbuildv2_connection.github_connection,
  ]
}

resource "google_cloudbuildv2_repository" "github_module_repo" {
  project           = var.project_id
  location          = var.region
  name              = "sft-terraform-modules"
  parent_connection = google_cloudbuildv2_connection.github_connection.name
  remote_uri        = "https://github.com/Sternforce-Technologies/terraform-google-infrastructure-manager-module.git"

  depends_on = [
    google_cloudbuildv2_connection.github_connection,
  ]
}