# Infrastructure Manager Automation & Governance

This Terraform module bootstraps a complete GitOps workflow for **Google Cloud Infrastructure Manager** and includes a custom **Governance Auditor** to detect and track unmanaged resources.

It automates the deployment of infrastructure via Cloud Build triggers, manages IAM securely with custom Service Accounts, and provides visibility into "ClickOps" (manual) changes versus managed state.

## 🚀 Features

* **Automated GitOps Pipelines**:
    * **Preview**: Automatically runs `gcloud infra-manager previews create` on Pull Requests to valid configuration.
    * **Apply**: Automatically runs `gcloud infra-manager deployments apply` on pushes to the `main` branch.
* **Drift & Audit Detection**:
    * Includes a Go-based Cloud Function (`im-global-auditor-go`) that compares actual GCP resources (via Asset Inventory) against Infrastructure Manager deployments.
    * Unmanaged resources are logged to **BigQuery** and alerted via **Pub/Sub**.
* **Secure IAM Architecture**:
    * Creates dedicated Service Accounts for Deployments (`im-sa`), Cloud Build (`cb-sa`), and Auditing (`im-auditor-sa`) with least-privilege roles.
    * Utilizes **Cloud Build v2** (Repository) connections for secure GitHub integration.

## 🛠 Architecture

### 1. Automation Pipelines (Cloud Build)
Two primary triggers are created to handle infrastructure changes:
* `im-preview-manual`: Triggers on PRs to `main`.
* `im-apply-manual`: Triggers on pushes to `main`.

### 2. Governance Auditor
A Gen2 Cloud Function runs periodically (triggered via Pub/Sub) to perform the following logic:
1.  **Fetch Reality**: Queries Cloud Asset Inventory for all active resources in the project.
2.  **Fetch State**: Queries Infrastructure Manager for all resources currently managed by deployments.
3.  **Compare**: Identifies resources that exist in reality but are **not** managed by Infrastructure Manager.
4.  **Report**:
    * Writes unmanaged resource details to BigQuery table `managed_governance.unmanaged_resources`.
    * Publishes a summary of flagged resources to the `resource-audit-topic` Pub/Sub topic.

## 📋 Prerequisites

Before using this module, ensure you have:
1.  A **Google Cloud Project**.
2.  A **GitHub App Installation** connected to your Google Cloud project (for Cloud Build v2).
3.  A **GitHub Personal Access Token (PAT)** stored in **Secret Manager**.

## 💻 Usage

```hcl
module "infra_manager_automation" {
  source = "./infrastructure_manager_automation"

  project_id                 = "your-gcp-project-id"
  region                     = "us-central1"
  deployment_id              = "prod-deployment"
  
  # GitHub Configuration
  repo_url                   = "[https://github.com/your-org/your-infra-repo.git](https://github.com/your-org/your-infra-repo.git)"
  github_app_installation_id = 12345678
  github_pat_secret_name     = "github-pat-secret" # Name of secret in Secret Manager
  
  # Path to Terraform config within the repo
  config_path                = "./envs/prod"
}
```

## ⚙️ Inputs

| Name | Type | Description | Default |
|------|------|-------------|---------|
| `project_id` | `string` | The GCP project ID. | **Required** |
| `region` | `string` | The GCP region for resources. | `"us-central1"` |
| `deployment_id` | `string` | A unique identifier used for naming resources. | **Required** |
| `github_pat_secret_name` | `string` | Secret Manager secret name for GitHub PAT. | **Required** |
| `github_app_installation_id` | `number` | The GitHub App installation ID. | **Required** |
| `repo_url` | `string` | The URL of the GitHub repository. | **Required** |
| `config_path` | `string` | Path to the Terraform configuration within the repo. | `.` |

## 📤 Outputs

| Name | Description |
|------|-------------|
| `infrastructure_manager_service_account_email` | The email of the service account for Infrastructure Manager deployments. |
| `cloud_build_service_account_email` | The email of the service account for Cloud Build triggers. |
| `github_connection_name` | The name of the Cloud Build v2 GitHub connection. |

## 📊 BigQuery Schema

The module creates a table named `unmanaged_resources` within the `managed_governance` dataset to track drift.

**Table Schema:**
* **`resource_name`** (`STRING`): The full Google Cloud resource name.
* **`asset_type`** (`STRING`): The specific asset type (e.g., `compute.googleapis.com/Instance`).
* **`discovery_time`** (`TIMESTAMP`): The timestamp when the unmanaged resource was detected.

## 🕵️‍♂️ Auditor Development

The auditor is a custom Go application located in the `infrastructure_manager_automation/im-audit/` directory.

* **Language Runtime:** Go 1.25.
* **Automatic Redeployment:** A specific Cloud Build trigger (`redeploy-auditor-on-push`) watches for changes in the `im-audit/` directory and automatically redeploys the Cloud Function when code is pushed to the `main` branch.
* **Entry Point:** The function entry point is `AuditResources`.

## 📄 License & Disclaimer

This project is open source and available under the [MIT License](LICENSE).

**DISCLAIMER**: This code is provided "as is" without warranty of any kind, either express or implied. It is intended for educational and experimental purposes. Users are responsible for reviewing and testing all infrastructure code before deploying to production environments. The authors assume no liability for any costs or damages associated with the use of this module.