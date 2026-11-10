variable "github_owner" {
  description = "Tổ chức / user sở hữu repo"
  type        = string
  default     = "nghiavip"
}

variable "repo_name" {
  description = "Tên repo cần tạo (bắt buộc)"
  type        = string
  # Không có default => bắt buộc phải truyền vào

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]+$", var.repo_name))
    error_message = "Tên repo chỉ được chứa chữ, số, dấu chấm, gạch ngang và gạch dưới."
  }
}
