trigger "query" "detect_and_correct_codebuild_projects_with_incorrect_tags" {
  title         = "Detect & correct CodeBuild projects with incorrect tags"
  description   = "Detects CodeBuild projects with incorrect tags and optionally attempts to correct them."
  tags          = local.codebuild_common_tags

  enabled  = var.codebuild_projects_with_incorrect_tags_trigger_enabled
  schedule = var.codebuild_projects_with_incorrect_tags_trigger_schedule
  database = var.database
  sql      = local.codebuild_projects_with_incorrect_tags_query

  capture "insert" {
    pipeline = pipeline.correct_resources_with_incorrect_tags
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_codebuild_projects_with_incorrect_tags" {
  title         = "Detect & correct CodeBuild projects with incorrect tags"
  description   = "Detects CodeBuild projects with incorrect tags and optionally attempts to correct them."
  tags          = merge(local.codebuild_common_tags, { recommended = "true" })

  param "database" {
    type        = connection.steampipe
    description = local.description_database
    default     = var.database
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
  }

  step "query" "detect" {
    database = param.database
    sql      = local.codebuild_projects_with_incorrect_tags_query
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

variable "codebuild_projects_tag_rules" {
  type = object({
    add           = optional(map(string))
    remove        = optional(list(string))
    remove_except = optional(list(string))
    update_keys   = optional(map(list(string)))
    update_values = optional(map(map(list(string))))
  })
  description = "CodeBuild Project specific tag rules"
  default     = null
  tags = {
    folder = "Advanced/CodeBuild"
  }
}

variable "codebuild_projects_with_incorrect_tags_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
  tags = {
    folder = "Advanced/CodeBuild"
  }
}

variable "codebuild_projects_with_incorrect_tags_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
  tags = {
    folder = "Advanced/CodeBuild"
  }
}

locals {
  codebuild_projects_tag_rules = {
    add           = merge(local.base_tag_rules.add, try(var.codebuild_projects_tag_rules.add, {}))
    remove        = distinct(concat(local.base_tag_rules.remove , try(var.codebuild_projects_tag_rules.remove, [])))
    remove_except = distinct(concat(local.base_tag_rules.remove_except , try(var.codebuild_projects_tag_rules.remove_except, [])))
    update_keys   = merge(local.base_tag_rules.update_keys, try(var.codebuild_projects_tag_rules.update_keys, {}))
    update_values = merge(local.base_tag_rules.update_values, try(var.codebuild_projects_tag_rules.update_values, {}))
  }
}

locals {
  codebuild_projects_update_keys_override   = join("\n", flatten([for key, patterns in local.codebuild_projects_tag_rules.update_keys : [for pattern in patterns : format("      when key %s '%s' then '%s'", (length(split(":", pattern)) > 1 && contains(local.operators, element(split(":", pattern), 0)) ? element(split(":", pattern), 0) : "="), (length(split(":", pattern)) > 1 && contains(local.operators, element(split(":", pattern), 0)) ? join(":", slice(split(":", pattern), 1, length(split(":", pattern)))) : pattern), key)]]))
  codebuild_projects_remove_override        = join("\n", length(local.codebuild_projects_tag_rules.remove) == 0 ? ["      when new_key like '%' then false"] : [for pattern in local.codebuild_projects_tag_rules.remove : format("      when new_key %s '%s' then true", (length(split(":", pattern)) > 1 && contains(local.operators, element(split(":", pattern), 0)) ? element(split(":", pattern), 0) : "="), (length(split(":", pattern)) > 1 && contains(local.operators, element(split(":", pattern), 0)) ? join(":", slice(split(":", pattern), 1, length(split(":", pattern)))) : pattern))])
  codebuild_projects_remove_except_override = join("\n", length(local.codebuild_projects_tag_rules.remove_except) == 0 ? ["      when new_key like '%' then true"] : flatten([[for key in keys(merge(local.codebuild_projects_tag_rules.add, local.codebuild_projects_tag_rules.update_keys)) : format("      when new_key = '%s' then true", key)], [for pattern in local.codebuild_projects_tag_rules.remove_except : format("      when new_key %s '%s' then true", (length(split(":", pattern)) > 1 && contains(local.operators, element(split(":", pattern), 0)) ? element(split(":", pattern), 0) : "="), (length(split(":", pattern)) > 1 && contains(local.operators, element(split(":", pattern), 0)) ? join(":", slice(split(":", pattern), 1, length(split(":", pattern)))) : pattern))]]))
  codebuild_projects_add_override           = join(",\n", length(keys(local.codebuild_projects_tag_rules.add)) == 0 ? ["      (null, null)"] : [for key, value in local.codebuild_projects_tag_rules.add : format("      ('%s', '%s')", key, value)])
  codebuild_projects_update_values_override = join("\n", flatten([for key in sort(keys(local.codebuild_projects_tag_rules.update_values)) : [flatten([for new_value, patterns in local.codebuild_projects_tag_rules.update_values[key] : [contains(patterns, "else:") ? [] : [for pattern in patterns : format("      when new_key = '%s' and value %s '%s' then '%s'", key, (length(split(": ", pattern)) > 1 && contains(local.operators, element(split(": ", pattern), 0)) ? element(split(": ", pattern), 0) : "="), (length(split(": ", pattern)) > 1 && contains(local.operators, element(split(": ", pattern), 0)) ? join(": ", slice(split(": ", pattern), 1, length(split(": ", pattern)))) : pattern), new_value)]]]), contains(flatten([for p in values(local.codebuild_projects_tag_rules.update_values[key]) : p]), "else:") ? [format("      when new_key = '%s' then '%s'", key, [for new_value, patterns in local.codebuild_projects_tag_rules.update_values[key] : new_value if contains(patterns, "else:")][0])] : []]]))
}

locals {
  codebuild_projects_with_incorrect_tags_query = replace(
    replace(
      replace(
        replace(
          replace(
            replace(
              replace(
                local.tags_query_template,
                "__TITLE__", "title"
              ),
              "__TABLE_NAME__", "aws_codebuild_project"
            ),
            "__UPDATE_KEYS_OVERRIDE__", local.codebuild_projects_update_keys_override
          ),
          "__REMOVE_OVERRIDE__", local.codebuild_projects_remove_override
        ),
        "__REMOVE_EXCEPT_OVERRIDE__", local.codebuild_projects_remove_except_override
      ),
      "__ADD_OVERRIDE__", local.codebuild_projects_add_override
    ),
    "__UPDATE_VALUES_OVERRIDE__", local.codebuild_projects_update_values_override
  )
}