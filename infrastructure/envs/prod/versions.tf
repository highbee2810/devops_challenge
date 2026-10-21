terraform {
  required_version = ">= 1.10"

  required_providers {
    aws    = { source = "hashicorp/aws", version = ">= 5.60, < 7.0" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }

  # Bucket/region are supplied at init time: terraform init -backend-config=backend.hcl
  backend "s3" {}
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
