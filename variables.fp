variable "approvers" {
  type        = list(notifier)
  description = "List of notifiers to be used for obtaining action/approval decisions, when empty list will perform the default response associated with the detection."
  default     = [notifier.default]
}

variable "notifier" {
  type        = notifier
  description = "The notifier to use for sending notification messages."
  default     = notifier.default
}

variable "notification_level" {
  type        = string
  description = "The verbosity level of notification messages to send. Valid options are 'verbose', 'info', 'error'."
  default     = "info"
}

variable "database" {
  type        = connection.steampipe
  description = "Steampipe database connection string."
  default     = connection.steampipe.default

  tags = {
    folder = "Advanced"
  }
}

variable "max_concurrency" {
  type        = number
  description = "The maximum concurrency to use for responding to detection items."
  default     = 1

  tags = {
    folder = "Advanced"
  }
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
