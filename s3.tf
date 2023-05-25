# //creating an s3 bucket

resource "aws_s3_bucket" "this" {
  bucket        = "nulp-bucket-courses"
  force_destroy = true
}

resource "aws_s3_bucket_website_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

resource "aws_s3_bucket_policy" "allow_access" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.allow_access.json
}

data "aws_iam_policy_document" "allow_access" {
  policy_id = "PolicyForCourses"
  statement {
    sid       = "AllowCloudFrontServicePrincipal"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.this.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

locals {
  initial_path   = "./react-app-frontend/build/"
  folder         = "static"
  nested_folder1 = "css"
  nested_folder2 = "js"
  nested_folder3 = "media"

}

resource "aws_s3_bucket_object" "data" {
  bucket       = aws_s3_bucket.this.id
  for_each     = fileset("${local.initial_path}", "*")
  key          = each.value
  content_type = "${each.value}" == "index.html" ? "text/html" : ""
  source       = "${local.initial_path}/${each.value}"

  # The filemd5() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the md5() function and the file() function:
  # etag = "${md5(file("path/to/file"))}"
  etag = filemd5("${local.initial_path}/${each.value}")
}

resource "aws_s3_bucket_object" "folder" {
  bucket       = aws_s3_bucket.this.id
  key          = "${local.folder}/"
  content_type = "application/x-directory"
}

resource "aws_s3_bucket_object" "nested_folder1" {
  bucket       = aws_s3_bucket.this.id
  key          = "${local.folder}/${local.nested_folder1}/"
  content_type = "application/x-directory/"

  depends_on = [
    aws_s3_bucket_object.folder
  ]
}

resource "aws_s3_bucket_object" "nested_folder2" {
  bucket       = aws_s3_bucket.this.id
  key          = "${local.folder}/${local.nested_folder2}/"
  content_type = "application/x-directory/"

  depends_on = [
    aws_s3_bucket_object.folder
  ]
}

resource "aws_s3_bucket_object" "nested_folder3" {
  bucket       = aws_s3_bucket.this.id
  key          = "${local.folder}/${local.nested_folder3}/"
  content_type = "application/x-directory/"

  depends_on = [
    aws_s3_bucket_object.folder
  ]
}

resource "aws_s3_bucket_object" "data_inside_nested_folder1" {
  bucket   = aws_s3_bucket.this.id
  for_each = fileset("${local.initial_path}/${local.folder}/${local.nested_folder1}", "*")
  key      = "${local.folder}/${local.nested_folder1}/${each.value}"
  source   = "${local.initial_path}/${local.folder}/${local.nested_folder1}/${each.value}"
  etag     = filemd5("${local.initial_path}/${local.folder}/${local.nested_folder1}/${each.value}")
  content_type = "${each.value}" == "main.d1ac64fa.css" ? "text/css" : ""

  depends_on = [
    aws_s3_bucket_object.nested_folder1
  ]
}

resource "aws_s3_bucket_object" "data_inside_nested_folder2" {
  bucket   = aws_s3_bucket.this.id
  for_each = fileset("${local.initial_path}/${local.folder}/${local.nested_folder2}", "*")
  key      = "${local.folder}/${local.nested_folder2}/${each.value}"
  source   = "${local.initial_path}/${local.folder}/${local.nested_folder2}/${each.value}"
  etag     = filemd5("${local.initial_path}/${local.folder}/${local.nested_folder2}/${each.value}")

  depends_on = [
    aws_s3_bucket_object.nested_folder2
  ]
}

resource "aws_s3_bucket_object" "data_inside_nested_folder3" {
  bucket   = aws_s3_bucket.this.id
  for_each = fileset("${local.initial_path}/${local.folder}/${local.nested_folder3}", "*")
  key      = "${local.folder}/${local.nested_folder3}/${each.value}"
  source   = "${local.initial_path}/${local.folder}/${local.nested_folder3}/${each.value}"
  etag     = filemd5("${local.initial_path}/${local.folder}/${local.nested_folder3}/${each.value}")

  depends_on = [
    aws_s3_bucket_object.nested_folder3
  ]
}

// cloudfront

locals {
  s3_origin_id = "educational"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.this.bucket_regional_domain_name
    origin_id                = local.s3_origin_id
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
  }

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA", "GB", "DE", "UA"]
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  retain_on_delete = false
}