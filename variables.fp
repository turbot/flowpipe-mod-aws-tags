variable "database" {
  type        = string
  description = "Steampipe database connection string."
  default     = "postgres://steampipe@localhost:9193/steampipe"
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
  default     = []
}

variable "max_concurrency" {
  type        = number
  description = "The maximum concurrency to use for responding to detection items."
  default     = 1
}

variable "default_action" {
  type        = string
  description = "The default action to take when no approvers are specified."
  default     = "notify"
}

variable "enabled_actions" {
  type        = list(string)
  description = "List of enabled actions to take when a detection is triggered."
  default     = ["skip", "apply"]

}

// variable "general_key_rules" {
//   type = object({
//     require = map(string) // key with default value
//     allow   = list(string) // pattern matched keys - if set, all other keys to be removed
//     remove  = list(string) // keys to be removed (prohibited keys)
//     update  = map(list(string)) // list is pattern matched keys, key is new key.
//   })
// }

// variable "general_value_rules" {
//   type = map(object({
//     allow  = list(string)
//     remove = list(string)
//     update = map(list(string))
//   }))
// }
