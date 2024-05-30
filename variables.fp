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

variable "tag_key_case" {
  type        = string
  description = "The case to use for tag keys. Valid options are 'lower', 'upper'." // TODO: Should we support other cases?
  default     = "lower"
}

variable "global_prohibited_tag_keys" {
  type        = list(string)
  description = "" // TODO: Add description
  default     = ["password", "secret", "key"] // TODO: Get a better list of default values OR provide no defaults
}

// TODO: Come up with a better way of getting default values for our mandatory tags (should these somehow be dynamic?)
variable "global_mandatory_tags" {
  type        = map(string)
  description = "" // TODO: Add description
  default     = {
    environment = "not set"
    owner       = "not set"
    cost_center = "not set"
    name        = "not set"
  }
}

variable "value_misspellings" {
  type = map(list(object({
    incorrect  = list(string)
    correction = string
  })))
  description = "" // TODO: Add description
  default = { // TODO: Get a better list of default values OR provide no defaults
    "environment" = [{
      incorrect  = ["Development", "Dev", "development"]
      correction = "dev"
    }, {
      incorrect  = ["Production", "Prod", "production"]
      correction = "prod"
    }]
    "HELLO" = [{
      incorrect  = ["World", "WORLD", "w0rld", "W0RLD", "W0rld"]
      correction = "world"
    }]
  }
}

variable "expected_tag_values" {
  type = map(object({
    value_patterns = list(string)
    default_value  = string
  }))
  description = "" // TODO: Add description
  default = {
    "environment" = {
      value_patterns = ["dev%", "test", "qa", "prod%"]
      default_value  = "dev"
    }
    "status" = {
      value_patterns = ["stat%", "completed", "running"]
      default_value  = "unknown"
    }
  }
}