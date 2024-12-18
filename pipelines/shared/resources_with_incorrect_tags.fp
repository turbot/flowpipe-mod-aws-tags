pipeline "correct_resources_with_incorrect_tags" {
  title       = "Correct resources with incorrect tags"
  description = "Corrects resources with incorrect tags"

  param "items" {
    type = list(object({
      title      = string
      arn        = string
      region     = string
      account_id = string
      conn       = string
      remove     = list(string)
      upsert     = map(string)
    }))
    description = local.description_items
  }

  param "notifier" {
    type        = notifier
    description = local.description_notifier
    default     = var.notifier
  }

  param "notification_level" {
    type        = string
    description = local.description_notifier_level
    default     = var.notification_level
    enum        = local.notification_level_enum
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.incorrect_tags_default_action
    enum        = local.incorrect_tags_default_action_enum
  }

  step "pipeline" "correct_one" {
    for_each        = { for row in param.items : row.arn => row }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_resource_with_incorrect_tags
    args = {
      title              = each.value.title
      arn                = each.value.arn
      region             = each.value.region
      conn               = connection.aws[each.value.conn]
      account_id         = each.value.account_id
      remove             = each.value.remove
      upsert             = each.value.upsert
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
    }
  }
}

pipeline "correct_one_resource_with_incorrect_tags" {
  title       = "Correct one resource with incorrect tags"
  description = "Corrects one resource with incorrect tags"

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

  param "conn" {
    type        = connection.aws
    description = local.description_connection
  }

  param "account_id" {
    type        = string
    description = local.description_account_id
  }

  param "remove" {
    type        = list(string)
    description = "List of tag keys to remove from the resource"
  }

  param "upsert" {
    type        = map(string)
    description = "Map of tag keys and values to add or update on the resource"
  }

  param "notifier" {
    type        = notifier
    description = local.description_notifier
    default     = var.notifier
  }

  param "notification_level" {
    type        = string
    description = local.description_notifier_level
    default     = var.notification_level
    enum        = local.notification_level_enum
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.incorrect_tags_default_action
    enum        = local.incorrect_tags_default_action_enum
  }

  step "transform" "remove_keys_display" {
    value = length(param.remove) > 0 ? format(" Tags that will be removed: %s.", join(", ", param.remove)) : ""
  }

  step "transform" "upsert_keys_display" {
    value = length(param.upsert) > 0 ? format(" Tags that will be added or updated: %s.", join(", ", [for key, value in param.upsert : format("%s=%s", key, value)])) : ""
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
      detect_msg         = format("Detected %s with incorrect tags.%s%s", step.transform.name_display.value, step.transform.upsert_keys_display.value, step.transform.remove_keys_display.value)
      default_action     = param.default_action
      enabled_actions    = ["skip", "apply"]
      actions = {
        "skip" = {
          label        = "Skip"
          value        = "skip"
          style        = local.style_info
          pipeline_ref = detect_correct.pipeline.optional_message
          pipeline_args = {
            notifier = param.notifier
            send     = param.notification_level == local.level_verbose
            text     = "Skipped ${param.title} (${param.arn}/${param.arn}) with incorrect tags."
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
            conn   = param.conn
            region = param.region
            arn    = param.arn
            add    = param.upsert
            remove = param.remove
          }
          success_msg = "Applied changes to tags on ${param.title}."
          error_msg   = "Error applying changes to tags on ${param.title}."
        }
      }
    }
  }
}