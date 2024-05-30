locals {
  s3_buckets_with_unexpected_tag_values_query = replace(
    replace(
      replace(
        local.unexpected_tag_values_query, 
        "__TABLE_NAME__", 
        "aws_s3_bucket"
      ),
      "__TITLE__", 
      "concat('S3 Bucket ', r.name, ' [', r.region, '/', r.account_id, ']')"
    ),
    "__VALUE_MAPPINGS__", 
    join(" union all ", [for key, values in var.expected_tag_values : "select '${key}' as tag_key, array[${join(", ", [for v in values.value_patterns : "'${v}'"])}, '%'] as value_patterns, '${values.default_value}' as default_value"])
  )
}

trigger "query" "detect_and_correct_s3_buckets_with_unexpected_tag_values" {
  title         = "Detect & correct S3 buckets with unexpected tag values"
  description   = "Detects S3 buckets with unexpected tag values and runs your chosen action."
  // documentation = file("./pipelines/s3/docs/detect_and_correct_s3_buckets_with_unexpected_tag_values_trigger.md")
  // tags          = merge(local.s3_common_tags, { class = "" })

  enabled  = var.s3_buckets_with_unexpected_tag_values_trigger_enabled
  schedule = var.s3_buckets_with_unexpected_tag_values_trigger_schedule
  database = var.database
  sql      = local.s3_buckets_with_unexpected_tag_values_query

  capture "insert" {
    pipeline = pipeline.correct_s3_buckets_with_unexpected_tag_values
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_s3_buckets_with_unexpected_tag_values" {
  title         = "Detect & correct S3 buckets with unexpected tag values"
  description   = "Detects S3 buckets with unexpected tag values and runs your chosen action."
  // documentation = file("./pipelines/s3/docs/detect_and_correct_s3_buckets_with_unexpected_tag_values.md")
  // tags          = merge(local.s3_common_tags, { class = "", type = "featured" })

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
    default     = var.s3_buckets_with_unexpected_tag_values_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.s3_buckets_with_unexpected_tag_values_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.s3_buckets_with_unexpected_tag_values_query

    output "debug" {
      value = local.s3_buckets_with_unexpected_tag_values_query
    }
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_s3_buckets_with_unexpected_tag_values
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

pipeline "correct_s3_buckets_with_unexpected_tag_values" {
  title         = "Correct S3 buckets with unexpected tag values"
  description   = "Runs corrective action on a collection of S3 buckets which have misspellings or typos in the tag values."
  // documentation = file("./pipelines/s3/docs/correct_s3_buckets_with_unexpected_tag_values.md")
  // tags          = merge(local.s3_common_tags, { class = "" })

  param "items" {
    type = list(object({
      title          = string
      arn            = string
      region         = string
      cred           = string
      invalid_values = map(string)
      corrected_tags = map(string)
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
    default     = var.s3_buckets_with_unexpected_tag_values_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.s3_buckets_with_unexpected_tag_values_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} S3 Buckets with unexpected tag values."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.arn => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_s3_bucket_with_unexpected_tag_values
    args            = {
      title              = each.value.title
      arn                = each.value.arn
      region             = each.value.region
      cred               = each.value.cred
      incorrect_tags     = each.value.incorrect_tags
      corrected_tags     = each.value.corrected_tags
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_s3_bucket_with_unexpected_tag_values" {
  title         = "Correct one S3 bucket with unexpected tag values"
  description   = "Runs corrective action on a single S3 bucket which has misspellings or typos in the tag values."
  // documentation = file("./pipelines/s3/docs/correct_one_s3_bucket_with_unexpected_tag_values.md")
  // tags          = merge(local.s3_common_tags, { class = "" })

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

  param "invalid_values" {
    type        = map(string)
    description = "" // TODO: Add description
  }

  param "corrected_tags" {
    type        = map(string)
    description = "" // TODO: Add description
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
    default     = var.s3_buckets_with_unexpected_tag_values_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.s3_buckets_with_unexpected_tag_values_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected ${param.title} with unexpected tag values."
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
            text     = "Skipped ${param.title} with unexpected tag values."
          }
          success_msg = ""
          error_msg   = ""
        }
       "update_tag_values" = {
          label        = "Update Tag Values"
          value        = "update_tag_values"
          style        = local.style_ok
          pipeline_ref = local.aws_pipeline_tag_resources
          pipeline_args = {
            cred          = param.cred 
            region        = param.region
            resource_arns = [param.arn]
            tags          = param.corrected_tags
          }
          success_msg = "Applied updated tag values to ${param.title}."
          error_msg   = "Error applying updated tag values to ${param.title}"
        }
      }
    }
  }
}

variable "s3_buckets_with_unexpected_tag_values_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "s3_buckets_with_unexpected_tag_values_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "s3_buckets_with_unexpected_tag_values_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "s3_buckets_with_unexpected_tag_values_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "update_tag_values"]
}