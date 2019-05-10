### Common Variables
variable "namespace" {
  type        = "string"
  description = "Resource naming identifier"
  default     = "team-demo"
}

variable "environment" {
  type        = "string"
  description = "Environment identification for resource tagging"
  default     = "demo"
}

variable "region" {
  type        = "string"
  description = "AWS Region"
}

variable "vpc_id" {
  type        = "string"
  description = "VPC ID for Consul and Vault clusters"
}

variable "ssm_kms_key_arn" {
  type        = "string"
  description = "KMS Key ARN used to encrypt/decrypt SSM parameters"
}

variable "ssm_parameter_path" {
  type        = "string"
  description = "Base path for SSM parameters"
  default = "/vault-demo"
}

variable "ssm_parameter_consul_gossip_encryption_key" {
  description = "16-byte base64 string used for Consul gossip encryption"
  type = "string"
  default = "/vault-demo/consul/gossip_encryption_key"
}

variable "ssm_parameter_consul_acl_master_token" {
  type = "string"
  default = "/vault-demo/consul/acl_master_token"
}
variable "ssm_parameter_consul_acl_agent_token" {}
variable "ssm_parameter_consul_acl_app_token" {}

variable "s3_bucket" {
  description = "S3 bucket for installation artifacts"
}

variable "enable_consul_acl" {
  default = true
}

### Consul Instance

variable "consul_packerized" {
  type    = "string"
  default = false
}

variable "consul_ami_id" {
  type        = "string"
  description = "EC2 AMI ID for Consul"
}

variable "consul_instance_type" {
  type    = "string"
  default = "m5.large"
}

variable "consul_ssh_public_key" {
  type        = "string"
  description = "SSH public key for Consul instances"
}

variable "consul_additional_security_groups" {
  type        = "list"
  description = "List of additional security group IDs to attach to Consul cluster"
  default     = []
}

variable "consul_zip" {
  type    = "string"
  default = "consul-enterprise_1.5.0+prem_linux_amd64.zip"
}

variable "consul_private_subnets" {
  type        = "map"
  description = "Map of private subnet IDs and associated availability zones for Consul cluster"
}

variable "consul_cluster_tag_key" {
  type    = "string"
  default = "consul_cluster_name"
}

variable "consul_cluster_tag_value" {
  type    = "string"
  default = "vault_ent_demo"
}

variable "ssm_parameter_consul_server_tls_ca" {
  description = "base64 encoded string, Consul server TLS CA chain"
  type = "string"
  default = "/vault-demo/consul/server_tls_ca"
}

variable "ssm_parameter_consul_server_tls_cert" {
  description = "base64 encoded string, Consul server TLS certificate"
  type = "string"
  default = "/vault-demo/consul/server_tls_cert"
}

variable "ssm_parameter_consul_server_tls_key" {
  description = ""
  type = "string"
}

### Consul Auto-Scaling Group

variable "consul_asg_enabled_metrics" {
  type    = "list"
  default = []
}

variable "consul_cluster_size_min" {
  type        = "string"
  description = "Minimum cluster size for Consul ASG"
  default     = 5
}

variable "consul_cluster_size_max" {
  type        = "string"
  description = "Maximum cluster size for Consul ASG"
  default     = 7
}

variable "consul_health_check_grace_period" {
  description = "Time, in seconds, after instance comes into service before checking health."
  default     = 300
}

variable "consul_termination_policies" {
  description = "A list of policies to decide how the instances in the auto scale group should be terminated. The allowed values are OldestInstance, NewestInstance, OldestLaunchConfiguration, ClosestToNextInstanceHour, Default."
  type        = "string"
  default     = "OldestInstance"
}

variable "consul_wait_for_capacity_timeout" {
  type    = "string"
  default = "10m"
}

# Consul Security Groups

variable "consul_api_ingress_cidr_blocks" {
  type    = "list"
  default = ["0.0.0.0/0"]
}

variable "consul_rpc_ingress_cidr_blocks" {
  type    = "list"
  default = ["0.0.0.0/0"]
}

variable "consul_serf_ingress_cidr_blocks" {
  type    = "list"
  default = ["0.0.0.0/0"]
}

variable "consul_egress_cidr_blocks" {
  type    = "list"
  default = ["0.0.0.0/0"]
}

### Vault Server
variable "vault_ami_id" {
  type        = "string"
  description = "EC2 AMI ID for Vault"
}

variable "vault_cluster_size_min" {
  type        = "string"
  description = "Minimum cluster size for Vault ASG"
  default     = 3
}

variable "vault_cluster_size_max" {
  type    = "string"
  default = 5
}

variable "vault_ssh_public_key" {
  type        = "string"
  description = "SSH public key for Vault instances"
}

variable "vault_private_subnets" {
  type        = "map"
  description = "Map of private subnet IDs and associated availability zones for Vault cluster"
}

variable "vault_additional_security_groups" {
  type        = "list"
  description = "List of additional security group IDs to attach to Vault cluster"
  default     = []
}

variable "vault_lb_cert_arn" {
  type        = "string"
  description = "IAM certificate ARN to attach to Vault Application Load Balancer"
}

variable "ssm_parameter_consul_client_tls_ca" {
  type = "string"
}

variable "ssm_parameter_consul_client_tls_cert" {
  type = "string"
}

variable "ssm_parameter_consul_client_tls_key" {
  type = "string"
}

variable "ssm_parameter_vault_tls_cert_chain" {
  type = "string"
}

variable "ssm_parameter_vault_tls_key" {
  type = "string"
}

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

variable "vault_zip" {
  type    = "string"
  default = "vault-enterprise_1.1.2+prem_linux_amd64.zip"
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
