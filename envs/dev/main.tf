resource "aws_s3_bucket" "this" {
  bucket = "${var.solution}-${var.project}-${var.environment}"
  lifecycle {
    prevent_destroy = false
  }
  tags = {
    Name = "${var.solution}-${var.project}-${var.environment}"
  }
}