#!/usr/bin/env bash
# Integration test: kiểm tra repo THẬT trên GitHub sau khi terraform apply.
# Cần: gh CLI, git, biến GH_TOKEN (PAT), OWNER, REPO.
# Dùng: OWNER=nghiavip REPO=tf-it-123 GH_TOKEN=xxx bash tests/integration/verify.sh
set -uo pipefail

: "${OWNER:?Thiếu OWNER}" "${REPO:?Thiếu REPO}" "${GH_TOKEN:?Thiếu GH_TOKEN}"
FAIL=0
pass() { echo "  ✅ $1"; }
fail() { echo "  ❌ $1"; FAIL=1; }
check() { # check "mô tả" "giá trị thực tế" "giá trị mong đợi"
  if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (thực tế: '$2', mong đợi: '$3')"; fi
}

echo "== Repo $OWNER/$REPO"
check "repo là public" "$(gh api "repos/$OWNER/$REPO" --jq .visibility)" "public"
DEFAULT_BRANCH=$(gh api "repos/$OWNER/$REPO" --jq .default_branch)
check "nhánh mặc định là main" "$DEFAULT_BRANCH" "main"

for b in main dev stg; do
  echo "== Nhánh $b"
  if ! gh api "repos/$OWNER/$REPO/branches/$b" --silent 2>/dev/null; then
    fail "nhánh $b không tồn tại"; continue
  fi
  pass "nhánh $b tồn tại"

  p=$(gh api "repos/$OWNER/$REPO/branches/$b/protection" 2>/dev/null) || { fail "nhánh $b chưa được bảo vệ"; continue; }
  check "chặn force push"      "$(jq -r .allow_force_pushes.enabled <<<"$p")" "false"
  check "chặn xóa nhánh"       "$(jq -r .allow_deletions.enabled <<<"$p")" "false"
  check "áp dụng cả admin"     "$(jq -r .enforce_admins.enabled <<<"$p")" "true"
  check "cần 1 approve"        "$(jq -r .required_pull_request_reviews.required_approving_review_count <<<"$p")" "1"
  check "bỏ approve cũ khi có commit mới" "$(jq -r .required_pull_request_reviews.dismiss_stale_reviews <<<"$p")" "true"
done

# Kiểm tra HÀNH VI thật: push thẳng vào từng nhánh phải bị GitHub từ chối
# Push phải thất bại VÀ lý do phải là bảo vệ nhánh (GH006/GH013),
# không phải lỗi quyền hay mạng — tránh "pass giả".
expect_blocked() { # expect_blocked "mô tả" <tham số git push...>
  local desc=$1; shift
  local out
  if out=$(git push "$@" 2>&1); then
    fail "$desc THÀNH CÔNG — bảo vệ không hoạt động!"
  elif grep -qiE 'GH006|GH013|protected branch' <<<"$out"; then
    pass "$desc bị chặn bởi branch protection"
  else
    fail "$desc thất bại nhưng KHÔNG phải do branch protection:"
    sed 's/^/       /' <<<"$out"
  fi
}

echo "== Thử push trực tiếp (phải bị chặn)"
TMP=$(mktemp -d)
git clone -q "https://x-access-token:${GH_TOKEN}@github.com/$OWNER/$REPO.git" "$TMP/repo"
cd "$TMP/repo"
git config user.email "ci@example.com"; git config user.name "ci"
for b in main dev stg; do
  git checkout -q "$b"
  echo "direct push $(date +%s)" >> direct-push.txt
  git add direct-push.txt && git commit -qm "thử push thẳng vào $b"
  expect_blocked "push thẳng vào $b" origin "$b"
  if [ "$b" = "$DEFAULT_BRANCH" ]; then
    # GitHub luôn cấm xóa nhánh mặc định trước cả khi xét branch protection,
    # nên thử xóa không chứng minh được gì. allow_deletions đã kiểm tra qua API ở trên.
    echo "  ⏭️  bỏ qua thử xóa $b (nhánh mặc định — GitHub luôn cấm xóa)"
  else
    expect_blocked "xóa nhánh $b" origin --delete "$b"
  fi
done
cd / && rm -rf "$TMP"

echo
if [ "$FAIL" -eq 0 ]; then echo "🎉 TẤT CẢ ĐỀU ĐÚNG"; else echo "💥 CÓ LỖI"; fi
exit $FAIL
