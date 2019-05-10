resource "aws_s3_bucket" "object_bucket" {
  bucket        = "${var.namespace}-vault-objects"
  region        = "${var.region}"
  force_destroy = true

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  tags {
    "Environment" = "${var.environment}"
  }
}

resource "aws_s3_bucket_object" "functions" {
  bucket = "${aws_s3_bucket.object_bucket.id}"
  key    = "artifacts/funcs.sh"
  source = "${path.module}/files/funcs.sh"
  etag   = "${filemd5("${path.module}/files/funcs.sh")}"
}

resource "aws_s3_bucket_object" "install_consul" {
  bucket = "${aws_s3_bucket.object_bucket.id}"
  key    = "artifacts/install_consul.sh"
  source = "${path.module}/files/install_consul.sh"
  etag   = "${filemd5("${path.module}/files/install_consul.sh")}"
}

resource "aws_s3_bucket_object" "install_vault" {
  bucket = "${aws_s3_bucket.object_bucket.id}"
  key    = "artifacts/install_vault.sh"
  source = "${path.module}/files/install_vault.sh"
  etag   = "${filemd5("${path.module}/files/install_vault.sh")}"
}

