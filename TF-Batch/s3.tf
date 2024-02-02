resource "aws_s3_bucket" "data" {
  bucket = "batch-customer-data-s3-bucket"

  tags = {
    Name        = "macie-bucket"
    Environment = "dev"
  }
}

resource "aws_s3_bucket" "report" {
  bucket = "batch-report-s3-bucket/"

  tags = {
    Name        = "macie-bucket"
    Environment = "dev"
  }
}

resource "aws_s3_bucket_ownership_controls" "private" {
  bucket = aws_s3_bucket.demo.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "private" {
  depends_on = [aws_s3_bucket_ownership_controls.private]

  bucket = aws_s3_bucket.demo.id
  acl    = "private"
}

resource "aws_s3_object" "object" {
    for_each = fileset("../Customer-Data/", "**")
    bucket = aws_s3_bucket.demo.id
    key    = "Customer-Data/${each.value}"
    source = "../Customer-Data/${each.value}"
}