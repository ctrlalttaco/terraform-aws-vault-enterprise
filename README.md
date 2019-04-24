# terraform-aws-vault-enterprise

A terraform module for deploying a Vault Enterprise HA cluster on AWS

## Requirements

* Consul ~> 1.4
* Vault ~> 1.0

## Tested Operating Systems

Amazon Linux 2 AMI

## Pre-requisites

KMS Key ARN for SSM parameters

IAM Certificate ARN for Vault Application Load Balancer

### SSM parameters

The following SSM parameter of type `SecureString` must be created:

* Consul gossip encryption key (16-byte random string, base64 encoded)
* Consul server TLS CA chain (base64 encoded)
* Consul server TLS certificate (base64 encoded)
* Consul server TLS key (base64 encoded)
* Consul client TLS CA chain (base64 encoded)
* Consul client TLS certificate (base64 encoded)
* Consul client TLS key (base64 encoded)
* Vault server TLS certificate chain (base64 encoded)
* Vault server TLS key (base64 encoded)

Creating a Consul gossip encryption key

CLI Example 1:
```
$ consul keygen

2DY+rtvNmltTLhdTTSmwkQ==
```

CLI Example 2:
```
$ openssl rand -base64 16

rD+h/UjWRCBQCnuYz3mxJQ==
```

Terraform Example:
```
# main.tf
resource "random_id" "consul_gossip_encryption_key" {
  byte_length = 16
}

output "consul_gossip_encryption_key" {
  value = "${random_id.consul_gossip_encryption_key.b64_std}"
}
```

```
$ terraform init
$ terraform apply -auto-approve

Outputs:

consul_gossip_encryption_key = ZsS+QLpWT6xbz3Ytv/zGrQ==
```

Base64 Encoding a TLS certificate or key

CLI Example 1:
```
$ openssl enc -base64 -A -in ca.pem

```

CLI Example 2:
```
$ base64 ca.pem
```

Terraform Example:
```
# main.tf
output "consul_server_tls_ca_base64" {
  value = "${base64encode(file("${path.module}/ca.pem"))}"
}

$ terraform init
$ terraform apply -auto-approve

Outputs:

consul_server_tls_ca_base64 = LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t....
```

Creating an SSM parameter

CLI Example:
```
$ aws ssm put-parameter \
  --region "us-west-2" \
  --name "/vault-demo/consul/gossip_encryption_key" \
  --value "2DY+rtvNmltTLhdTTSmwkQ==" \
  --type "SecureString"
```

Terraform Example:
```
resource "aws_ssm_parameter" "consul_gossip_encryption_key" {
  name   = "/vault-demo/consul/gossip_encryption_key"
  type   = "SecureString"
  value  = "${random_id.consul_gossip_encryption_key.b64_std}"
  key_id = "${aws_kms_key.ssm.arn}"
}
```

## Inputs

### Common

| Variable | Type | Description | Default Value |
| -------- | ---- | ----------- | ------------- |
| namespace | string | Resource name descriptor | team-demo |
| environment | string | Resource environment tag | demo |
| region | string | AWS Region | us-west-2 |
| vpc_id | string | AWS VPC ID | |
| ssm_kms_key_arn | string | AWS KMS key for SSM parameters | |

### SSM parameters

| Variable | Type | Description | Default Value |
| -------- | ---- | ----------- | ------------- |
| ssm_parameter_path | string | Base path for SSM parameters | /vault-demo |
| ssm_parameter_consul_acl_master_token | string | Consul ACL token used for creating ACL policies and tokens | /vault-demo/consul/acl_master_token |
| ssm_parameter_consul_acl_agent_token | string | Consul ACL token used for Consul agents | /vault-demo/consul/acl_agent_token |
| ssm_parameter_consul_acl_app_token | string | Consul ACL token used for Vault | /vault-demo/consul/acl_app_token |
| ssm_parameter_consul_gossip_encryption_key | string | 16-byte base64 string used for Consul gossip encryption | /vault-demo/consul/gossip_encryption_key |
| ssm_parameter_consul_server_tls_ca | string | base64 encoded string, Consul server TLS CA chain | /vault-demo/consul/server_tls_ca |
| ssm_parameter_consul_server_tls_cert | string | base64 encoded string, Consul server TLS certificate | /vault-demo/consul/server_tls_cert |
| ssm_parameter_consul_server_tls_key | string | base64 encoded string, Consul server TLS key | /vault-demo/consul/server_tls_key |
| ssm_parameter_consul_client_tls_ca | string | base64 encoded string, Consul client TLS CA chain | /vault-demo/consul/client_tls_ca |
| ssm_parameter_consul_client_tls_cert | string | base64 encoded string, Consul client TLS certificate | /vault-demo/consul/client_tls_cert |
| ssm_parameter_consul_client_tls_key | string | base64 encoded string, Consul client TLS key | /vault-demo/consul/client_tls_key |
| ssm_parameter_vault_tls_cert_chain | string | base64 encoded string, Vault server TLS certificate chain | /vault-demo/vault/tls_cert_chain |
| ssm_parameter_vault_tls_key | string | base64 encoded string, Vault server TLS key | /vault-demo/vault/tls_key |

### Consul

| Variable | Type | Description | Default Value |
| -------- | ---- | ----------- | ------------- |
| enable_consul_acl | string | True/False, Enable Consul ACLs | true |
| consul_packerized | string | True/False, Enable if using a pre-built AMI with Consul installed | false |
| consul_ami_id | string | EC2 AMI ID for Consul instances | |
| consul_instance_type | string | EC2 instance type for Consul | m5.large |
| consul_ssh_public_key | string | SSH public key for Consul instances | |
| consul_additional_security_groups | list | Additional security groups to attach to Consul instances | |
| consul_zip_path | string | Path to Consul binary zip file | |
| consul_private_subnets | map | Subnet IDs and associated Availability Zones | |
| consul_cluster_tag_key | string | Tag key to use for Consul auto-join | consul_cluster_name |
| consul_cluster_tag_value | string | Tag value to use for Consul auto-join | vault_ent_demo |
| consul_asg_enabled_metrics | string | True/Flase, Enable metrics for Consul auto-scaling group | true |
| consul_cluster_size_min | string | Integer, Consul cluster minimum size | 5 |
| consul_cluster_size_max | string | Integer, Consul cluster maximum size | 7 |
| consul_health_check_grace_period | string | Integer, Time in seconds, after instance comes into service before checking health | 300 |
| consul_termination_policies | string | Termination policy for determining which instance to terminate during scale-down | OldestInstance |
| consul_wait_for_capacity_timeout | string | Time in minutes to wait for changes in auto-scaling group capacity | 10m |
| consul_api_ingress_cidr_blocks | list | List of CIDR blocks to permit ingress access to the Consul API | ["0.0.0.0/0"] |
| consul_rpc_ingress_cidr_blocks | list | List of CIDR blocks to permit ingress access to the Consul RPC protocol | ["0.0.0.0/0"] |
| consul_serf_ingress_cidr_blocks | list | List of CIDR blocks to permit ingress access to the Consul Serf protocol | ["0.0.0.0/0"] |
| consul_egress_cidr_blocks | list | List of CIDR blocks to permit all egress traffic | ["0.0.0.0/0"] |


### Vault

| Variable | Type | Description | Default Value |
| -------- | ---- | ----------- | ------------- |
| vault_packerized | string | True/False, Enable if using a pre-built AMI with Consul installed | false |
| vault_ami_id | string | EC2 AMI ID for Vault instances | |
| vault_instance_type | string | EC2 instance type for Consul | m5.large |
| vault_cluster_size_min | string | Integer, Minimum cluster size for Vault instances | 3 |
| vault_cluster_size_max | string | Integer, Maximum cluster size for Vault instances | 5 |
| vault_ssh_public_key | string | SSH public key for Vault instances | |
| vault_private_subnets | map | Subnet IDs and associated Availability Zones | |
| vault_additional_security_groups | list | Additional security groups to attach to Vault instances | |
| vault_lb_cert_arn | string | IAM certificate manager ARN for Application Load Balancer | |
| vault_kms_key_rotate | string | Integer, Number of days before rotating KMS key | 7 |
| vault_kms_deletion_days | string | Integer, Number of days to wait before deleting previous KMS key | 10 |
| vault_health_check_timeout | string | Timeout in seconds to wait for health check response | 5 |
| vault_health_check_protocol | string | Protocol to use for health check | HTTPS |
| vault_health_check_path | string | API endpoint path to use for health check | /v1/sys/health |
| vault_health_check_success_codes | string | HTTP response codes to consider for health check | 200,473 |
| vault_health_check_interval | string | Time in seconds to run health check | 10 |
| vault_health_check_healthy_threshold | string | Number of successful health checks to consider instance healthy | 2 |
| vault_health_check_unhealthy_threshold | string | Number of unsuccessful health checks to consider instance unhealthy | 2 |
| vault_health_check_grace_period | string | Time in seconds before starting health checks on new instances | 300 |
| vault_api_port | string | Integer, port number for Vault API | 8200 |
| vault_egress_cidr_blocks | list | List of CIDR blocks to permit all egress traffic | ["0.0.0.0/0"] |
| vault_idle_timeout | string | Time in seconds before an idle connection times out | 60 |
| vault_connection_draining | string | True/False, enable connection draining | true |
| vault_api_ingress_cidr_blocks | list | List of CIDR blocks to permit Vault API access | ["0.0.0.0/0"] |
| vault_zip_path | string | Path to Vault binary zip file | |
| vault_wait_for_capacity_timeout | string | Time in minutes to wait for changes in auto-scaling group capacity | 10m |
| vault_enabled_metrics | string | True/Flase, Enable metrics for Vault auto-scaling group | true |
| vault_termination_policies | string | Termination policy for determining which instance to terminate during scale-down | OldestInstance |

Example subnet map variable definition:
```
consul_private_subnets = {
  "subnet-09f9fa49b56fe8e39" = "us-west-2a"
  "subnet-0c6830f9acf1cbac9" = "us-west-2b"
  "subnet-0e2025c6531edd88d" = "us-west-2c"
}
```

## Outputs
