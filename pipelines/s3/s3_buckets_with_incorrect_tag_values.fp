locals {
  // s3_buckets_with_incorrect_tag_values_query_update_override = join("\n", flatten([for key, rules in var.s3_buckets_with_incorrect_tag_values_rules : [for new_value, patterns in rules.update : [for pattern in patterns : format("      when key = '%s' and value %s '%s' then '%s'", key, (length(split(":", pattern)) > 1 && contains(local.operators, element(split(":", pattern), 0)) ? element(split(":", pattern), 0) : "="), (length(split(":", pattern)) > 1 && contains(local.operators, element(split(":", pattern), 0)) ? join(":", slice(split(":", pattern), 1, length(split(":", pattern)))) : pattern), new_value)]]]))
  // s3_buckets_with_incorrect_tag_values_query_remove_override = join("\n", flatten([for key, rules in var.s3_buckets_with_incorrect_tag_values_rules : [for pattern in rules.remove : format("      when key = '%s' and updated_value %s '%s' then '%s'", key, (length(split(":", pattern)) > 1 && contains(local.operators, element(split(":", pattern), 0)) ? element(split(":", pattern), 0) : "="), (length(split(":", pattern)) > 1 && contains(local.operators, element(split(":", pattern), 0)) ? join(":", slice(split(":", pattern), 1, length(split(":", pattern)))) : pattern), var.s3_buckets_with_incorrect_tag_values_rules[key].default)]]))
  // s3_buckets_with_incorrect_tag_values_query_allow_override = join("\n", flatten([for key, rules in var.s3_buckets_with_incorrect_tag_values_rules : concat([for pattern in rules.allow : format("      when key = '%s' and updated_value %s '%s' then updated_value", key, (length(split(":", pattern)) > 1 && contains(local.operators, element(split(":", pattern), 0)) ? element(split(":", pattern), 0) : "="), (length(split(":", pattern)) > 1 && contains(local.operators, element(split(":", pattern), 0)) ? join(":", slice(split(":", pattern), 1, length(split(":", pattern)))) : pattern))], length(rules.allow) > 0 ? [format("      when key = '%s' then '%s'", key, rules.default)] : [])]))

  s3_buckets_with_incorrect_tag_values_query = replace(
    replace(
      replace(
        replace(
          replace(
            local.tag_values_query,
            "__TITLE__", "name"
          ),
          "__TABLE_NAME__", "aws_s3_bucket"
        ),
        "__UPDATE_OVERRIDES__", join("\n", flatten([for key, rules in var.s3_buckets_with_incorrect_tag_values_rules : [for new_value, patterns in rules.update : [for pattern in patterns : format("      when key = '%s' and value %s '%s' then '%s'", key, (length(split(":", pattern)) > 1 && contains(local.operators, element(split(":", pattern), 0)) ? element(split(":", pattern), 0) : "="), (length(split(":", pattern)) > 1 && contains(local.operators, element(split(":", pattern), 0)) ? join(":", slice(split(":", pattern), 1, length(split(":", pattern)))) : pattern), new_value)]]]))
      ),
      "__REMOVE_OVERRIDES__", join("\n", flatten([for key, rules in var.s3_buckets_with_incorrect_tag_values_rules : [for pattern in rules.remove : format("      when key = '%s' and updated_value %s '%s' then '%s'", key, (length(split(":", pattern)) > 1 && contains(local.operators, element(split(":", pattern), 0)) ? element(split(":", pattern), 0) : "="), (length(split(":", pattern)) > 1 && contains(local.operators, element(split(":", pattern), 0)) ? join(":", slice(split(":", pattern), 1, length(split(":", pattern)))) : pattern), var.s3_buckets_with_incorrect_tag_values_rules[key].default)]]))
    ),
    "__ALLOW_OVERRIDES__", join("\n", flatten([for key, rules in var.s3_buckets_with_incorrect_tag_values_rules : concat([for pattern in rules.allow : format("      when key = '%s' and updated_value %s '%s' then updated_value", key, (length(split(":", pattern)) > 1 && contains(local.operators, element(split(":", pattern), 0)) ? element(split(":", pattern), 0) : "="), (length(split(":", pattern)) > 1 && contains(local.operators, element(split(":", pattern), 0)) ? join(":", slice(split(":", pattern), 1, length(split(":", pattern)))) : pattern))], length(rules.allow) > 0 ? [format("      when key = '%s' then '%s'", key, rules.default)] : [])]))
  )
}

pipeline "test" {
  step "transform" "debug" {
    value = "irrelevant"
    output "debug" {
      value = local.s3_buckets_with_incorrect_tag_values_query
    }
  }
}

variable "s3_buckets_with_incorrect_tag_values_rules" {
  type = map(object({
    default = string
    allow   = list(string)
    remove  = list(string)
    update  = map(list(string))
  }))
  description = "" // TODO: Add description
}

variable "s3_buckets_with_incorrect_tag_values_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "s3_buckets_with_incorrect_tag_values_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}