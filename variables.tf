variable "project_id" {
  description = "The GCP project ID."
  type        = string
}

variable "region" {
  description = "The GCP region for resources."
  type        = string
  default     = "us-central1"
}

variable "deployment_id" {
  description = "A unique identifier used for naming resources."
  type        = string
}

variable "github_pat_secret_name" {
  description = "Secret Manager secret name for GitHub PAT."
  type        = string
}

variable "github_app_installation_id" {
  type        = number
}

variable "repo_url" {
  type        = string
}

variable "config_path" {
  type        = string
  default     = "."
}