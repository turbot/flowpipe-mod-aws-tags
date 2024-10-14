mod "aws_tags" {
  title         = "AWS Tags"
  description   = "Run pipelines to detect and correct AWS tags which are missing, prohibited or otherwise unexpected."
  color         = "#FF9900"
  documentation = file("./README.md")
  icon          = "/images/mods/turbot/aws-tags.svg"
  categories    = ["aws", "public cloud", "standard", "tags"]

  opengraph {
    title       = "AWS Tags Mod for Flowpipe"
    description = "Run pipelines to detect and correct AWS tags which are missing, prohibited or otherwise unexpected."
    image       = "/images/mods/turbot/aws-tags-social-graphic.png"
  }

  require {
    mod "github.com/turbot/flowpipe-mod-detect-correct" {
      version = "v1.0.0-rc.0"
    }
    mod "github.com/turbot/flowpipe-mod-aws" {
      version = "v1.0.0-rc.2"
    }
  }
}
