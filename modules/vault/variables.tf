variable "vault_packerized" {
  type    = "string"
  default = false
}

variable "vault_kms_key_rotate" {
  type    = "string"
  default = true
}

variable "vault_kms_deletion_days" {
  type    = "string"
  default = 7
}

variable "vault_health_check_timeout" {
  description = "The amount of time, in seconds, before a health check times out."
  type        = "string"
  default     = 5
}

variable "vault_health_check_protocol" {
  description = "Protocol to use for Vault health check"
  type        = "string"
  default     = "HTTPS"
}

variable "vault_health_check_path" {
  description = "Vault health check API endpoint"
  type        = "string"
  default     = "/v1/sys/health"
}

variable "vault_health_check_success_codes" {
  description = "Vault health check API endpoint return codes"
  type        = "string"
  default     = "200,473"
}

variable "vault_health_check_interval" {
  description = "The interval between checks (seconds)."
  type        = "string"
  default     = 10
}

variable "vault_health_check_healthy_threshold" {
  description = "The number of health checks that must pass before the instance is declared healthy."
  type        = "string"
  default     = 2
}

variable "vault_health_check_grace_period" {
  description = "Time, in seconds, after instance comes into service before checking health."
  default     = 300
}

variable "vault_api_port" {
  type    = "string"
  default = 8200
}

variable "vault_health_check_unhealthy_threshold" {
  description = "The number of health checks that must fail before the instance is declared unhealthy."
  type        = "string"
  default     = 2
}

variable "vault_egress_cidr_blocks" {
  type    = "list"
  default = ["0.0.0.0/0"]
}

variable "vault_idle_timeout" {
  description = "The time, in seconds, that the connection is allowed to be idle."
  type        = "string"
  default     = 60
}

variable "vault_connection_draining" {
  description = "Set to true to enable connection draining."
  type        = "string"
  default     = true
}

variable "vault_api_ingress_cidr_blocks" {
  type    = "list"
  default = ["0.0.0.0/0"]
}

variable "vault_instance_type" {
  type    = "string"
  default = "m5.large"
}

variable "vault_wait_for_capacity_timeout" {
  type    = "string"
  default = "10m"
}

variable "vault_enabled_metrics" {
  type    = "list"
  default = []
}

variable "vault_termination_policies" {
  description = "A list of policies to decide how the instances in the auto scale group should be terminated. The allowed values are OldestInstance, NewestInstance, OldestLaunchConfiguration, ClosestToNextInstanceHour, Default."
  type        = "string"
  default     = "OldestInstance"
}

variable "vault_zip_name" {
  description = "The file name of the vault zip located in S3"
  type = "string"
  default = "vault-enterprise_1.1.2+prem_linux_amd64.zip"
}