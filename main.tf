terraform {
  required_version = ">= 0.11.11"
}

data "aws_caller_identity" "current" {}

data "aws_s3_bucket" "selected" {
  bucket = "${var.s3_bucket}"
}