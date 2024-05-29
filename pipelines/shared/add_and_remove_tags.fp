pipeline "add_and_remove_tags" {
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

  param "add_tags" {
    type        = map(string)
    description = "Tags to add to the resource"
  }

  param "remove_tag_keys" {
    type        = list(string)
    description = "Tags to remove from the resource as a list of keys"
  }

  step "pipeline" "add_new_tags" {
    pipeline = local.aws_pipeline_tag_resources
    args     = {
      cred          = param.cred
      region        = param.region
      resource_arns = [param.arn]
      tags          = param.add_tags
    }
  }

  step "pipeline" "remove_old_tags" {
    pipeline = local.aws_pipeline_untag_resources
    args     = {
      cred          = param.cred
      region        = param.region
      resource_arns = [param.arn]
      tag_keys      = param.remove_tag_keys
    }
  }
}