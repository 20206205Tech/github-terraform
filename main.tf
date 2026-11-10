terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0" # Sử dụng phiên bản mới nhất của GitHub provider
    }
  }
}

# Cấu hình GitHub Provider
# Lưu ý: Token được truyền qua biến môi trường GITHUB_TOKEN (từ secret GH_PAT)
# Các biến được khai báo trong variables.tf
provider "github" {
  owner = var.github_owner
}

# 1. Tạo Repository
resource "github_repository" "my_repo" {
  name        = var.repo_name
  description = "Repository được tạo quản lý bằng Terraform"
  # visibility  = "private" # hoặc "public"
  visibility = "public"
  # Khởi tạo commit đầu tiên (README) để nhánh 'main' được tự động tạo
  auto_init = true
}

# 2. Tạo các nhánh dev và stg từ nhánh main
resource "github_branch" "dev_branch" {
  repository    = github_repository.my_repo.name
  branch        = "dev"
  source_branch = "main"
}

resource "github_branch" "stg_branch" {
  repository    = github_repository.my_repo.name
  branch        = "stg"
  source_branch = "main"
}

# 3. Bật bảo vệ (Branch Protection) chặn push trực tiếp
resource "github_branch_protection" "protect_branches" {
  # Lặp qua các nhánh để áp dụng chung một rule bảo vệ
  for_each = toset(["main", "dev", "stg"])

  repository_id = github_repository.my_repo.node_id
  pattern       = each.key

  # Ngăn chặn force push và xóa nhánh
  allows_force_pushes = false
  allows_deletions    = false
  enforce_admins      = true # Bắt buộc cả Admin cũng phải tuân thủ rule này

  # Yêu cầu phải có Pull Request mới được merge (Chặn direct push)
  required_pull_request_reviews {
    required_approving_review_count = 1 # Cần ít nhất 1 người approve PR
    dismiss_stale_reviews           = true
    restrict_dismissals             = false
  }
}