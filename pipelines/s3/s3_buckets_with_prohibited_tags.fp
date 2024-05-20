locals {
  s3_buckets_with_prohibited_tags_query = replace(
    replace(
      replace(
        replace(
          local.prohibited_tags_query, 
          "__TABLE_NAME__", 
          "aws_s3_bucket"
        ),
        "__TITLE__", 
        "concat('S3 Bucket ', name, ' [', region, '/', account_id, ']')"
      ),
      "__PROHIBITED_TAGS__", 
      join(", ", formatlist("'%s'", [for tag in concat(var.global_prohibited_tag_keys, var.s3_buckets_with_prohibited_tags_keys) : lower(tag)]))
    ),
    "__ADDITIONAL_GROUP_BY__", 
    "name, account_id"
  )
}

trigger "query" "detect_and_correct_s3_buckets_with_prohibited_tags" {
  title         = "Detect & correct S3 buckets with prohibited tags"
  description   = "Detects S3 buckets which have prohibited tags and runs your chosen action."
  documentation = file("./pipelines/s3/docs/detect_and_correct_s3_buckets_with_prohibited_tags_trigger.md")
  tags          = merge(local.s3_common_tags, { class = "prohibited" })

  enabled  = var.s3_buckets_with_prohibited_tags_trigger_enabled
  schedule = var.s3_buckets_with_prohibited_tags_trigger_schedule
  database = var.database
  sql      = local.s3_buckets_with_prohibited_tags_query

  capture "insert" {
    pipeline = pipeline.correct_s3_buckets_with_prohibited_tags
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_s3_buckets_with_prohibited_tags" {
  title         = "Detect & correct S3 buckets with prohibited tags"
  description   = "Detects S3 buckets which have prohibited tags and runs your chosen action."
  documentation = file("./pipelines/s3/docs/detect_and_correct_s3_buckets_with_prohibited_tags.md")
  tags          = merge(local.s3_common_tags, { class = "prohibited", type = "featured" })

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
    default     = var.s3_buckets_with_prohibited_tags_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.s3_buckets_with_prohibited_tags_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.s3_buckets_with_prohibited_tags_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_s3_buckets_with_prohibited_tags
    args = {
      items              = step.query.detect.rows
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_s3_buckets_with_prohibited_tags" {
  title         = "Correct S3 buckets with prohibited tags"
  description   = "Runs corrective action on a collection of S3 buckets which have prohibited tags."
  documentation = file("./pipelines/s3/docs/correct_s3_buckets_with_prohibited_tags.md")
  tags          = merge(local.s3_common_tags, { class = "untagged" })

  param "items" {
    type = list(object({
      title           = string
      arn             = string
      region          = string
      cred            = string
      prohibited_tags = list(string)
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
    default     = var.s3_buckets_with_prohibited_tags_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.s3_buckets_with_prohibited_tags_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} S3 Buckets with prohibited tags."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.arn => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_s3_bucket_with_prohibited_tags
    args = {
      title              = each.value.title
      arn                = each.value.arn
      region             = each.value.region
      cred               = each.value.cred
      prohibited_tags    = each.value.prohibited_tags
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_s3_bucket_with_prohibited_tags" {
  title         = "Correct one S3 bucket with prohibited tags"
  description   = "Runs corrective action on an individual S3 bucket which has prohibited tags."
  documentation = file("./pipelines/s3/docs/correct_one_s3_bucket_with_prohibited_tags.md")
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

  param "prohibited_tags" {
    type        = list(string)
    description = local.description_prohibited_tags
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
    default     = var.s3_buckets_with_prohibited_tags_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.s3_buckets_with_prohibited_tags_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected ${param.title} with prohibited tags (${join(", ", param.prohibited_tags)})."
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
            text     = "Skipped ${param.title} with prohibited tags."
          }
          success_msg = ""
          error_msg   = ""
        }
       "delete_prohibited_tags" = {
          label        = "Delete Prohibited Tags"
          value        = "delete_prohibited_tags"
          style        = local.style_alert
          pipeline_ref = local.aws_pipeline_untag_resources
          pipeline_args = {
            cred          = param.cred 
            region        = param.region
            resource_arns = [param.arn]
            tag_keys      = param.prohibited_tags
          }
          success_msg = "Removed prohitbited tags from ${param.title}."
          error_msg   = "Error removing prohitbited tags from ${param.title}."
        }
      }
    }
  }
}

variable "s3_buckets_with_prohibited_tags_keys" {
  type        = list(string)
  description = ""
  default     = []
}

variable "s3_buckets_with_prohibited_tags_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "s3_buckets_with_prohibited_tags_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "s3_buckets_with_prohibited_tags_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "s3_buckets_with_prohibited_tags_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "delete_prohibited_tags"]
}