variable "iam_roles_tag_rules" {
  type = object({
    add           = optional(map(string))
    remove        = optional(list(string))
    remove_except = optional(list(string))
    update_keys   = optional(map(list(string)))
    update_values = optional(map(map(list(string))))
  })
  description = "" // TODO: Add Description
}

variable "iam_roles_with_incorrect_tags_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "iam_roles_with_incorrect_tags_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

locals {
  iam_roles_tag_rules = {
    add           = merge(local.base_tag_rules.add, try(var.iam_roles_tag_rules.add, {})) 
    remove        = distinct(concat(local.base_tag_rules.remove, try(var.iam_roles_tag_rules.remove, [])))
    remove_except = distinct(concat(local.base_tag_rules.remove_except, try(var.iam_roles_tag_rules.remove_except, [])))
    update_keys   = merge(local.base_tag_rules.update_keys, try(var.iam_roles_tag_rules.update_keys, {}))
    update_values = merge(local.base_tag_rules.update_values, try(var.iam_roles_tag_rules.update_values, {}))
  }
}

locals {
  iam_roles_with_incorrect_tags_query = "" // TODO: Add Query Override
}

trigger "query" "detect_and_correct_iam_roles_with_incorrect_tags" {
  title         = "Detect & correct IAM roles with incorrect tags"
  description   = "" // TODO: Add description
  documentation = "" // TODO: Add documentation
  tags          = merge(local.iam_common_tags, { })

  enabled       = var.iam_roles_with_incorrect_tags_trigger_enabled
  schedule      = var.iam_roles_with_incorrect_tags_trigger_schedule
  database      = var.database
  sql           = local.iam_roles_with_incorrect_tags_query

  capture "insert" {
    pipeline = pipeline.correct_resources_with_incorrect_tags
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_iam_roles_with_incorrect_tags" {
  title         = "Detect & correct IAM roles with incorrect tags"
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
    default     = var.incorrect_tags_default_action
  }

  step "query" "detect" {
    database = param.database
    sql      = local.iam_roles_with_incorrect_tags_query
  }

  step "pipeline" "correct" {
    pipeline = pipeline.correct_resources_with_incorrect_tags
    args = {
      items              = step.query.detect.rows
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
    }
  }
}