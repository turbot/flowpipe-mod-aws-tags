pipeline "add_and_remove_resource_tags" {
  title         = "Add and remove resource tags"
  description   = "This pipeline wraps the functionality to add and remove tags from a resource." 

  param "arn" {
    type        = string
    description = local.description_arn
  }

  param "region" {
    type        = string
    description = local.description_region
  }

  param "conn" {
    type        = connection.aws
    description = local.description_connection
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
    if       = length(param.add) > 0
    pipeline = aws.pipeline.tag_resources
    args     = {
      conn          = param.conn
      region        = param.region
      resource_arns = [param.arn]
      tags          = param.add
    }
  }

  step "pipeline" "remove" {
    if         = length(param.remove) > 0
    depends_on = [step.pipeline.add_or_update]
    pipeline   = aws.pipeline.untag_resources
    args       = {
      conn          = param.conn
      region        = param.region
      resource_arns = [param.arn]
      tag_keys      = param.remove
    }
  }
}