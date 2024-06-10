pipeline "correct_resources_with_incorrect_tag_keys" {
  title         = "" // TODO: Add title
  description   = "" // TODO: Add description
  documentation = "" // TODO: Add documentation
  tags          = merge(local.s3_common_tags, { type = "featured" })

  param "items" {
    type = list(object({
      title      = string
      arn        = string
      region     = string
      account_id = string
      cred       = string
      remove     = list(string)
      add        = map(string)
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
    default     = var.default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.enabled_actions
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.arn => row }
  }

  step "pipeline" "correct_one" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_resource_with_incorrect_tag_keys
    args = {
      title              = each.value.title
      arn                = each.value.arn
      region             = each.value.region
      cred               = each.value.cred
      account_id         = each.value.account_id
      remove             = each.value.remove
      add                = each.value.add
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_resource_with_incorrect_tag_keys" {
  title         = "" // TODO: Add title
  description   = "" // TODO: Add description
  documentation = "" // TODO: Add documentation
  tags          = merge(local.s3_common_tags, { type = "featured" })

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

  param "remove" {
    type        = list(string)
    description = "" // TODO: Add description
  }

  param "add" {
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
    default     = var.default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.enabled_actions
  }

  step "transform" "remove_keys_display" {
    value = length(param.remove) > 0 ? format(" Tag keys that will be removed: %s.", join(", ", param.remove)) : ""
  }

  step "transform" "add_keys_display" {
    value = length(param.add) > 0 ? format(" Tags that will be added: %s.", join(", ", [for key, value in param.add : format("%s=%s", key, value)])) : ""
  }

  step "transform" "name_display" {
    value = format("%s (%s/%s/%s)", param.title, param.account_id, param.region, param.arn)
  }

  step "pipeline" "correction" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = format("Detected %s with incorrect tag keys, below are a list of remediations to apply.%s%s", step.transform.name_display.value, step.transform.add_keys_display.value, step.transform.remove_keys_display.value)
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
          pipeline_ref = pipeline.add_and_remove_resource_tags
          pipeline_args = {
            cred   = param.cred 
            region = param.region
            arn    = param.arn
            add    = param.add
            remove = param.remove
          }
          success_msg = "Removed prohitbited tags from ${param.title}."
          error_msg   = "Error removing prohitbited tags from ${param.title}."
        }
      }
    }
  }
}
