resource "google_bigquery_table" "unmanaged_resources" {
  dataset_id = "managed_governance"

  labels = {
    managed-by-cnrm = "true"
  }

  project  = var.project_id
  schema   = "[{\"name\":\"resource_name\",\"type\":\"STRING\"},{\"name\":\"asset_type\",\"type\":\"STRING\"},{\"name\":\"discovery_time\",\"type\":\"TIMESTAMP\"}]"
  table_id = "unmanaged_resources"
}

resource "google_bigquery_dataset" "managed_governance" {
  access {
    role          = "OWNER"
    special_group = "projectOwners"
  }

  access {
    role          = "READER"
    special_group = "projectReaders"
  }

  access {
    role          = "WRITER"
    special_group = "projectWriters"
  }

  dataset_id                 = "managed_governance"
  delete_contents_on_destroy = false

  labels = {
    managed-by-cnrm = "true"
  }

  location              = var.region
  max_time_travel_hours = "168"
  project               = var.project_id
}