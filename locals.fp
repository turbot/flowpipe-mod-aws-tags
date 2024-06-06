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
  operators = ["~", "~*", "like", "ilike", "!=", "="]

  tag_keys_query = <<-EOQ
with tags as (
  select
    name as title,
    arn,
    region,
    account_id,
    sp_connection_name as cred,
    coalesce(tags, '{}'::jsonb) as tags,
    key,
    value
  from
    __TABLE_NAME__
  left join
    jsonb_each_text(tags) as t(key, value) on true
),
updated_tags as (
  select
    arn,
    key as old_key,
    case
      when false then key
__UPDATE_OVERRIDE__
      else key
    end as new_key,
    value
  from
    tags
  where key is not null and key not like 'aws:%'
),
required_tags as (
  select
    r.arn,
    null as old_key,
    a.key as new_key,
    a.value
  from
    (select distinct arn from __TABLE_NAME__) r
  cross join (
    values
__REQUIRE_OVERRIDE__
  ) as a(key, value)
  where not exists (
    select 1 from updated_tags ut where ut.arn = r.arn and ut.new_key = a.key
  )
),
all_tags as (
  select arn, old_key, new_key, value from updated_tags
  union all
  select arn, old_key, new_key, value from required_tags where new_key is not null
),
allowed_tags as (
  select distinct
    arn,
    new_key
  from (
    select
      arn,
      new_key,
      case
__ALLOW_OVERRIDE__
        else false
      end as allowed
    from all_tags
  ) a
  where allowed = true
),
remove_tags as (
  select distinct arn, key from (
    select
      arn,
      new_key as key,
      case
__REMOVE_OVERRIDE__
        else false
      end   as remove
    from all_tags) r
    where remove = true
  union
  select arn, old_key as key from all_tags where old_key is not null and old_key != new_key
  union
  select arn, new_key as key from all_tags a where not exists (select 1 from allowed_tags at where at.arn = a.arn and at.new_key = a.new_key)
)
select * from (
  select
    t.title,
    t.arn,
    t.region,
    t.account_id,
    t.cred,
    coalesce((select jsonb_agg(key) from remove_tags rt where rt.arn = t.arn), '[]'::jsonb) as remove,
    coalesce((select jsonb_object_agg(at.new_key, at.value) from all_tags at where at.arn = t.arn and at.new_key != coalesce(at.old_key, '') and not exists (
      select 1 from remove_tags rt where rt.arn = at.arn and rt.key = at.new_key
    )), '{}'::jsonb) as add
  from
    tags t
  group by t.title, t.arn, t.region, t.account_id, t.cred
) result
where remove != '[]'::jsonb or add != '{}'::jsonb;
  EOQ
}