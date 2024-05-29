locals {
  s3_buckets_with_incorrect_tag_key_casing_query = replace(
    replace(
      replace(
        local.incorrect_tag_key_casing_query, 
        "__TABLE_NAME__", 
        "aws_s3_bucket"
      ),
      "__TITLE__", 
      "concat('S3 Bucket ', name, ' [', region, '/', account_id, ']')"
    ),
    "__FUNCTION__", 
    var.tag_key_case
  )
}

trigger "query" "detect_and_correct_s3_buckets_with_incorrect_tag_key_casing" {
  title         = "Detect & correct S3 buckets with incorrect tag key casing"
  description   = "Detects S3 buckets which have incorrect tag key casing and runs your chosen action."
  // documentation = file("./pipelines/s3/docs/detect_and_correct_s3_buckets_with_incorrect_tag_key_casing_trigger.md")
  // tags          = merge(local.s3_common_tags, { class = "" })

  enabled  = var.s3_buckets_with_incorrect_tag_key_casing_trigger_enabled
  schedule = var.s3_buckets_with_incorrect_tag_key_casing_trigger_schedule
  database = var.database
  sql      = local.s3_buckets_with_incorrect_tag_key_casing_query

  capture "insert" {
    pipeline = pipeline.correct_s3_buckets_with_incorrect_tag_key_casing
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_s3_buckets_with_incorrect_tag_key_casing" {
  title         = "Detect & correct S3 buckets with incorrect tag key casing"
  description   = "Detects S3 buckets which have incorrect tag key casing and runs your chosen action."
  // documentation = file("./pipelines/s3/docs/detect_and_correct_s3_buckets_with_incorrect_tag_key_casing.md")
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
    default     = var.s3_buckets_with_incorrect_tag_key_casing_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.s3_buckets_with_incorrect_tag_key_casing_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.s3_buckets_with_incorrect_tag_key_casing_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_s3_buckets_with_incorrect_tag_key_casing
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

pipeline "correct_s3_buckets_with_incorrect_tag_key_casing" {
  title         = "Correct S3 buckets with incorrect tag key casing"
  description   = "Runs corrective action on a collection of S3 buckets which have incorrect tag key casing."
  // documentation = file("./pipelines/s3/docs/correct_s3_buckets_with_incorrect_tag_key_casing.md")
  // tags          = merge(local.s3_common_tags, { class = "" })

  param "items" {
    type = list(object({
      title        = string
      arn          = string
      region       = string
      cred         = string
      invalid_tags = map(string)
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
    default     = var.s3_buckets_with_incorrect_tag_key_casing_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.s3_buckets_with_incorrect_tag_key_casing_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} S3 Buckets with incorrect tag key casing."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.arn => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_s3_bucket_with_incorrect_tag_key_casing
    args = {
      title              = each.value.title
      arn                = each.value.arn
      region             = each.value.region
      cred               = each.value.cred
      invalid_tags       = each.value.invalid_tags
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_s3_bucket_with_incorrect_tag_key_casing" {
  title         = "Correct S3 buckets with incorrect tag key casing"
  description   = "Runs corrective action on an individual S3 bucket which has incorrect tag key casing."
  // documentation = file("./pipelines/s3/docs/correct_one_s3_bucket_with_incorrect_tag_key_casing.md")
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

  param "invalid_tags" {
    type        = map(string)
    description = local.description_invalid_tags
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
    default     = var.s3_buckets_with_incorrect_tag_key_casing_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.s3_buckets_with_incorrect_tag_key_casing_enabled_actions
  }

  step "transform" "get_invalid_tag_keys" {
    value = keys(param.invalid_tags)

    output "debug_invalid" {
      value = keys(param.invalid_tags)
    }
  }

  step "transform" "build_new_tags" {
    value = { for key, value in param.invalid_tags : (lower(var.tag_key_case) == "upper" ? upper(key) : lower(key)) => value }

    output "debug_new" {
      value = { for key, value in param.invalid_tags : (lower(var.tag_key_case) == "upper" ? upper(key) : lower(key)) => value }
    }
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected ${param.title} with incorrect tag key casing: (${join(", ", step.transform.get_invalid_tag_keys.value)})."
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
            text     = "Skipped ${param.title} with incorrect tag key casing: (${join(", ", step.transform.get_invalid_tag_keys.value)})."
          }
          success_msg = ""
          error_msg   = ""
        }
       "update_tag_case" = {
          label        = "Update Tag Case"
          value        = "update_tag_case"
          style        = local.style_ok
          pipeline_ref = pipeline.add_and_remove_tags
          pipeline_args = {
            cred            = param.cred 
            region          = param.region
            arn             = param.arn
            add_tags        = step.transform.build_new_tags.value
            remove_tag_keys = step.transform.get_invalid_tag_keys.value
          }
          success_msg = "Updated tag casing on ${param.title}."
          error_msg   = "Error updating tag casing on ${param.title}."
        }
      }
    }
  }
}

variable "s3_buckets_with_incorrect_tag_key_casing_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "s3_buckets_with_incorrect_tag_key_casing_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "s3_buckets_with_incorrect_tag_key_casing_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "s3_buckets_with_incorrect_tag_key_casing_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "update_tag_case"]
}