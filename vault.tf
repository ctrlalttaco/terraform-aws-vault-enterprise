resource "aws_kms_key" "vault" {
  description             = "Vault KMS key"
  deletion_window_in_days = "${var.vault_kms_deletion_days}"
  enable_key_rotation     = "${var.vault_kms_key_rotate}"

  tags {
    "Name"        = "vault-kms-${var.namespace}"
    "Environment" = "${var.environment}"
  }
}

resource "aws_key_pair" "vault" {
  key_name   = "vault-server-${var.namespace}"
  public_key = "${var.vault_ssh_public_key}"
}

resource "aws_iam_instance_profile" "vault" {
  name = "vault-server-${var.namespace}"
  role = "${aws_iam_role.vault.name}"
}

resource "aws_iam_role" "vault" {
  name               = "vault-server-${var.namespace}"
  path               = "/"
  assume_role_policy = "${file("${path.module}/files/iam_role.json")}"
}

resource "aws_iam_role_policy" "vault" {
  name   = "vault-server-${var.namespace}"
  role   = "${aws_iam_role.vault.id}"
  policy = "${file("${path.module}/files/iam_role_policy.json")}"
}

resource "aws_launch_configuration" "vault_asg" {
  name_prefix          = "vault-${var.namespace}-"
  image_id             = "${var.vault_ami_id}"
  instance_type        = "${var.vault_instance_type}"
  iam_instance_profile = "${aws_iam_instance_profile.vault.id}"
  security_groups      = ["${concat(var.vault_additional_security_groups, list(aws_security_group.vault.id), list(aws_security_group.vault_internal.id))}"]
  key_name             = "${aws_key_pair.vault.key_name}"
  user_data            = "${data.template_file.vault_user_data.rendered}"

  lifecycle = {
    create_before_destroy = true
  }
}

resource "aws_placement_group" "vault" {
  name     = "vault-${var.namespace}"
  strategy = "spread"
}

resource "aws_autoscaling_group" "vault_asg" {
  name_prefix          = "${var.namespace}"
  launch_configuration = "${aws_launch_configuration.vault_asg.name}"
  availability_zones   = ["${values(var.vault_private_subnets)}"]
  vpc_zone_identifier  = ["${keys(var.vault_private_subnets)}"]

  min_size             = "${var.vault_cluster_size_min}"
  max_size             = "${var.vault_cluster_size_max}"
  desired_capacity     = "${var.vault_cluster_size_min}"
  placement_group      = "${aws_placement_group.vault.id}"
  termination_policies = ["${var.vault_termination_policies}"]

  health_check_type         = "EC2"
  health_check_grace_period = "${var.vault_health_check_grace_period}"
  wait_for_capacity_timeout = "${var.vault_wait_for_capacity_timeout}"

  enabled_metrics = ["${var.vault_enabled_metrics}"]

  lifecycle = {
    create_before_destroy = true
  }

  tag = {
    key                 = "Name"
    value               = "vault-${var.namespace}"
    propagate_at_launch = true
  }

  tag = {
    key                 = "Environment"
    value               = "${var.environment}"
    propagate_at_launch = true
  }

  depends_on = ["aws_s3_bucket_object.consul_zip", "aws_s3_bucket_object.vault_zip"]
}

resource "random_id" "vault_install_script" {
  keepers = {
    install_hash = "${filemd5("${path.module}/files/install_vault.sh")}"
    funcs_hash   = "${filemd5("${path.module}/files/funcs.sh")}"
  }

  byte_length = 8
}

data "template_file" "vault_user_data" {
  template = "${file("${path.module}/templates/vault_user_data.sh.tpl")}"

  vars {
    packerized                                 = "${var.vault_packerized}"
    s3_bucket                                  = "${aws_s3_bucket.object_bucket.id}"
    s3_path                                    = "artifacts"
    consul_rejoin_tag_key                             = "${var.consul_cluster_tag_key}"
    consul_rejoin_tag_value                           = "${var.consul_cluster_tag_value}"
    consul_zip                                 = "${basename(var.consul_zip_path)}"
    vault_zip                                  = "${basename(var.vault_zip_path)}"
    enable_consul_acl                          = "${var.enable_consul_acl}"
    ssm_parameter_consul_gossip_encryption_key = "${var.ssm_parameter_consul_gossip_encryption_key}"
    ssm_parameter_consul_client_tls_ca         = "${var.ssm_parameter_consul_client_tls_ca}"
    ssm_parameter_consul_client_tls_cert       = "${var.ssm_parameter_consul_client_tls_cert}"
    ssm_parameter_consul_client_tls_key        = "${var.ssm_parameter_consul_client_tls_key}"
    ssm_parameter_vault_tls_cert_chain         = "${var.ssm_parameter_vault_tls_cert_chain}"
    ssm_parameter_vault_tls_key                = "${var.ssm_parameter_vault_tls_key}"
    ssm_parameter_consul_acl_agent_token       = "${var.ssm_parameter_consul_acl_agent_token}"
    ssm_parameter_consul_acl_app_token         = "${var.ssm_parameter_consul_acl_app_token}"
    install_script_hash                        = "${(var.vault_packerized ? random_id.vault_install_script.hex : "" )}"
    vault_api_address                          = "${aws_lb.vault_lb.dns_name}"
    vault_unseal_kms_key_arn                   = "${aws_kms_key.vault.arn}"
  }
}

resource "aws_lb_target_group" "vault_asg" {
  name        = "vault-${var.namespace}"
  port        = "${var.vault_api_port}"
  protocol    = "HTTPS"
  target_type = "instance"
  vpc_id      = "${var.vpc_id}"

  health_check = {
    protocol            = "${var.vault_health_check_protocol}"
    path                = "${var.vault_health_check_path}"
    interval            = "${var.vault_health_check_interval}"
    healthy_threshold   = "${var.vault_health_check_healthy_threshold}"
    unhealthy_threshold = "${var.vault_health_check_unhealthy_threshold}"
    timeout             = "${var.vault_health_check_timeout}"
    matcher             = "${var.vault_health_check_success_codes}"
  }

  stickiness = {
    type    = "lb_cookie"
    enabled = false
  }
}

resource "aws_autoscaling_attachment" "vault_asg_attachment" {
  autoscaling_group_name = "${aws_autoscaling_group.vault_asg.id}"
  alb_target_group_arn   = "${aws_lb_target_group.vault_asg.arn}"
}

resource "aws_lb" "vault_lb" {
  name_prefix                      = "vault-"
  internal                         = true
  load_balancer_type               = "application"
  enable_cross_zone_load_balancing = true
  idle_timeout                     = "${var.vault_idle_timeout}"
  subnets                          = ["${keys(var.vault_private_subnets)}"]
  security_groups                  = ["${aws_security_group.vault_lb_sg.id}"]

  tags = {
    "Environment" = "${var.environment}"
  }
}

resource "aws_lb_listener" "vault_lb" {
  load_balancer_arn = "${aws_lb.vault_lb.arn}"
  port              = "${var.vault_api_port}"
  protocol          = "HTTPS"
  certificate_arn   = "${var.vault_lb_cert_arn}"

  default_action = {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.vault_asg.arn}"
  }
}

resource "aws_security_group" "vault_lb_sg" {
  description = "Enable vault UI and API access to the alb"
  name        = "vault-lb-${var.namespace}-sg"
  vpc_id      = "${var.vpc_id}"

  ingress {
    protocol    = "tcp"
    from_port   = 8200
    to_port     = 8200
    cidr_blocks = ["${var.vault_api_ingress_cidr_blocks}"]
  }

  egress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Environment" = "${var.environment}"
  }
}

resource "aws_security_group" "vault" {
  name        = "vault-${var.namespace}"
  description = "Security group for communication to Vault servers"
  vpc_id      = "${var.vpc_id}"

  tags = {
    "Environment" = "${var.environment}"
  }
}

resource "aws_security_group" "vault_internal" {
  name        = "vault-int-${var.namespace}"
  description = "Security group for internal communication to Vault servers"
  vpc_id      = "${var.vpc_id}"

  tags = {
    "Environment" = "${var.environment}"
  }
}

resource "aws_security_group_rule" "vault_api_ingress" {
  type                     = "ingress"
  from_port                = 8200
  to_port                  = 8200
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.vault_lb_sg.id}"
  description              = "Vault API"
  security_group_id        = "${aws_security_group.vault.id}"
}

resource "aws_security_group_rule" "vault_api_ingress_internal" {
  type              = "ingress"
  from_port         = 8200
  to_port           = 8200
  protocol          = "tcp"
  self              = true
  description       = "Vault API internal"
  security_group_id = "${aws_security_group.vault_internal.id}"
}

resource "aws_security_group_rule" "vault_cluster_ingress_internal" {
  type              = "ingress"
  from_port         = 8201
  to_port           = 8201
  protocol          = "tcp"
  self              = true
  description       = "Vault internal cluster traffic"
  security_group_id = "${aws_security_group.vault_internal.id}"
}

resource "aws_security_group_rule" "vault_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["${var.vault_egress_cidr_blocks}"]
  description       = "Vault egress traffic"
  security_group_id = "${aws_security_group.vault.id}"
}

resource "aws_security_group_rule" "vault_egress_internal" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  self              = true
  description       = "Vault internal egress traffic"
  security_group_id = "${aws_security_group.vault_internal.id}"
}

resource "aws_iam_role_policy" "vault_s3" {
  count  = "${var.vault_packerized ? 0 : 1}"
  name   = "vault-server-s3-${var.namespace}"
  role   = "${aws_iam_role.vault.id}"
  policy = "${data.template_file.vault_s3_iam_role_policy.rendered}"
}

data "template_file" "vault_s3_iam_role_policy" {
  count    = "${var.vault_packerized ? 0 : 1}"
  template = "${file("${path.module}/templates/s3_iam_role_policy.json.tpl")}"

  vars {
    s3_bucket_arn = "${aws_s3_bucket.object_bucket.arn}"
  }
}

resource "aws_iam_role_policy" "vault_kms" {
  name   = "vault-server-kms-${var.namespace}"
  role   = "${aws_iam_role.vault.id}"
  policy = "${data.template_file.vault_kms_iam_role_policy.rendered}"
}

data "template_file" "vault_kms_iam_role_policy" {
  template = "${file("${path.module}/templates/vault_kms_iam_role_policy.json.tpl")}"

  vars {
    ssm_kms_key_arn   = "${var.ssm_kms_key_arn}"
    vault_kms_key_arn = "${aws_kms_key.vault.arn}"
  }
}

resource "aws_iam_role_policy" "vault_ssm" {
  name   = "vault-server-ssm-${var.namespace}"
  role   = "${aws_iam_role.vault.id}"
  policy = "${data.template_file.vault_ssm_iam_role_policy.rendered}"
}

data "template_file" "vault_ssm_iam_role_policy" {
  template = "${file("${path.module}/templates/vault_ssm_iam_role_policy.json.tpl")}"

  vars {
    ssm_parameter_arn = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter${var.ssm_parameter_path}"
  }
}
