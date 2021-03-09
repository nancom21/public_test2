locals {
  bucket_name             = "origin-s3-bucket-${random_pet.this.id}"
  destination_bucket_name = "replica-s3-bucket-${random_pet.this.id}"
  origin_region           = "eu-west-1"
  replica_region          = "eu-central-1"
}

provider "aws" {
  region = local.origin_region
}

provider "aws" {
  region = local.replica_region

  alias = "replica"
}

data "aws_caller_identity" "current" {}

resource "random_pet" "this" {
  length = 2
}

resource "aws_kms_key" "replica" {
  provider = "aws.replica"

  description             = "S3 bucket replication KMS key"
  deletion_window_in_days = 7
}

module "replica_bucket" {
  source = "../../"

  providers = {
    aws = "aws.replica"
  }

  bucket = local.destination_bucket_name
  region = local.replica_region
  acl    = "private"

  versioning = {
    enabled = true
  }
}

module "s3_bucket" {
  source = "../../"

  bucket = local.bucket_name
  region = local.origin_region
  acl    = "private"

  versioning = {
    enabled = true
  }

  replication_configuration = {
    role = aws_iam_role.replication.arn

    rules = [
      {
        id       = "foo"
        status   = "Enabled"
        priority = 10

        source_selection_criteria = {
          sse_kms_encrypted_objects = {
            enabled = true
          }
        }

        filter = {
          prefix = "one"
          tags = {
            ReplicateMe = "Yes"
          }
        }

        destination = {
          bucket             = "arn:aws:s3:::${local.destination_bucket_name}"
          storage_class      = "STANDARD"
          replica_kms_key_id = aws_kms_key.replica.arn
          account_id         = data.aws_caller_identity.current.account_id
          access_control_translation = {
            owner = "Destination"
          }
        }
      },
      {
        id       = "bar"
        status   = "Enabled"
        priority = 20

        destination = {
          bucket        = "arn:aws:s3:::${local.destination_bucket_name}"
          storage_class = "STANDARD"
        }


        filter = {
          prefix = "two"
          tags = {
            ReplicateMe = "Yes"
          }
        }

      },

    ]
  }

}
