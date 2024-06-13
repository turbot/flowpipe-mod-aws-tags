locals {
  iam_roles_with_incorrect_tag_values_query = replace(
    replace(
      replace(
        replace(
          replace(
            local.tag_values_query,
            "__TITLE__", "name"
          ),
          "__TABLE_NAME__", "aws_iam_role"
        ),
        "__UPDATE_OVERRIDES__", join("\n", flatten([for key, rules in var.iam_roles_with_incorrect_tag_values_rules : [for new_value, patterns in rules.update : [for pattern in patterns : format("      when key = '%s' and value %s '%s' then '%s'", key, (length(split(":", pattern)) > 1 && contains(local.operators, element(split(":", pattern), 0)) ? element(split(":", pattern), 0) : "="), (length(split(":", pattern)) > 1 && contains(local.operators, element(split(":", pattern), 0)) ? join(":", slice(split(":", pattern), 1, length(split(":", pattern)))) : pattern), new_value)]]]))
      ),
      "__REMOVE_OVERRIDES__", join("\n", flatten([for key, rules in var.iam_roles_with_incorrect_tag_values_rules : [for pattern in rules.remove : format("      when key = '%s' and updated_value %s '%s' then '%s'", key, (length(split(":", pattern)) > 1 && contains(local.operators, element(split(":", pattern), 0)) ? element(split(":", pattern), 0) : "="), (length(split(":", pattern)) > 1 && contains(local.operators, element(split(":", pattern), 0)) ? join(":", slice(split(":", pattern), 1, length(split(":", pattern)))) : pattern), var.iam_roles_with_incorrect_tag_values_rules[key].default)]]))
    ),
    "__ALLOW_OVERRIDES__", join("\n", flatten([for key, rules in var.iam_roles_with_incorrect_tag_values_rules : concat([for pattern in rules.allow : format("      when key = '%s' and updated_value %s '%s' then updated_value", key, (length(split(":", pattern)) > 1 && contains(local.operators, element(split(":", pattern), 0)) ? element(split(":", pattern), 0) : "="), (length(split(":", pattern)) > 1 && contains(local.operators, element(split(":", pattern), 0)) ? join(":", slice(split(":", pattern), 1, length(split(":", pattern)))) : pattern))], length(rules.allow) > 0 ? [format("      when key = '%s' then '%s'", key, rules.default)] : [])]))
  )
}

trigger "query" "detect_and_correct_iam_roles_with_incorrect_tag_values" {
  title         = "Detect & correct IAM roles with incorrect tag values"
  description   = "" // TODO: Add description
  documentation = "" // TODO: Add documentation
  tags          = merge(local.iam_common_tags, { })

  enabled       = var.iam_roles_with_incorrect_tag_values_trigger_enabled
  schedule      = var.iam_roles_with_incorrect_tag_values_trigger_schedule
  database      = var.database
  sql           = local.iam_roles_with_incorrect_tag_values_query

  capture "insert" {
    pipeline = pipeline.correct_resources_with_incorrect_tag_values
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_iam_roles_with_incorrect_tag_values" {
  title         = "Detect & correct IAM roles with incorrect tag values"
  description   = "" // TODO: Add description
  documentation = "" // TODO: Add documentation
  tags          = merge(local.iam_common_tags, { type = "featured" })

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
    default     = var.incorrect_tag_values_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.incorrect_tag_values_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.iam_roles_with_incorrect_tag_values_query
  }

  step "pipeline" "correct" {
    pipeline = pipeline.correct_resources_with_incorrect_tag_values
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

variable "iam_roles_with_incorrect_tag_values_rules" {
  type = map(object({
    default = string
    allow   = list(string)
    remove  = list(string)
    update  = map(list(string))
  }))
  description = "" // TODO: Add description
}

variable "iam_roles_with_incorrect_tag_values_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "iam_roles_with_incorrect_tag_values_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}