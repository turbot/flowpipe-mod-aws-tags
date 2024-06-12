locals {
  iam_roles_with_incorrect_tag_keys_query = replace(
    replace(
      replace(
        replace(
          replace(
            replace(local.tag_keys_query, "__TABLE_NAME__", "aws_iam_role"),
            "__TITLE__", "name"
          ),
          "__UPDATE_OVERRIDE__", join("\n",flatten([for key, patterns in var.iam_roles_with_incorrect_tag_keys_rules.update : [for pattern in patterns : format("      when key %s '%s' then '%s'", (length(split(":", pattern)) > 1 && contains(local.operators, element(split(":", pattern), 0)) ? element(split(":", pattern), 0) : "="), (length(split(":", pattern)) > 1 && contains(local.operators, element(split(":", pattern), 0)) ? join(":", slice(split(":", pattern), 1, length(split(":", pattern)))) : pattern), key)]]))
        ),
        "__ALLOW_OVERRIDE__", join("\n", length(var.iam_roles_with_incorrect_tag_keys_rules.allow) == 0 ? ["      when new_key like '%' then true"] : [for pattern in var.iam_roles_with_incorrect_tag_keys_rules.allow : format("      when new_key %s '%s' then true", (length(split(":", pattern)) > 1 && contains(local.operators, element(split(":", pattern), 0)) ? element(split(":", pattern), 0) : "="), (length(split(":", pattern)) > 1 && contains(local.operators, element(split(":", pattern), 0)) ? join(":", slice(split(":", pattern), 1, length(split(":", pattern)))) : pattern))])
      ),
      "__REMOVE_OVERRIDE__", join("\n", length(var.iam_roles_with_incorrect_tag_keys_rules.remove) == 0 ? ["      when new_key like '%' then false"] : [for pattern in var.iam_roles_with_incorrect_tag_keys_rules.remove : format("      when new_key %s '%s' then true", (length(split(":", pattern)) > 1 && contains(local.operators, element(split(":", pattern), 0)) ? element(split(":", pattern), 0) : "="), (length(split(":", pattern)) > 1 && contains(local.operators, element(split(":", pattern), 0)) ? join(":", slice(split(":", pattern), 1, length(split(":", pattern)))) : pattern))])
    ),
    "__REQUIRE_OVERRIDE__", join(",\n", length(keys(var.iam_roles_with_incorrect_tag_keys_rules.require)) == 0 ? ["      (null, null)"] : [for key, value in var.iam_roles_with_incorrect_tag_keys_rules.require : format("      ('%s', '%s')", key, value)])
  )
}

trigger "query" "detect_and_correct_iam_roles_with_incorrect_tag_keys" {
  title         = "" // TODO: Add title
  description   = "" // TODO: Add description
  documentation = "" // TODO: Add documentation
  tags          = merge(local.s3_common_tags, { })

  enabled       = var.iam_roles_with_incorrect_tag_keys_trigger_enabled
  schedule      = var.iam_roles_with_incorrect_tag_keys_trigger_schedule
  database      = var.database
  sql           = local.iam_roles_with_incorrect_tag_keys_query

  capture "insert" {
    pipeline = pipeline.correct_resources_with_incorrect_tag_keys
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_iam_roles_with_incorrect_tag_keys" {
  title         = "" // TODO: Add title
  description   = "" // TODO: Add description
  documentation = "" // TODO: Add documentation
  tags          = merge(local.s3_common_tags, { type = "featured" })

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
    default     = var.incorrect_tag_keys_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.incorrect_tag_keys_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.iam_roles_with_incorrect_tag_keys_query
  }

  step "pipeline" "correct" {
    pipeline = pipeline.correct_resources_with_incorrect_tag_keys
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

variable "iam_roles_with_incorrect_tag_keys_rules" {
  type = object({
    require = map(string) 
    allow   = list(string)
    remove  = list(string)
    update  = map(list(string))
  })
  description = "" // TODO: Add description
}

variable "iam_roles_with_incorrect_tag_keys_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "iam_roles_with_incorrect_tag_keys_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}