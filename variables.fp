variable "database" {
  type        = string
  description = "Steampipe database connection string."
  default     = "postgres://steampipe@localhost:9193/steampipe"
  
  tags        = {
    folder = "Advanced/Global"
  }
}

variable "max_concurrency" {
  type        = number
  description = "The maximum concurrency to use for responding to detection items."
  default     = 1

  tags        = {
    folder = "Advanced/Global"
  }
}

variable "notifier" {
  type        = string
  description = "The name of the notifier to use for sending notification messages."
  default     = "default"
}

variable "notification_level" {
  type        = string
  description = "The verbosity level of notification messages to send. Valid options are 'verbose', 'info', 'error'."
  default     = "info"
}

variable "approvers" {
  type        = list(string)
  description = "List of notifiers to be used for obtaining action/approval decisions, when empty list will perform the default response associated with the detection."
  default     = ["default"]
}

variable "incorrect_tags_default_action" {
  type        = string
  description = "The default action to take when no approvers are specified."
  default     = "notify"
}

variable "base_tag_rules" {
  type = object({
    add           = optional(map(string))
    remove        = optional(list(string))
    remove_except = optional(list(string))
    update_keys   = optional(map(list(string)))
    update_values = optional(map(map(list(string))))
  })
  description = "Base rules to apply to resources unless overridden when merged with any provided resource-specific rules."
  default     = {
    add           = {}
    remove        = []
    remove_except = []
    update_keys   = {}
    update_values = {}
  }
}
