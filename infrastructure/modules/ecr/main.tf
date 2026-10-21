variable "name" {
  description = "Repository name"
  type        = string
}

variable "force_delete" {
  description = "Delete the repository even if it still contains images (teardown only)"
  type        = bool
  default     = false
}

variable "keep_last_images" {
  description = "How many images to retain"
  type        = number
  default     = 30
}

resource "aws_ecr_repository" "this" {
  name                 = var.name
  force_delete         = var.force_delete
  image_tag_mutability = "IMMUTABLE" # a tag (git SHA) always maps to exactly one image

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep only the last ${var.keep_last_images} images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = var.keep_last_images
      }
      action = { type = "expire" }
    }]
  })
}

output "repository_url" {
  value = aws_ecr_repository.this.repository_url
}

output "repository_arn" {
  value = aws_ecr_repository.this.arn
}

output "repository_name" {
  value = aws_ecr_repository.this.name
}
