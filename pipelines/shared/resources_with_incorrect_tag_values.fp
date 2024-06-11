pipeline "correct_resources_with_incorrect_tag_values" {
  title         = "" // TODO: Add title
  description   = "" // TODO: Add description
  documentation = "" // TODO: Add documentation

  param "items" {
    type = list(object({
      title      = string
      arn        = string
      region     = string
      account_id = string
      cred       = string
      old_values = map(string)
      new_values = map(string)
    }))
    description = local.description_items
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
    default     = var.incorrect_tag_values_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.incorrect_tag_values_enabled_actions
  }

  step "pipeline" "correct_one" {
    for_each = { for row in param.items : row.arn => row }
    max_concurrency = var.max_concurrency
    pipeline = pipeline.correct_one_resource_with_incorrect_tag_values
    args = {
      title              = each.value.title
      arn                = each.value.arn
      region             = each.value.region
      cred               = each.value.cred
      account_id         = each.value.account_id
      old_values         = each.value.old_values
      new_values         = each.value.new_values
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_resource_with_incorrect_tag_values" {
  title         = "" // TODO: Add title
  description   = "" // TODO: Add description
  documentation = "" // TODO: Add documentation

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

  param "account_id" {
    type        = string
    description = local.description_account_id
  }

  param "old_values" {
    type        = map(string)
    description = "" // TODO: Add description
  }

  param "new_values" {
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
    default     = var.incorrect_tag_keys_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.incorrect_tag_keys_enabled_actions
  }

  // TODO: Transform for tag values showing which is replaced with what

  step "transform" "name_display" {
    value = format("%s (%s/%s/%s)", param.title, param.account_id, param.region, param.arn)
  }

  step "pipeline" "correction" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "" // TODO: Add detect message
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
            text     = "Skipped ${param.title} (${param.arn}/${param.arn}) with incorrect tag keys."
          }
          success_msg = ""
          error_msg   = ""
        }
       "apply" = {
          label        = "Apply"
          value        = "apply"
          style        = local.style_ok
          pipeline_ref = local.aws_pipeline_tag_resources
          pipeline_args = {
            cred          = param.cred 
            region        = param.region
            resource_arns = [param.arn]
            tags          = param.new_values
          }
          success_msg = "Applied changes to tag values on ${param.title}."
          error_msg   = "Error applying changes to tag values on ${param.title}."
        }
      }
    }
  }
}