trigger "query" "detect_and_correct_s3_buckets_without_tags" {
  title         = "Detect & correct S3 buckets without tags"
  description   = "Detects S3 buckets which do not have a lifecycle policy and runs your chosen action."
  // documentation = file("./pipelines/s3/docs/detect_and_correct_s3_buckets_without_tags_trigger.md")
  tags          = merge(local.s3_common_tags, { class = "untagged" })

  enabled  = var.s3_buckets_without_tags_trigger_enabled
  schedule = var.s3_buckets_without_tags_trigger_schedule
  database = var.database
  sql      = local.s3_buckets_without_tags_query_override

  capture "insert" {
    pipeline = pipeline.correct_s3_buckets_without_tags
    args = {
      items = self.inserted_rows
      tags  = local.s3_bucket_default_tags
    }
  }
}

pipeline "detect_and_correct_s3_buckets_without_tags" {
  title         = "Detect & correct S3 buckets without tags"
  description   = "Detects S3 buckets which do not have a lifecycle policy and runs your chosen action."
  // documentation = file("./pipelines/s3/docs/detect_and_correct_s3_buckets_without_tags.md")
  tags          = merge(local.s3_common_tags, { class = "untagged", type = "featured" })

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

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.s3_buckets_without_tags_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.s3_buckets_without_tags_enabled_actions
  }

  param "tags" {
    type        = map(string)
    description = "The tags to apply to the S3 bucket."
    default     = local.s3_bucket_default_tags
  }

  step "query" "detect" {
    database = param.database
    sql      = local.s3_buckets_without_tags_query_override
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_s3_buckets_without_tags
    args = {
      items              = step.query.detect.rows
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
      tags               = param.tags
    }
  }
}

pipeline "correct_s3_buckets_without_tags" {
  title         = "Correct S3 buckets without tags"
  description   = "Runs corrective action on a collection of S3 buckets which do not have tags."
  // documentation = file("./pipelines/s3/docs/correct_s3_buckets_without_tags.md")
  tags          = merge(local.s3_common_tags, { class = "untagged" })

  param "items" {
    type = list(object({
      title      = string
      arn        = string
      region     = string
      cred       = string
    }))
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

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.s3_buckets_without_tags_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.s3_buckets_without_tags_enabled_actions
  }

  param "tags" {
    type        = map(string)
    description = "The tags to apply to the S3 bucket."
    default     = local.s3_bucket_default_tags
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} S3 Buckets without tags."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.arn => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_s3_bucket_without_tags
    args = {
      title              = each.value.title
      arn                = each.value.arn
      region             = each.value.region
      cred               = each.value.cred
      tags               = param.tags
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_s3_bucket_without_tags" {
  title         = "Correct one S3 bucket without tags"
  description   = "Runs corrective action on an individual S3 bucket which does not have tags."
  // documentation = file("./pipelines/s3/docs/correct_one_s3_bucket_without_tags.md")
  tags          = merge(local.s3_common_tags, { class = "untagged" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "arn" {
    type        = string
    description = local.description_arn
  }

  param "region" {
    type        = string
    description = local.description_region
  }

  param "cred" {
    type        = string
    description = local.description_credential
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

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.s3_buckets_without_tags_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.s3_buckets_without_tags_enabled_actions
  }

  param "tags" {
    type        = map(string)
    description = "The tags to apply to the S3 bucket."
    default     = local.s3_bucket_default_tags
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected ${param.title} without tags."
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
      actions = {
        "skip" = {
          label        = "Skip"
          value        = "skip"
          style        = local.style_info
          pipeline_ref = local.pipeline_optional_message
          pipeline_args = {
            notifier = param.notifier
            send     = param.notification_level == local.level_verbose
            text     = "Skipped ${param.title} without tags."
          }
          success_msg = ""
          error_msg   = ""
        }
       "apply_tags" = {
          label        = "Apply Tags"
          value        = "apply_tags"
          style        = local.style_ok
          pipeline_ref = local.aws_pipeline_tag_resources
          pipeline_args = {
            cred          = param.cred 
            region        = param.region
            resource_arns = [param.arn]
            tags          = param.tags
          }
          success_msg = "Applied tags to ${param.title}."
          error_msg   = "Error applying tags to ${param.title}."
        }
      }
    }
  }
}

variable "s3_buckets_without_tags_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "s3_buckets_without_tags_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "s3_buckets_without_tags_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "s3_buckets_without_tags_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "apply_tags"]
}