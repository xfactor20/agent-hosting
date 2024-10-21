provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

provider "kubernetes" {
  host                   = google_container_cluster.gke_cluster.endpoint
  cluster_ca_certificate = base64decode(google_container_cluster.gke_cluster.master_auth.0.cluster_ca_certificate)
  token                  = data.google_client_config.default.access_token

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "gcloud"
    args        = ["config", "config-helper", "--format=json"]
  }


}

data "google_client_config" "default" {}

resource "google_container_cluster" "gke_cluster" {
  name     = "${var.gcp_project_id}-cluster"
  location = "us-west1-a"
  initial_node_count = 1

  deletion_protection = false

  # Enable autoscaling
  remove_default_node_pool = true
}

resource "google_container_node_pool" "gke_node_pool" {
  name       = "${var.gcp_project_id}-node-pool"
  cluster    = google_container_cluster.gke_cluster.name
  location   = google_container_cluster.gke_cluster.location
  initial_node_count = 1

  node_config {
    machine_type = "n1-highmem-8"
    disk_size_gb = 100  # Adjust as needed

    guest_accelerator {
      type  = "nvidia-tesla-p100"
      count = 1
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    metadata = {
      "disable-legacy-endpoint" = "true"
    }

    # Enable GPU driver installation
    workload_metadata_config {
      mode = "GCE_METADATA"
    }
  }

  # Optional autoscaling configuration
  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }

  management {
    auto_upgrade = true
    auto_repair  = true
  }

}

data "google_compute_network" "default" {
  name = "default"
}

resource "google_compute_firewall" "allow_http" {
  name    = "allow-http"
  network = data.google_compute_network.default.self_link
  # network = google_container_cluster.gke_cluster.network

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "22", "8000", "11434"]
  }

  # For testing. Define access pool for production environments
  source_ranges = ["0.0.0.0/0"]  # Public access
}

# Apply the Kubernetes manifest using a null_resource
resource "null_resource" "apply_kubernetes_manifest" {
  depends_on = [
    google_container_cluster.gke_cluster,
    google_container_node_pool.gke_node_pool,
  ]

  # NOTE:
  # Get this file from the "dev" directory.  Copy the file link to this directory. Then rename it to "mor-chat-dply.yaml":
  #  https://github.com/FLock-io/ragchat-morpheus/blob/main/k8s/deployment.yaml
  # A test version may be found in the "reference" directory

  provisioner "local-exec" {
    command     = "kubectl apply -f mor-chat-dply.yaml"
    environment = {
      KUBECONFIG = "${path.module}/kubeconfig"
    }
  }

}

# Generate kubeconfig file
resource "local_file" "kubeconfig" {
  content  = templatefile("${path.module}/kubeconfig.tmpl", {
    cluster_ca_certificate = google_container_cluster.gke_cluster.master_auth[0].cluster_ca_certificate
    endpoint               = google_container_cluster.gke_cluster.endpoint

    cluster_name           = google_container_cluster.gke_cluster.name
    cluster_zone           = google_container_cluster.gke_cluster.location
    project_id             = var.gcp_project_id  # Ensure you have var.project_id defined
    token                  = data.google_client_config.default.access_token
  })
  filename = "${path.module}/kubeconfig"
}

