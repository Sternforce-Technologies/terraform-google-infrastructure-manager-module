# IAM CONFIGURATION FOR INFRASTRUCTURE MANAGER AUTOMATION
data "google_project" "current" {
  project_id = var.project_id
}

locals {
  project_num = data.google_project.current.number

  service_accounts = {
    "im-sa" = {
      display_name = "Infrastructure Manager Service Account"
      description  = "Primary SA for Infrastructure Manager deployments"
    },
    "cb-sa" = {
      display_name = "Cloud Build Service Account"
      description  = "SA for running Cloud Build triggers"
    },
    "im-auditor-sa" = {
      display_name = "Infrastructure Manager Auditor Service Account"
      description  = "Read-only auditor account"
    }
  }
}

# SERVICE ACCOUNT CREATION 
resource "google_service_account" "custom_sas" {
  for_each = local.service_accounts

  account_id   = "${var.deployment_id}-${each.key}"
  display_name = each.value.display_name
  description  = each.value.description
  project      = var.project_id
}


# DEPLOYMENT SERVICE ACCOUNT PERMISSIONS (im-sa)
resource "google_project_iam_member" "im_sa_roles" {
  for_each = toset([
    "roles/editor",                        
    "roles/config.admin",                 
    "roles/iam.serviceAccountUser",         
    "roles/logging.logWriter",            
    "roles/eventarc.admin",                 
    "roles/cloudbuild.connectionAdmin",    
    "roles/cloudbuild.builds.editor",       
    "roles/cloudbuild.workerPoolUser",      
    "roles/iam.serviceAccountTokenCreator",
    "roles/secretmanager.admin",           
    "roles/storage.admin",                  
    "roles/serviceusage.serviceUsageConsumer", 
    "roles/serviceusage.serviceUsageAdmin",
    # --- IAM Management ---
    "roles/resourcemanager.projectIamAdmin",
    "roles/iam.serviceAccountAdmin"
  ])
  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.custom_sas["im-sa"].email}"
}

# CUSTOM CLOUD BUILD SERVICE ACCOUNT PERMISSIONS (cb-sa)
resource "google_project_iam_member" "cb_sa_roles" {
  for_each = toset([
    "roles/editor",
    "roles/cloudbuild.builds.builder",
    "roles/cloudbuild.connectionAdmin",
    "roles/cloudfunctions.developer",
    "roles/run.admin",
    "roles/eventarc.admin",
    "roles/logging.logWriter",
    "roles/serviceusage.serviceUsageConsumer"
  ])
  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.custom_sas["cb-sa"].email}"
}

# Specific Secret Access for GitHub PAT
resource "google_secret_manager_secret_iam_member" "cb_secret_accessor" {
  project   = var.project_id
  secret_id = var.github_pat_secret_name
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.custom_sas["cb-sa"].email}"
}

# AUDITOR SERVICE ACCOUNT PERMISSIONS (im-auditor-sa)
resource "google_project_iam_member" "auditor_sa_roles" {
  for_each = toset([
    "roles/config.viewer",
    "roles/cloudasset.viewer",
    "roles/cloudbuild.serviceAgent",
    "roles/pubsub.publisher",
    "roles/bigquery.dataEditor",
    "roles/logging.logWriter",
    "roles/secretmanager.secretAccessor"
  ])
  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.custom_sas["im-auditor-sa"].email}"
}

# DEFAULT COMPUTE SERVICE ACCOUNT (The Worker)
resource "google_project_iam_member" "default_compute_roles" {
  for_each = toset([
    "roles/editor",
    "roles/secretmanager.secretAccessor",
    "roles/serviceusage.serviceUsageConsumer",
    "roles/cloudbuild.workerPoolUser",       
    "roles/iam.serviceAccountTokenCreator",  
    "roles/storage.admin",                   
    "roles/logging.logWriter"
  ])
  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${local.project_num}-compute@developer.gserviceaccount.com"
}

# DEFAULT CLOUD BUILD SERVICE ACCOUNT (The Builder)
resource "google_project_iam_member" "default_cloudbuild_roles" {
  for_each = toset([
    "roles/cloudbuild.builds.builder",
    "roles/editor",
    "roles/secretmanager.secretAccessor",
    "roles/serviceusage.serviceUsageConsumer",
    "roles/iam.serviceAccountTokenCreator",
    "roles/storage.admin",
    "roles/logging.logWriter"
  ])
  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${local.project_num}@cloudbuild.gserviceaccount.com"
}

# ROBOTS (Service Agents)
resource "google_project_iam_member" "infra_manager_agent_secret" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:service-${local.project_num}@gcp-sa-config.iam.gserviceaccount.com"
}

# Project-Level Secret Access
resource "google_project_iam_member" "cloudbuild_agent_secret" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:service-${local.project_num}@gcp-sa-cloudbuild.iam.gserviceaccount.com"
}

# IMPERSONATION & BINDINGS
# Allow cb_sa to act as im_sa
resource "google_service_account_iam_member" "cb_impersonate_im_sa" {
  service_account_id = google_service_account.custom_sas["im-sa"].name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.custom_sas["cb-sa"].email}"
}

# Allow im_auditor_sa to act as im_sa
resource "google_service_account_iam_member" "im_sa_user" {
  service_account_id = google_service_account.custom_sas["im-auditor-sa"].name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.custom_sas["im-sa"].email}"
}

# Allow im_auditor_sa to act as cb_sa
resource "google_service_account_iam_member" "cloudbuild_sa_user" {
  service_account_id = google_service_account.custom_sas["im-auditor-sa"].name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.custom_sas["cb-sa"].email}"
}

# Allow Cloud Build Service Agent (Robot) to impersonate cb_sa
resource "google_service_account_iam_member" "cb_sa_impersonation" {
  service_account_id = google_service_account.custom_sas["cb-sa"].name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:service-${local.project_num}@gcp-sa-cloudbuild.iam.gserviceaccount.com"
}

# Allow Cloud Build Service Agent (Robot) to impersonate im_auditor_sa
resource "google_service_account_iam_member" "im_audit_sa_impersonation" {
  service_account_id = google_service_account.custom_sas["im-auditor-sa"].name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:service-${local.project_num}@gcp-sa-cloudbuild.iam.gserviceaccount.com"
}

# Allow Default Cloud Build SA to impersonate custom cb_sa
resource "google_service_account_iam_member" "cb_legacy_robot_impersonation" {
  service_account_id = google_service_account.custom_sas["cb-sa"].name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${local.project_num}@cloudbuild.gserviceaccount.com"
}