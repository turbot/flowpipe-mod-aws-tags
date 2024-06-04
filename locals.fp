locals {
  aws_tags_common_tags = {
    category = "tags"
    plugin   = "aws"
    service  = "AWS"
  }
}

// Consts
locals {
  level_verbose = "verbose"
  level_info    = "info"
  level_error   = "error"
  style_ok      = "ok"
  style_info    = "info"
  style_alert   = "alert"
}

// Common Texts
locals {
  description_database         = "Database connection string."
  description_approvers        = "List of notifiers to be used for obtaining action/approval decisions."
  description_credential       = "Name of the credential to be used for any authenticated actions."
  description_region           = "AWS Region of the resource(s)."
  description_title            = "Title of the resource, to be used as a display name."
  description_arn              = "The ARN of the resource."
  description_account_id       = "The account ID of the resource."
  description_tags             = "The tags to apply to or remove from the resource."
  description_prohibited_tags  = "Prohibited tag keys to be removed from the resource."
  description_missing_tags     = "The keys of the mandatory tags which haven't been applied to the resource."
  description_max_concurrency  = "The maximum concurrency to use for responding to detection items."
  description_notifier         = "The name of the notifier to use for sending notification messages."
  description_notifier_level   = "The verbosity level of notification messages to send. Valid options are 'verbose', 'info', 'error'."
  description_default_action   = "The default action to use for the detected item, used if no input is provided."
  description_enabled_actions  = "The list of enabled actions to provide to approvers for selection."
  description_trigger_enabled  = "If true, the trigger is enabled."
  description_trigger_schedule = "The schedule on which to run the trigger if enabled."
  description_items            = "A collection of detected resources to run corrective actions against."
}

// Pipeline References
locals {
  pipeline_optional_message    = detect_correct.pipeline.optional_message
  aws_pipeline_tag_resources   = aws.pipeline.tag_resources
  aws_pipeline_untag_resources = aws.pipeline.untag_resources
}
