# Unit test: chạy bằng `terraform test` — KHÔNG cần token, KHÔNG gọi GitHub thật.
# mock_provider giả lập provider github, chỉ kiểm tra logic của plan.

mock_provider "github" {}

variables {
  github_owner = "test-owner"
  repo_name    = "test-repo"
}

run "repo_duoc_cau_hinh_dung" {
  command = plan

  assert {
    condition     = github_repository.my_repo.name == "test-repo"
    error_message = "Tên repo phải lấy từ var.repo_name"
  }
  assert {
    condition     = github_repository.my_repo.auto_init == true
    error_message = "auto_init phải bật để nhánh main được tạo"
  }
  assert {
    condition     = github_repository.my_repo.visibility == "public"
    error_message = "Repo phải là public"
  }
}

run "tao_nhanh_dev_va_stg_tu_main" {
  command = plan

  assert {
    condition     = github_branch.dev_branch.branch == "dev" && github_branch.dev_branch.source_branch == "main"
    error_message = "Nhánh dev phải được tạo từ main"
  }
  assert {
    condition     = github_branch.stg_branch.branch == "stg" && github_branch.stg_branch.source_branch == "main"
    error_message = "Nhánh stg phải được tạo từ main"
  }
}

run "bao_ve_du_3_nhanh" {
  command = plan

  assert {
    condition     = toset(keys(github_branch_protection.protect_branches)) == toset(["main", "dev", "stg"])
    error_message = "Phải bảo vệ đúng 3 nhánh main, dev, stg"
  }
  assert {
    condition = alltrue([
      for p in github_branch_protection.protect_branches :
      p.allows_force_pushes == false && p.allows_deletions == false && p.enforce_admins == true
    ])
    error_message = "Mọi nhánh phải chặn force push, chặn xóa và áp dụng cho cả admin"
  }
  assert {
    condition = alltrue([
      for p in github_branch_protection.protect_branches :
      p.required_pull_request_reviews[0].required_approving_review_count >= 1
    ])
    error_message = "Mọi nhánh phải yêu cầu PR có ít nhất 1 approve"
  }
}

run "tu_choi_ten_repo_sai" {
  command = plan

  variables {
    repo_name = "ten repo co dau cach!"
  }

  expect_failures = [var.repo_name]
}
