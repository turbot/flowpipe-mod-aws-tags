pipeline "add_and_remove_resource_tags" {
  title         = "Add and remove resource tags"
  description   = "" // TODO: Add description

  param "arn" {
    type        = string
    description = local.description_arn
  }

  param "region" {
    type        = string
    description = local.description_region
  }

  param "cred" {
    type        = string
    description = local.description_credential
  }

  param "add" {
    type        = map(string)
    description = "Tags to add to or update on the resource."
  }

  param "remove" {
    type        = list(string)
    description = "Tag keys to remove from the resource."
  }

  step "pipeline" "add_or_update" {
    pipeline = local.aws_pipeline_tag_resources
    args     = {
      cred          = param.cred
      region        = param.region
      resource_arns = [param.arn]
      tags          = param.add
    }
  }

  step "pipeline" "remove" {
    depends_on = [step.pipeline.add_or_update]
    pipeline   = local.aws_pipeline_untag_resources
    args       = {
      cred          = param.cred
      region        = param.region
      resource_arns = [param.arn]
      tag_keys      = param.remove
    }
  }
}