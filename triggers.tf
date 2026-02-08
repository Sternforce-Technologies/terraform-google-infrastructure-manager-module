resource "google_cloudbuild_trigger" "im_apply" {
  name            = "im-apply-manual"
  location        = var.region
  project         = var.project_id
  service_account = google_service_account.custom_sas["cb-sa"].id

  repository_event_config {
    repository = google_cloudbuildv2_repository.github_repo.id
    push {
      branch = "^main$"
    }
  }

  build {
    step {
      name       = "gcr.io/google.com/cloudsdktool/cloud-sdk:slim"
      entrypoint = "gcloud"
      args = [
        "infra-manager",
        "deployments",
        "apply",
        "projects/$${PROJECT_ID}/locations/$${_REGION}/deployments/$${_DEPLOYMENT_ID}",
        "--service-account=projects/$${PROJECT_ID}/serviceAccounts/$${_SERVICE_ACCOUNT_EMAIL}",
        "--git-source-repo=$${_REPO_URL}",
        "--git-source-directory=$${_CONFIG_PATH}",
        "--git-source-ref=$${_BRANCH}",
        "--tf-version-constraint=$${_TF_VERSION}",
      ]
    }
    options {
      logging = "CLOUD_LOGGING_ONLY"
    }
  }

  substitutions = {
    _TF_VERSION            = "1.5.7"
    _REGION                = var.region
    _DEPLOYMENT_ID         = var.deployment_id
    _CONFIG_PATH           = var.config_path
    _REPO_URL              = var.repo_url
    _BRANCH                = "main"
    _SERVICE_ACCOUNT_EMAIL = google_service_account.custom_sas["im-sa"].email
  }

  approval_config {
     approval_required = false 
  }

  depends_on = [
    google_secret_manager_secret_iam_member.cb_secret_accessor,
    google_cloudbuildv2_repository.github_repo,
  ]
}

resource "google_cloudbuild_trigger" "im_preview" {
  name            = "im-preview-manual"
  location        = var.region
  project         = var.project_id
  service_account = google_service_account.custom_sas["cb-sa"].id

  repository_event_config {
    repository = google_cloudbuildv2_repository.github_repo.id
    pull_request {
      branch = "^main$"
    }
  }

  build {
    step {
      name       = "gcr.io/google.com/cloudsdktool/cloud-sdk:slim"
      entrypoint = "gcloud"
      args = [
        "infra-manager",
        "previews",
        "create",
        "projects/$${PROJECT_ID}/locations/$${_REGION}/previews/preview-$${_PR_NUMBER}",
        "--deployment=projects/$${PROJECT_ID}/locations/$${_REGION}/deployments/$${_DEPLOYMENT_ID}",
        "--service-account=projects/$${PROJECT_ID}/serviceAccounts/$${_SERVICE_ACCOUNT_EMAIL}",
        "--git-source-repo=$${_REPO_URL}",
        "--git-source-directory=$${_CONFIG_PATH}",
        "--git-source-ref=$${_BRANCH}",
        "--tf-version-constraint=$${_TF_VERSION}",
      ]
    }
    options {
      logging = "CLOUD_LOGGING_ONLY"
    }
  }

  substitutions = {
    _TF_VERSION            = "1.5.7"
    _REGION                = var.region
    _DEPLOYMENT_ID         = var.deployment_id
    _CONFIG_PATH           = var.config_path
    _REPO_URL              = var.repo_url
    _BRANCH                = "main"
    _SERVICE_ACCOUNT_EMAIL = google_service_account.custom_sas["im-sa"].email
  }

  approval_config {
     approval_required = false 
  }

  depends_on = [
    google_secret_manager_secret_iam_member.cb_secret_accessor,
    google_cloudbuildv2_repository.github_repo,
  ]
}

resource "google_cloudbuild_trigger" "redeploy_on_push" {
  name            = "redeploy-auditor-on-push"
  location        = var.region
  project         = var.project_id  
  service_account = google_service_account.custom_sas["cb-sa"].id

  repository_event_config {
    repository = google_cloudbuildv2_repository.github_module_repo.id
    push {
      branch = "^main$"
    }
  }

  # Deployment instructions path
  filename = "im-audit/files/cloudbuild.yaml"
  
  # Only trigger if the auditor code changes
  included_files = ["im-audit/**"]

  approval_config {
     approval_required = false 
  }

  depends_on = [
    google_secret_manager_secret_iam_member.cb_secret_accessor,
    google_cloudbuildv2_repository.github_module_repo,
  ]
}