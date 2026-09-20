resource "aws_ecr_repository" "app_repo" {
  name = "web-3d-app-repo"
  image_tag_mutability = "MUTABLE" 

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "web-3d-app-repo"
  }
}

resource "aws_ecr_lifecycle_policy" "repo_policy" {
  repository = aws_ecr_repository.app_repo.name

  policy = <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Keep last 5 images",
            "selection": {
                "tagStatus": "any",
                "countType": "imageCountMoreThan",
                "countNumber": 5
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
}