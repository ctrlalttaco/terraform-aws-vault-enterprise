resource "aws_key_pair" "consul" {
  key_name   = "consul-server-${var.namespace}"
  public_key = "${var.consul_ssh_public_key}"
}

resource "aws_iam_instance_profile" "consul" {
  name = "consul-server-${var.namespace}"
  role = "${aws_iam_role.consul.name}"
}

resource "aws_iam_role" "consul" {
  name               = "consul-server-${var.namespace}"
  path               = "/"
  assume_role_policy = "${file("${path.module}/files/iam_role.json")}"
}

resource "aws_iam_role_policy" "consul" {
  name   = "consul-server-${var.namespace}"
  role   = "${aws_iam_role.consul.id}"
  policy = "${file("${path.module}/files/iam_role_policy.json")}"
}

resource "aws_launch_configuration" "consul_asg" {
  name_prefix          = "consul-${var.namespace}-"
  image_id             = "${var.consul_ami_id}"
  instance_type        = "${var.consul_instance_type}"
  iam_instance_profile = "${aws_iam_instance_profile.consul.id}"
  security_groups      = ["${concat(var.consul_additional_security_groups, list(aws_security_group.consul.id), list(aws_security_group.consul_internal.id))}"]
  key_name             = "${aws_key_pair.consul.key_name}"
  user_data            = "${data.template_file.consul_user_data.rendered}"

  lifecycle = {
    create_before_destroy = true
  }
}

resource "aws_placement_group" "consul" {
  name     = "consul-${var.namespace}"
  strategy = "spread"
}

resource "aws_autoscaling_group" "consul_asg" {
  name_prefix          = "${var.namespace}"
  launch_configuration = "${aws_launch_configuration.consul_asg.name}"
  availability_zones   = ["${values(var.consul_private_subnets)}"]
  vpc_zone_identifier  = ["${keys(var.consul_private_subnets)}"]

  min_size             = "${var.consul_cluster_size_min}"
  max_size             = "${var.consul_cluster_size_max}"
  desired_capacity     = "${var.consul_cluster_size_min}"
  placement_group      = "${aws_placement_group.consul.id}"
  termination_policies = ["${var.consul_termination_policies}"]

  health_check_type         = "EC2"
  health_check_grace_period = "${var.consul_health_check_grace_period}"
  wait_for_capacity_timeout = "${var.consul_wait_for_capacity_timeout}"

  enabled_metrics = ["${var.consul_asg_enabled_metrics}"]

  lifecycle = {
    create_before_destroy = true
  }

  tag = {
    key                 = "Name"
    value               = "consul-${var.namespace}"
    propagate_at_launch = true
  }

  tag = {
    key                 = "Environment"
    value               = "${var.environment}"
    propagate_at_launch = true
  }

  tag = {
    key                 = "${var.consul_cluster_tag_key}"
    value               = "${var.consul_cluster_tag_value}"
    propagate_at_launch = true
  }
}

resource "random_id" "consul_install_script" {
  keepers = {
    install_hash = "${filemd5("${path.module}/files/install_consul.sh")}"
    funcs_hash   = "${filemd5("${path.module}/files/funcs.sh")}"
  }

  byte_length = 8
}

data "template_file" "consul_user_data" {
  template = "${file("${path.module}/templates/consul_user_data.sh.tpl")}"

  vars {
    packerized                                 = "${var.consul_packerized}"
    s3_bucket                                  = "${var.s3_bucket}"
    bootstrap_expect                           = "${var.consul_cluster_size_min}"
    rejoin_tag_key                             = "${var.consul_cluster_tag_key}"
    rejoin_tag_value                           = "${var.consul_cluster_tag_value}"
    consul_zip                                 = "${var.consul_zip}"
    enable_consul_acl                          = "${var.enable_consul_acl}"
    ssm_parameter_consul_gossip_encryption_key = "${var.ssm_parameter_consul_gossip_encryption_key}"
    ssm_parameter_consul_server_tls_ca         = "${var.ssm_parameter_consul_server_tls_ca}"
    ssm_parameter_consul_server_tls_cert       = "${var.ssm_parameter_consul_server_tls_cert}"
    ssm_parameter_consul_server_tls_key        = "${var.ssm_parameter_consul_server_tls_key}"
    ssm_parameter_consul_acl_master_token      = "${var.ssm_parameter_consul_acl_master_token}"
    ssm_parameter_consul_acl_agent_token       = "${var.ssm_parameter_consul_acl_agent_token}"
    ssm_parameter_consul_acl_app_token         = "${var.ssm_parameter_consul_acl_app_token}"
    install_script_hash                        = "${(var.consul_packerized ? random_id.consul_install_script.hex : "" )}"
  }
}

resource "aws_security_group" "consul" {
  name        = "consul-${var.namespace}"
  description = "Security group for external communication to Consul servers"
  vpc_id      = "${var.vpc_id}"

  tags = {
    "Owner" = "${var.namespace}"
  }
}

resource "aws_security_group" "consul_internal" {
  name        = "consul-int-${var.namespace}"
  description = "Security group for internal communication to Consul servers"
  vpc_id      = "${var.vpc_id}"

  tags = {
    "Owner" = "${var.namespace}"
  }
}

resource "aws_security_group_rule" "consul_api_ingress" {
  type              = "ingress"
  from_port         = 8500
  to_port           = 8500
  protocol          = "tcp"
  cidr_blocks       = ["${var.consul_api_ingress_cidr_blocks}"]
  description       = "Consul API"
  security_group_id = "${aws_security_group.consul.id}"
}

resource "aws_security_group_rule" "consul_api_ingress_internal" {
  type              = "ingress"
  from_port         = 8500
  to_port           = 8500
  protocol          = "tcp"
  self              = true
  description       = "Consul API internal"
  security_group_id = "${aws_security_group.consul_internal.id}"
}

resource "aws_security_group_rule" "consul_rpc_ingress" {
  type              = "ingress"
  from_port         = 8300
  to_port           = 8300
  protocol          = "tcp"
  cidr_blocks       = ["${var.consul_rpc_ingress_cidr_blocks}"]
  description       = "Consul RPC traffic"
  security_group_id = "${aws_security_group.consul.id}"
}

resource "aws_security_group_rule" "consul_rpc_ingress_internal" {
  type              = "ingress"
  from_port         = 8300
  to_port           = 8300
  protocol          = "tcp"
  self              = true
  description       = "Consul internal RPC traffic"
  security_group_id = "${aws_security_group.consul_internal.id}"
}

resource "aws_security_group_rule" "consul_serf_ingress_tcp" {
  type              = "ingress"
  from_port         = 8301
  to_port           = 8301
  protocol          = "tcp"
  cidr_blocks       = ["${var.consul_serf_ingress_cidr_blocks}"]
  description       = "Consul TCP serf traffic"
  security_group_id = "${aws_security_group.consul.id}"
}

resource "aws_security_group_rule" "consul_serf_ingress_udp" {
  type              = "ingress"
  from_port         = 8301
  to_port           = 8301
  protocol          = "udp"
  cidr_blocks       = ["${var.consul_serf_ingress_cidr_blocks}"]
  description       = "Consul UDP serf traffic"
  security_group_id = "${aws_security_group.consul.id}"
}

resource "aws_security_group_rule" "consul_serf_ingress_tcp_internal" {
  type              = "ingress"
  from_port         = 8301
  to_port           = 8301
  protocol          = "tcp"
  self              = true
  description       = "Consul internal TCP serf traffic"
  security_group_id = "${aws_security_group.consul_internal.id}"
}

resource "aws_security_group_rule" "consul_serf_ingress_udp_internal" {
  type              = "ingress"
  from_port         = 8301
  to_port           = 8301
  protocol          = "udp"
  self              = true
  description       = "Consul internal UDP serf traffic"
  security_group_id = "${aws_security_group.consul_internal.id}"
}

resource "aws_security_group_rule" "consul_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["${var.consul_egress_cidr_blocks}"]
  description       = "Consul egress traffic"
  security_group_id = "${aws_security_group.consul.id}"
}

resource "aws_security_group_rule" "consul_egress_internal" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  self              = true
  description       = "Consul internal egress traffic"
  security_group_id = "${aws_security_group.consul_internal.id}"
}

resource "aws_iam_role_policy" "consul_s3" {
  count  = "${var.consul_packerized ? 0 : 1}"
  name   = "consul-server-s3-${var.namespace}"
  role   = "${aws_iam_role.consul.id}"
  policy = "${data.template_file.consul_s3_iam_role_policy.rendered}"
}

data "template_file" "consul_s3_iam_role_policy" {
  count    = "${var.consul_packerized ? 0 : 1}"
  template = "${file("${path.module}/templates/s3_iam_role_policy.json.tpl")}"

  vars {
    s3_bucket_arn = "${aws_s3_bucket.object_bucket.arn}"
  }
}

resource "aws_iam_role_policy" "consul_kms" {
  name   = "consul-server-kms-${var.namespace}"
  role   = "${aws_iam_role.consul.id}"
  policy = "${data.template_file.consul_kms_iam_role_policy.rendered}"
}

data "template_file" "consul_kms_iam_role_policy" {
  template = "${file("${path.module}/templates/consul_kms_iam_role_policy.json.tpl")}"

  vars {
    kms_key_arn = "${var.ssm_kms_key_arn}"
  }
}

resource "aws_iam_role_policy" "consul_ssm" {
  name   = "consul-server-ssm-${var.namespace}"
  role   = "${aws_iam_role.consul.id}"
  policy = "${data.template_file.consul_ssm_iam_role_policy.rendered}"
}

data "template_file" "consul_ssm_iam_role_policy" {
  template = "${file("${path.module}/templates/consul_ssm_iam_role_policy.json.tpl")}"

  vars {
    ssm_parameter_arn = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter${var.ssm_parameter_path}"
  }
}
