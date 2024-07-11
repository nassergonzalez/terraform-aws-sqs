provider "aws" {
  region = local.region
}

data "aws_caller_identity" "current" {}

locals {
  name   = "ex-${basename(path.cwd)}"
  region = "eu-west-1"

  tags = {
    Name       = local.name
    Example    = "complete"
    Repository = "github.com/terraform-aws-modules/terraform-aws-sqs"
  }
}

################################################################################
# SQS Module
################################################################################

module "default_sqs" {
  source = "../../"

  name = "${local.name}-default"

  tags = local.tags
}
