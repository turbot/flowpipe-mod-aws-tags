locals {
  s3_buckets_without_standardized_tag_keys_query = replace(
    replace(
      replace(
        local.non_standardized_tags_query, 
        "__TABLE_NAME__", 
        "aws_s3_bucket"
      ),
      "__TITLE__", 
      "concat('S3 Bucket ', r.name, ' [', r.region, '/', r.account_id, ']')"
    ),
    "__TAG_MAPPINGS__", 
    join(" union all ", [for key, values in var.s3_buckets_without_standardized_tag_keys_standardizations : "SELECT '${key}' AS new_key, jsonb_build_array(${join(", ", [for v in values : "'${v}'"])}) AS old_keys"])
  )
}

trigger "query" "detect_and_correct_s3_buckets_without_standardized_tag_keys" {
  title         = "Detect & correct S3 buckets without standardized tag keys"
  description   = "Detects S3 buckets without standardized tag keys and runs your chosen action."
  // documentation = file("./pipelines/s3/docs/detect_and_correct_s3_buckets_without_standardized_tag_keys_trigger.md")
  // tags          = merge(local.s3_common_tags, { class = "" })

  enabled  = var.s3_buckets_without_standardized_tag_keys_trigger_enabled
  schedule = var.s3_buckets_without_standardized_tag_keys_trigger_schedule
  database = var.database
  sql      = local.s3_buckets_without_standardized_tag_keys_query

  capture "insert" {
    pipeline = pipeline.correct_s3_buckets_without_standardized_tag_keys
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_s3_buckets_without_standardized_tag_keys" {
  title         = "Detect & correct S3 buckets without standardized tag keys"
  description   = "Detects S3 buckets without standardized tag keys and runs your chosen action."
  // documentation = file("./pipelines/s3/docs/detect_and_correct_s3_buckets_without_standardized_tag_keys.md")
  // tags          = merge(local.s3_common_tags, { class = "" })

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
    default     = var.s3_buckets_without_standardized_tag_keys_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.s3_buckets_without_standardized_tag_keys_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.s3_buckets_without_standardized_tag_keys_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_s3_buckets_without_standardized_tag_keys
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

pipeline "correct_s3_buckets_without_standardized_tag_keys" {
  title         = "Correct S3 buckets without standardized tag keys"
  description   = "Runs corrective action on a collection of S3 buckets which do not have standardized tag keys."
  // documentation = file("./pipelines/s3/docs/correct_s3_buckets_with_incorrect_tag_key_casing.md")
  // tags          = merge(local.s3_common_tags, { class = "" })

  param "items" {
    type = list(object({
      title            = string
      arn              = string
      region           = string
      cred             = string
      invalid_tag_keys = list(string)
      replacement_tags = map(string)
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
    default     = var.s3_buckets_without_standardized_tag_keys_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.s3_buckets_without_standardized_tag_keys_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} S3 Buckets without standardized tag keys."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.arn => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_s3_bucket_without_standardized_tag_keys
    args            = {
      title              = each.value.title
      arn                = each.value.arn
      region             = each.value.region
      cred               = each.value.cred
      invalid_tag_keys   = each.value.invalid_tag_keys
      replacement_tags   = each.value.replacement_tags
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_s3_bucket_without_standardized_tag_keys" {
  title         = "Correct one S3 bucket without standardized tag keys"
  description   = "Runs corrective action on a single S3 bucket which does not have standardized tag keys."
  // documentation = file("./pipelines/s3/docs/correct_one_s3_bucket_without_standardized_tag_keys.md")
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

  param "invalid_tag_keys" {
    type        = list(string)
    description = "" // TODO: Add description
  }

  param "replacement_tags" {
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
    default     = var.s3_buckets_without_standardized_tag_keys_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.s3_buckets_without_standardized_tag_keys_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected ${param.title} with non-standardized tag keys: (${join(", ", param.invalid_tag_keys)})."
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
            text     = "Skipped ${param.title} with non-standardized tag keys: (${join(", ", param.invalid_tag_keys)})."
          }
          success_msg = ""
          error_msg   = ""
        }
       "update_tag_keys" = {
          label        = "Update Tag Keys"
          value        = "update_tag_keys"
          style        = local.style_ok
          pipeline_ref = pipeline.add_and_remove_tags
          pipeline_args = {
            cred            = param.cred 
            region          = param.region
            arn             = param.arn
            add_tags        = param.replacement_tags
            remove_tag_keys = param.invalid_tag_keys
          }
          success_msg = "Applied updated tags to ${param.title}."
          error_msg   = "Error applying updated tags to ${param.title}"
        }
      }
    }
  }
}

variable "s3_buckets_without_standardized_tag_keys_standardizations" {
  type = map(list(string))
  description = "" // TODO: Add description
  default = {
    "turbot" = ["trbt", "turbit"] // TODO: Implement a better default
    "owner"  = ["ownr", "Owner"]
    "costcenter" = ["cost_center", "CostCenter", "cc", "costcentre"]
  }
}

variable "s3_buckets_without_standardized_tag_keys_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "s3_buckets_without_standardized_tag_keys_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "s3_buckets_without_standardized_tag_keys_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "s3_buckets_without_standardized_tag_keys_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "update_tag_keys"]
}