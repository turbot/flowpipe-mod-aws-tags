locals {
  aws_tags_common_tags = {
    category = "Tags"
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
  description_invalid_tags     = "The tags which are invalid and in need of remediation."
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

locals {
  prohibited_tags_query = <<-EOQ
    select
      __TITLE__ as title,
      arn,
      region,
      _ctx ->> 'connection_name' as cred,
      json_agg(keys) as prohibited_tags
    from
      __TABLE_NAME__,
      jsonb_object_keys(tags) as keys
    where
      lower(keys) = any (array[__PROHIBITED_TAGS__])
    group by arn, region, cred, __ADDITIONAL_GROUP_BY__
  EOQ

  mandatory_tags_query = <<-EOQ
    select
      __TITLE__ as title,
      arn,
      region,
      _ctx ->> 'connection_name' as cred,
      to_jsonb(array[__MANDATORY_TAGS__]) - array(select jsonb_object_keys(tags)) as missing_tags
    from
      __TABLE_NAME__
    where
      coalesce(tags ?& array[__MANDATORY_TAGS__], false) = false
  EOQ

  # Can swap the invalid tags column with jsonb_agg(jsonb_build_object(key, value)) as invalid_tags if we require a list of tags individually
  incorrect_tag_key_casing_query = <<-EOQ
    with tag_details as (
      select
        __TITLE__ as title,
        arn,
        region,
        tags,
        jsonb_object_keys(tags) as key,
        _ctx ->> 'connection_name' as cred
      from
        __TABLE_NAME__
    ),
    filtered_tags as (
      select
        title,
        arn,
        region,
        key,
        tags -> key as value,
        cred
      from tag_details
      where
        key <> __FUNCTION__(key)
        and key not like 'aws:%' -- Exclude AWS-managed tag keys
    )
    select
      title,
      arn,
      region,
      cred,
      jsonb_object_agg(key, value) as invalid_tags
    from filtered_tags
    group by title, arn, region, cred
    having count(key) > 0;
  EOQ

  non_standardized_tags_query = <<-EOQ
    with tag_mappings as (
      __TAG_MAPPINGS__
    ),
    expanded_tags as (
      select
        __TITLE__ as title,
        r.region,
        r.arn,
        r._ctx ->> 'connection_name' as cred,
        r.tags,
        tk.key,
        tk.value,
        tm.new_key
      from
        __TABLE_NAME__ r,
        jsonb_each_text(r.tags) as tk(key, value)
      left join
        tag_mappings tm on tk.key = any(select jsonb_array_elements_text(tm.old_keys))
    )
    select
      e.title,
      e.region,
      e.arn,
      e.cred,
      jsonb_agg(e.key) as invalid_tag_keys,
      jsonb_object_agg(coalesce(e.new_key, e.key), e.value) as replacement_tags
    from
      expanded_tags e
    where
      e.new_key is not null
    group by
      e.title, e.region, e.arn, e.cred;
  EOQ

  misspelled_tag_values_query = <<-EOQ
    with value_mappings as (
      __VALUE_MAPPINGS__
    ),
    expanded_tags as (
      select
        __TITLE__ as title,
        r.region,
        r.arn,
        r._ctx ->> 'connection_name' as cred,
        r.tags,
        tk.key,
        tk.value,
        vm.tag_key,
        vm.new_value
      from
        __TABLE_NAME__ r,
        jsonb_each_text(r.tags) as tk(key, value)
      left join
        value_mappings vm on tk.value = any(select jsonb_array_elements_text(vm.old_values)) and tk.key = vm.tag_key
    )
    select
      e.title,
      e.region,
      e.arn,
      e.cred,
      jsonb_object_agg(e.key, e.value) as incorrect_tags,
      jsonb_object_agg(e.key, e.new_value) as corrected_tags
    from
      expanded_tags e
    where
      e.new_value is not null
    group by
      e.title, e.region, e.arn, e.cred;
  EOQ

  unexpected_tag_values_query = <<-EOQ
    with value_mappings as (
      select 'environment' as tag_key, array['dev%', 'test', 'qa', 'p_od%'] as expected_values, 'development' as default_value
      union all select 'hello' as tag_key, array['b%', 'completed', 'running'] as expected_values, 'bob' as default_value
    ),
    expanded_tags as (
      select
        __TITLE__ as title,
        r.region,
        r.arn,
        r._ctx->>'connection_name' as cred,
        tk.key,
        tk.value,
        vm.tag_key,
        vm.expected_values,
        vm.default_value
      from
        __TABLE_NAME__ r,
        jsonb_each_text(r.tags) as tk(key, value)
      join
        value_mappings vm on tk.key = vm.tag_key
    ),
    filtered_tags as (
      select
        e.title,
        e.region,
        e.arn,
        e.cred,
        e.key,
        e.value,
        e.default_value,
        (case when not exists (select 1 from unnest(e.expected_values) as ev where e.value like ev or e.value ~ ev) then e.default_value else e.value end) as corrected_value
      from
        expanded_tags e
    )
    select
      ft.title,
      ft.region,
      ft.arn,
      ft.cred,
      jsonb_object_agg(ft.key, ft.value) as invalid_values,
      jsonb_object_agg(ft.key, ft.corrected_value) as corrected_tags
    from
      filtered_tags ft
    where
      ft.corrected_value <> ft.value
    group by
      ft.title, ft.region, ft.arn, ft.cred;
  EOQ
}