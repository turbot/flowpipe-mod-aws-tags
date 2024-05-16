locals {
  s3_common_tags = merge(local.aws_tags_common_tags, {
    service = "AWS/S3"
  })
  s3_buckets_default_tags    = merge(var.global_default_tags, var.s3_buckets_default_tags)
  s3_buckets_prohibited_tags = concat(var.global_prohibited_tags, var.s3_buckets_prohibited_tags)

  s3_buckets_without_tags_query_override = replace(replace(local.untagged_resources_query, "__TABLE_NAME__", "aws_s3_bucket"), "__TITLE__", "concat('S3 Bucket ', name, ' [', region, '/', account_id, ']')")
  s3_buckets_with_prohibited_tags_query_override = replace(replace(replace(local.prohibited_tags_query, "__TABLE_NAME__", "aws_s3_bucket"), "__TITLE__", "concat('S3 Bucket ', name, ' [', region, '/', account_id, ']')"),"__PROHIBITED_TAGS__", join(", ", formatlist("'%s'", concat(var.global_prohibited_tags, var.s3_buckets_prohibited_tags))))
  
}

variable "s3_buckets_default_tags" {
  type        = map(string)
  description = ""
  default     = {}
}

variable "s3_buckets_prohibited_tags" {
  type        = list(string)
  description = ""
  default     = []
}