locals {
  s3_common_tags = merge(local.aws_tags_common_tags, {
    service = "AWS/S3"
  })
  s3_buckets_without_tags_query_override = replace(replace(local.untagged_resources_query, "__TABLE_NAME__", "aws_s3_bucket"), "__TITLE__", "concat('S3 Bucket ', name, ' [', region, '/', account_id, ']')")
  s3_bucket_default_tags = merge(var.global_default_tags, var.s3_bucket_default_tags)
}

variable "s3_bucket_default_tags" {
  type        = map(string)
  description = ""
  default     = {}
}