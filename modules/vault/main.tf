terraform {
  required_version = ">= 0.11.11"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

/*------------------------------------------------------------------------------
The Vault cluster is either built as var.vault_cluster_size instances or as a
var.vault_cluster_size[min|max|des] instance ASG depending on the use of the
var.use_asg boolean.
------------------------------------------------------------------------------
------------------------------------------------------------------------------
 This is the instance build for the Vault infra without an ASG. This is
defined only if the variable var.use_asg = false (default)
------------------------------------------------------------------------------*/

resource "aws_instance" "vault-instance" {
  ami                         = "${var.vault_ami_id}"
  count                       = "${(var.use_asg ? 0 : var.vault_cluster_size)}"
  instance_type               = "${var.instance_type}"
  iam_instance_profile        = "${aws_iam_instance_profile.cluster_server.id}"
  associate_public_ip_address = false
  key_name                    = "${var.ssh_key_name}"
  vpc_security_group_ids      = ["${concat(var.additional_sg_ids, list(aws_security_group.vault_cluster_int.id))}"]
  subnet_id                   = "${element(var.private_subnets, count.index)}"
  user_data                   = "${data.template_file.vault_user_data.rendered}"

  tags = {
    "Name" = "vault_server-${count.index}"
  }
}

/*------------------------------------------------------------------------------
 This is the instance build for the Consul infra. This is deliberately
not built inside an ASG (coz)
------------------------------------------------------------------------------*/

resource "aws_instance" "consul-instance" {
  ami                         = "${var.consul_ami_id}"
  count                       = "${var.consul_cluster_size}"
  instance_type               = "${var.instance_type}"
  iam_instance_profile        = "${aws_iam_instance_profile.cluster_server.id}"
  associate_public_ip_address = false
  key_name                    = "${var.ssh_key_name}"
  vpc_security_group_ids      = ["${concat(var.additional_sg_ids, list(aws_security_group.vault_cluster_int.id))}"]
  user_data                   = "${data.template_file.consul_user_data.rendered}"
  subnet_id                   = "${element(var.private_subnets, count.index)}"

  tags = "${merge(map("Name", "consul_server-${count.index}"), map("${var.cluster_tag_key}", "${var.cluster_tag_value}"))}"
}

/*------------------------------------------------------------------------------
This is the configuration for the Vault ASG. This is defined only if the
variable var.use_asg = true
------------------------------------------------------------------------------*/

resource "aws_launch_configuration" "vault_instance_asg" {
  count                = "${(var.use_asg ? 1 : 0)}"
  name_prefix          = "${var.cluster_name}-"
  image_id             = "${var.vault_ami_id}"
  instance_type        = "${var.instance_type}"
  iam_instance_profile = "${aws_iam_instance_profile.cluster_server.id}"
  security_groups      = ["${concat(var.additional_sg_ids, list(aws_security_group.vault_cluster_int.id))}"]
  key_name             = "${var.ssh_key_name}"
  user_data            = "${data.template_file.vault_user_data.rendered}"
}

resource "aws_autoscaling_group" "vault_asg" {
  count                = "${(var.use_asg ? 1 : 0)}"
  name_prefix          = "${var.cluster_name}"
  launch_configuration = "${aws_launch_configuration.vault_instance_asg.name}"
  availability_zones   = ["${var.availability_zones}"]
  vpc_zone_identifier  = ["${var.private_subnets}"]

  min_size             = "${var.vault_cluster_size}"
  max_size             = "${var.vault_cluster_size}"
  desired_capacity     = "${var.vault_cluster_size}"
  termination_policies = ["${var.termination_policies}"]

  health_check_type         = "EC2"
  health_check_grace_period = "${var.health_check_grace_period}"
  wait_for_capacity_timeout = "${var.wait_for_capacity_timeout}"

  enabled_metrics = ["${var.enabled_metrics}"]

  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = "vault_server"
    propagate_at_launch = true
  }
}

# Create a new load balancer attachment for ASG if ASG is used
resource "aws_autoscaling_attachment" "asg_attachment_vault" {
  count                  = "${(var.use_elb && var.use_asg ? 1 : 0)}"
  autoscaling_group_name = "${aws_autoscaling_group.vault_asg.id}"
  elb                    = "${aws_elb.vault_elb.id}"
}

# Alternatively attach the instances directly to the ELB
resource "aws_elb_attachment" "instance_attach_vault" {
  count    = "${(var.use_elb  && !var.use_asg ? var.vault_cluster_size : 0)}"
  elb      = "${aws_elb.vault_elb.id}"
  instance = "${element(aws_instance.vault-instance.*.id, count.index)}"
}

/*------------------------------------------------------------------------------
This is the configuration for the ELB. This is defined only if the variable
var.use_elb = true
------------------------------------------------------------------------------*/
resource "aws_elb" "vault_elb" {
  count                       = "${(var.use_elb ? 1 : 0)}"
  name_prefix                 = "elb-"
  internal                    = "${var.internal_elb}"
  cross_zone_load_balancing   = "${var.cross_zone_load_balancing}"
  idle_timeout                = "${var.idle_timeout}"
  connection_draining         = "${var.connection_draining}"
  connection_draining_timeout = "${var.connection_draining_timeout}"
  security_groups             = ["${aws_security_group.elb_sg.id}"]
  subnets                     = ["${split(",", var.internal_elb ? join(",", var.private_subnets) : join(",", var.public_subnets))}"]

  listener {
    lb_port           = "${var.lb_port}"
    lb_protocol       = "TCP"
    instance_port     = "${var.vault_api_port}"
    instance_protocol = "TCP"
  }

  listener {
    lb_port           = 8201
    lb_protocol       = "TCP"
    instance_port     = 8201
    instance_protocol = "TCP"
  }

  health_check {
    target              = "${var.health_check_protocol}:${var.vault_api_port}${var.health_check_path}"
    interval            = "${var.health_check_interval}"
    healthy_threshold   = "${var.health_check_healthy_threshold}"
    unhealthy_threshold = "${var.health_check_unhealthy_threshold}"
    timeout             = "${var.health_check_timeout}"
  }
}

resource "aws_security_group" "elb_sg" {
  count       = "${(var.use_elb || var.use_asg ? 1 : 0)}"
  description = "Enable vault UI and API access to the elb"
  name        = "elb-security-group"
  vpc_id      = "${var.vpc_id}"

  ingress {
    protocol    = "tcp"
    from_port   = 8200
    to_port     = 8201
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

/*--------------------------------------------------------------
Vault Cluster AWS KMS key
--------------------------------------------------------------*/
resource "aws_kms_key" "vault" {
  description             = "Vault KMS key"
  deletion_window_in_days = "${var.kms_deletion_days}"
  enable_key_rotation     = "${var.kms_key_rotate}"

  tags {
    Name = "vault-kms-${var.cluster_name}"
  }
}

resource "random_id" "consul_key" {
  byte_length = 16
}

resource "aws_ssm_parameter" "consul_key" {
  name   = "/${var.ssm_parameter_path}/vault/consul-encrypt"
  type   = "SecureString"
  value  = "${random_id.consul_key.b64_std}"
  key_id = "${aws_kms_key.vault.id}"
  overwrite = true
}

/*--------------------------------------------------------------
Vault Cluster Instance Security Group
--------------------------------------------------------------*/

resource "aws_security_group" "vault_cluster_int" {
  name        = "vault_cluster_int"
  description = "The SG for vault Servers Internal comms"
  vpc_id      = "${var.vpc_id}"
}

/*--------------------------------------------------------------
Vault Cluster Internal Security Group Rules
--------------------------------------------------------------*/
resource "aws_security_group_rule" "vault_cluster_allow_elb_820x_tcp" {
  count                    = "${(var.use_elb || var.use_asg ? 1 : 0)}"
  type                     = "ingress"
  from_port                = 8200
  to_port                  = 8201
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.elb_sg.id}"
  description              = "Vault API port between elb and servers"
  security_group_id        = "${aws_security_group.vault_cluster_int.id}"
}

resource "aws_security_group_rule" "vault_cluster_allow_self_8300-8302_tcp" {
  type              = "ingress"
  from_port         = 8300
  to_port           = 8302
  protocol          = "tcp"
  self              = true
  description       = "Consul gossip protocol between agents and servers"
  security_group_id = "${aws_security_group.vault_cluster_int.id}"
}

resource "aws_security_group_rule" "vault_cluster_allow_self_8301-8302_udp" {
  type              = "ingress"
  from_port         = 8301
  to_port           = 8302
  protocol          = "udp"
  self              = true
  description       = "Consul gossip protocol between agents and servers"
  security_group_id = "${aws_security_group.vault_cluster_int.id}"
}

resource "aws_security_group_rule" "vault_cluster_allow_self_8200_tcp" {
  type              = "ingress"
  from_port         = 8200
  to_port           = 8200
  protocol          = "tcp"
  self              = true
  description       = "Vault API port between agents and servers"
  security_group_id = "${aws_security_group.vault_cluster_int.id}"
}

resource "aws_security_group_rule" "vault_cluster_allow_self_8201_tcp" {
  type              = "ingress"
  from_port         = 8201
  to_port           = 8201
  protocol          = "tcp"
  self              = true
  description       = "Vault listen port between servers"
  security_group_id = "${aws_security_group.vault_cluster_int.id}"
}

resource "aws_security_group_rule" "vault_cluster_allow_self_8500_tcp" {
  type              = "ingress"
  from_port         = 8500
  to_port           = 8500
  protocol          = "tcp"
  self              = true
  description       = "Consul API port between agents and servers"
  security_group_id = "${aws_security_group.vault_cluster_int.id}"
}

resource "aws_security_group_rule" "vault_cluster_allow_self_8600_tcp" {
  type              = "ingress"
  from_port         = 8600
  to_port           = 8600
  protocol          = "tcp"
  self              = true
  description       = "Consul DNS port between agents and servers"
  security_group_id = "${aws_security_group.vault_cluster_int.id}"
}

resource "aws_security_group_rule" "vault_cluster_allow_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.vault_cluster_int.id}"
}

/*------------------------------------------------------------------------------
 This is the IAM profile setup for the cluster servers to allow the consul
 servers to join a cluster.
------------------------------------------------------------------------------*/
resource "aws_iam_instance_profile" "cluster_server" {
  name = "cluster-server-${var.cluster_name}"
  role = "${aws_iam_role.cluster_server.name}"
}

resource "aws_iam_role" "cluster_server" {
  name               = "cluster-server-${var.cluster_name}"
  path               = "/"
  assume_role_policy = "${file("${path.module}/provisioning/files/cluster-server-role.json")}"
}

resource "aws_iam_role_policy" "cluster_server" {
  name   = "cluster-server-${var.cluster_name}"
  role   = "${aws_iam_role.cluster_server.id}"
  policy = "${file("${path.module}/provisioning/files/cluster-server-role-policy.json")}"
}

/*--------------------------------------------------------------
S3 IAM Role and Policy to allow access to the userdata install files
--------------------------------------------------------------*/
resource "aws_iam_role_policy" "s3-access" {
  name   = "s3-access-install-${var.cluster_name}"
  role   = "${aws_iam_role.cluster_server.id}"
  policy = "${data.template_file.s3_iam_policy.rendered}"
}

data "template_file" "s3_iam_policy" {
  template = "${file("${path.module}/provisioning/templates/s3-access-role.json.tpl")}"

  vars {
    s3-bucket-name = "${var.install_bucket}"
  }
}

/*--------------------------------------------------------------
KMS IAM Role and Policy to allow access to the KMS key from vault servers to
utilise auto-unseal
--------------------------------------------------------------*/
data "template_file" "vault_kms_unseal" {
  count    = "${(var.use_auto_unseal ? 1 : 0)}"
  template = "${file("${path.module}/provisioning/templates/kms-access-role.json.tpl")}"

  vars {
    kms_arn = "${aws_kms_key.vault.arn}"
  }
}

resource "aws_iam_role_policy" "kms-access" {
  count  = "${(var.use_auto_unseal ? 1 : 0)}"
  name   = "kms-access-${var.cluster_name}"
  role   = "${aws_iam_role.cluster_server.id}"
  policy = "${data.template_file.vault_kms_unseal.rendered}"
}

/*--------------------------------------------------------------
SSM parameter store IAM policy used to fetch Consul and Vault tokens
--------------------------------------------------------------*/
data "template_file" "vault_ssm_policy" {
  template = "${file("${path.module}/provisioning/templates/ssm-parameter-policy.json.tpl")}"

  vars {
    aws_region    = "${var.aws_region}"
    account_id    = "${data.aws_caller_identity.current.account_id}"
    ssm_base_path = "${var.ssm_parameter_path}"
  }
}

resource "aws_iam_role_policy" "vault_ssm" {
  name   = "ssm-parameter-policy-${var.cluster_name}"
  role   = "${aws_iam_role.cluster_server.id}"
  policy = "${data.template_file.vault_ssm_policy.rendered}"
}

/*--------------------------------------------------------------
This is the set up of the userdata template file for the install
--------------------------------------------------------------*/

locals {
  api_address = "${coalesce(var.elb_fqdn, aws_elb.vault_elb.dns_name)}"
}

data "template_file" "vault_user_data" {
  template = "${file("${path.module}/provisioning/templates/vault_ud.tpl")}"

  vars {
    use_userdata        = "${var.use_userdata}"
    install_bucket      = "${var.install_bucket}"
    vault_bin           = "${var.vault_bin}"
    vault_version       = "${var.vault_version}"
    tls_ca              = "${var.consul_tls_ca}"
    tls_cert            = "${var.vault_tls_cert}"
    tls_key             = "${var.vault_tls_key}"
    consul_bin          = "${var.consul_bin}"
    consul_version      = "${var.consul_version}"
    cluster_tag_key     = "${var.cluster_tag_key}"
    cluster_tag_value   = "${var.cluster_tag_value}"
    consul_cluster_size = "${var.consul_cluster_size}"
    aws_region          = "${var.aws_region}"
    api_addr            = "${(var.use_elb ? local.api_address : "host")}"
    use_auto_unseal     = "${var.use_auto_unseal}"
    kms_key_arn         = "${aws_kms_key.vault.arn}"
    ssm_param           = "${aws_ssm_parameter.consul_key.name}"
  }
}

data "template_file" "consul_user_data" {
  template = "${file("${path.module}/provisioning/templates/consul_ud.tpl")}"

  vars {
    use_userdata        = "${var.use_userdata}"
    install_bucket      = "${var.install_bucket}"
    consul_version      = "${var.consul_version}"
    consul_bin          = "${var.consul_bin}"
    tls_ca              = "${var.consul_tls_ca}"
    tls_cert            = "${var.consul_tls_cert}"
    tls_key             = "${var.consul_tls_key}"
    cluster_tag_key     = "${var.cluster_tag_key}"
    cluster_tag_value   = "${var.cluster_tag_value}"
    consul_cluster_size = "${var.consul_cluster_size}"
    aws_region          = "${var.aws_region}"
    ssm_param           = "${aws_ssm_parameter.consul_key.name}"
  }
}
