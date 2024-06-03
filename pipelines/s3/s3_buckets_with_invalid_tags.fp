locals = {
  s3_buckets_all_tagging_controls = {
    "prohibited_tags"          = { pipeline = pipeline.detect_and_correct_s3_buckets_with_prohibited_tags }
    "incorrect_tag_key_casing" = { pipeline = pipeline.detect_and_correct_s3_buckets_with_incorrect_tag_key_casing }
    "mandatory_tags"           = { pipeline = pipeline.detect_and_correct_s3_buckets_without_mandatory_tags }
    "standardized_tag_keys"    = { pipeline = pipeline.detect_and_correct_s3_buckets_without_standardized_tag_keys }
    "misspelled_tag_values"    = { pipeline = pipeline.detect_and_correct_s3_buckets_with_misspelled_tag_values }
    "unexpected_tag_values"    = { pipeline = pipeline.detect_and_correct_s3_buckets_with_unexpected_tag_values }
  }

  // TODO: Consider making this a variable (or populated by one) to allow for easier customization of controls to run
  s3_buckets_enabled_tagging_controls = [
    "prohibited_tags",
    "incorrect_tag_key_casing",
    "mandatory_tags",
    "standardized_tag_keys",
    "misspelled_tag_values",
    "unexpected_tag_values"
  ]
}

pipeline "detect_and_correct_s3_buckets_with_invalid_tags" {
  title       = "Detect and correct S3 buckets with invalid tags"
  description = "" // TODO: Add description

  param "database" {
    type        = string
    description = local.description_database
    default     = var.database
  }

  param "notifier" {
    type        = string
    description = local.description_notifier
    default     = var.notifier
  }

  param "notification_level" {
    type        = string
    description = local.description_notifier_level
    default     = var.notification_level
  }

  param "approvers" {
    type        = list(string)
    description = local.description_approvers
    default     = var.approvers
  }

  step "pipeline" "control" {
    for_each        = local.s3_buckets_enabled_tagging_controls
    max_concurrency = 1

    pipeline = local.s3_buckets_all_tagging_controls[each.key].pipeline
    args     = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}