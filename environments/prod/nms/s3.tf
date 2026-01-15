### S3 Bucket: api data
module "s3-api-assets" {
  source = "git::https://github.com/keepmycloudcom/modules-s3-bucket.git?ref=v1.0.0"
  project_domain = var.project_domain
  name   = "${local.basename}-api-assets"
  bucket = lower("${var.project_env}-api-assets-${var.aws_region}-${var.project_domain}")
  tags   = local.base_tags
}
