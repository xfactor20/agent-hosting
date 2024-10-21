# Global variables

variable "gcp_project_id" {
  description = "The ID of the GCP project."
  type        = string
}

variable "gcp_region" {
  description = "The region in which to deploy resources."
  type        = string
}

variable "gcp_zone" {
  description = "The zone in which to deploy resources."
  type        = string
}

variable "vault_address" {
  description = "The address of the Vault server."
  type        = string
}

variable "vault_token" {
  description = "The token to authenticate with Vault."
  type        = string
}
