# outputs.tf


output "cluster_name" {
  description = "The name of the GKE cluster"    
  value = google_container_cluster.gke_cluster.name
}

output "cluster_endpoint" {
description = "The endpoint of the GKE cluster"
  value = google_container_cluster.gke_cluster.endpoint
}

#output "kubeconfig" {
#  description = "Kubeconfig for the GKE cluster"
#  value       = google_container_cluster.gke_cluster.kube_config_raw
#  sensitive   = true
#}
