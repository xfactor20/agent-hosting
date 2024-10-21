# Terraform GCP GKE Infrastructure Provisioning for NFA Operations

This Terraform configuration (`agent_hosting_gcp_main.tf`) automates the provisioning of a Google Kubernetes Engine (GKE) cluster on Google Cloud Platform (GCP) for hosting and operating AI and other agent services (Non-fungible agents). It sets up a GKE cluster with customized node pools, firewall settings, and deploys a Kubernetes manifest to run your applications seamlessly.  It sets up an initial agent service "mor-chat-dply.yaml" to validate environment.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Configuration Details](#configuration-details)
  - [Providers](#providers)
  - [GKE Cluster](#gke-cluster)
  - [Node Pool](#node-pool)
  - [Firewall Rules](#firewall-rules)
  - [Applying Kubernetes Manifest](#applying-kubernetes-manifest)
  - [Generating Kubeconfig](#generating-kubeconfig)
- [Usage Instructions](#usage-instructions)
- [Notes](#notes)
- [Clean Up](#clean-up)
- [Troubleshooting](#troubleshooting)

## Overview

The Terraform script performs the following actions:

- **Configures Providers**: Sets up Google Cloud and Kubernetes providers with specified project and region.
- **Creates a GKE Cluster**: Provisions a GKE cluster in the specified region.
- **Configures a Node Pool**: Adds a node pool with custom machine types and GPU accelerators.
- **Sets up Firewall Rules**: Creates firewall rules to allow inbound traffic on specified ports.
- **Deploys Kubernetes Manifests**: Applies a Kubernetes deployment manifest to the cluster.
- **Generates Kubeconfig**: Creates a kubeconfig file for accessing the cluster.

## Prerequisites

- **Terraform**: Install [Terraform](https://www.terraform.io/downloads.html).
- **Google Cloud SDK**: Install and configure the [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) OR Log on to your Google Cloud Platform console and open an Cloudshell shell to execute generation of the NFA GKE environment 
- **GCP Project**: Have a GCP project with necessary permissions.
- **Kubernetes Manifest**: Ensure `mor-chat-dply.yaml` is available in the working directory.
- **Variables**: Define `var.gcp_project_id` and `var.gcp_region`.

## Configuration Details

### Providers

- **Google Provider**: Configures GCP project and region.
  ```hcl
  provider "google" {
    project = var.gcp_project_id
    region  = var.gcp_region
  }
  ```
- **Kubernetes Provider**: Connects to the GKE cluster using credentials and certificates.
  ```hcl
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
  ```

### GKE Cluster

- **Resource**: `google_container_cluster.gke_cluster`
- **Configuration**:
  - Name: Based on `var.gcp_project_id`
  - Location: `us-west1-a`
  - Initial Node Count: 1
  - Deletion Protection: Disabled
  ```hcl
  resource "google_container_cluster" "gke_cluster" {
    name                = "${var.gcp_project_id}-cluster"
    location            = "us-west1-a"
    initial_node_count  = 1
    deletion_protection = false
    remove_default_node_pool = true
  }
  ```

### Node Pool

- **Resource**: `google_container_node_pool.gke_node_pool`
- **Configuration**:
  - Machine Type: `n1-highmem-8`
  - Disk Size: 100 GB
  - GPU Accelerator: NVIDIA Tesla P100
  - OAuth Scopes: Full access
  - Autoscaling: Min 1, Max 3 nodes
  - Management: Auto-upgrade and auto-repair enabled
  ```hcl
  resource "google_container_node_pool" "gke_node_pool" {
    name              = "${var.gcp_project_id}-node-pool"
    cluster           = google_container_cluster.gke_cluster.name
    location          = google_container_cluster.gke_cluster.location
    initial_node_count = 1
    node_config {
      machine_type   = "n1-highmem-8"
      disk_size_gb   = 100
      guest_accelerator {
        type  = "nvidia-tesla-p100"
        count = 1
      }
      oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
      metadata = {
        "disable-legacy-endpoint" = "true"
      }
      workload_metadata_config {
        mode = "GCE_METADATA"
      }
    }
    autoscaling {
      min_node_count = 1
      max_node_count = 3
    }
    management {
      auto_upgrade = true
      auto_repair  = true
    }
  }
  ```

### Firewall Rules

- **Resource**: `google_compute_firewall.allow_http`
- **Configuration**:
  - Name: `allow-http`
  - Network: Default network
  - Allowed Ports: 80, 443, 22, 8000, 11434
  - Source Ranges: `0.0.0.0/0` (public access)
  ```hcl
  resource "google_compute_firewall" "allow_http" {
    name    = "allow-http"
    network = data.google_compute_network.default.self_link
    allow {
      protocol = "tcp"
      ports    = ["80", "443", "22", "8000", "11434"]
    }
    source_ranges = ["0.0.0.0/0"]
  }
  ```

### Applying Kubernetes Manifest

IMPORTANT: Copy the `mor-chat-dply.yaml` in the location where location of the terraform scripts PRIOR to runtime operations.  It has customizations for this development operations environment.

Refernce the flock.io team and this file for updated customizations
https://github.com/FLock-io/ragchat-morpheus/blob/main/k8s/deployment.yaml

```hcl
https://github.com/xfactor20/compute-services/master/gcp/agent-gke-gcp-1/reference/mor-chat-dply.yaml
```

- **Resource**: `null_resource.apply_kubernetes_manifest`
- **Action**: Applies `mor-chat-dply.yaml` using `kubectl`
- **Dependencies**: Depends on GKE cluster and node pool
  ```hcl
  resource "null_resource" "apply_kubernetes_manifest" {
    depends_on = [
      google_container_cluster.gke_cluster,
      google_container_node_pool.gke_node_pool,
    ]
    provisioner "local-exec" {
      command     = "kubectl apply -f mor-chat-dply.yaml"
      environment = {
        KUBECONFIG = "${path.module}/kubeconfig"
      }
    }
  }
  ```

### Generating Kubeconfig

- **Resource**: `local_file.kubeconfig`
- **Action**: Generates kubeconfig using a template file
  ```hcl
  resource "local_file" "kubeconfig" {
    content  = templatefile("${path.module}/kubeconfig.tmpl", {
      cluster_ca_certificate = google_container_cluster.gke_cluster.master_auth[0].cluster_ca_certificate
      endpoint               = google_container_cluster.gke_cluster.endpoint
      cluster_name           = google_container_cluster.gke_cluster.name
      cluster_zone           = google_container_cluster.gke_cluster.location
      project_id             = var.gcp_project_id
      token                  = data.google_client_config.default.access_token
    })
    filename = "${path.module}/kubeconfig"
  }
  ```

## Usage Instructions

1.  **Clone Repository**: Clone this repository to your local workspace, GCP Cloud Shell or command line path:
    ```hcl
    git clone https://github.com/morpheus-software/agent-hosting.git  
    ```
    
2.  **Set Variables**: Create a `terraform.tfvars` file or set environment variables with your GCP project ID and region and Vault server (access keys storage). At the root of the cloned repository noted in step #1. Open a command line (GCP Cloud Shell or similar) and run the `scripts` directory: 
   ```bash
   <path-to-cloned-reposiory>/./scripts/setup_tfvars_vault.sh
   ```
   
   Conversely, make certain these environment variables are set prior to proceeding
   ```hcl
   gcp_project_id = "your-project-id"
   gcp_region     = "your-region"
   gcp_zone       = "your-zone"
   ```
   
  NOTE: The default region and zone are set to "us-west1" and "us-west1-a", respectively.  Change these to your region of choice prior to runtime operations.
   
3. **Initialize Terraform**:
   ```bash
   terraform init
   ```
4. **Plan the Deployment**:
   ```bash
   terraform plan
   ```
5. **Apply the Configuration**:
   ```bash
   terraform apply
   ```
6. **Access the Cluster**:
   - The kubeconfig file is located at `${path.module}/kubeconfig`.
   - Use `kubectl` with the generated kubeconfig:
     ```bash
     KUBECONFIG=${path.module}/kubeconfig kubectl get nodes
     ```
7. **Deploy Kubernetes Manifests**:
   - Ensure `mor-chat-dply.yaml` is in the working directory.
   - The manifest is applied automatically during `terraform apply`.
   - To reapply manually:
     ```bash
     KUBECONFIG=${path.module}/kubeconfig kubectl apply -f mor-chat-dply.yaml
     ```

## Notes

- **GPU Support**: The node pool is configured with NVIDIA Tesla P100 GPUs for workloads requiring GPU acceleration.
- **Firewall Configuration**: The firewall rule is open to all IPs on specified ports. For production, modify `source_ranges` to restrict access.
- **Kubeconfig Template**: Ensure `kubeconfig.tmpl` exists in the module path for kubeconfig generation.
- **Dependencies Management**: The `null_resource` ensures Kubernetes manifests are applied after the cluster and node pool are ready.

## Clean Up

To destroy all resources created by this Terraform configuration:

```bash
terraform destroy
```

## Troubleshooting

- **Authentication Issues**: Run `gcloud auth login` and ensure you have the necessary permissions.
- **Resource Quotas**: Check GCP quotas for CPUs, GPUs, and other resources.
- **Firewall Access**: If you cannot access services, verify firewall rules and `source_ranges`.
- **Manifest Errors**: Ensure `mor-chat-dply.yaml` is correctly formatted and references valid images and configurations.

---

By following this guide, you can set up a GKE cluster with customized configurations to run your applications efficiently on Google Cloud Platform.
