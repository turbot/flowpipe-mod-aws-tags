locals {
  api_gateway_common_tags = merge(local.aws_tags_common_tags, {
    service = "AWS/APIGateway"
  })
}