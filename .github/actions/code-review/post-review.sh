#!/usr/bin/env bash
set -euo pipefail

COMMENT_FILE="/tmp/review-comment.md"

if [[ ! -f "$COMMENT_FILE" ]]; then
  echo "Missing review comment file" >&2
  exit 1
fi

MARKER="<!-- ai-code-review:marker -->"
REPO="${GITHUB_REPOSITORY:?}"
PR_NUMBER="${PR_NUMBER:?}"
VERDICT="${VERDICT:-unknown}"

existing_id="$(gh api \
  "repos/${REPO}/issues/${PR_NUMBER}/comments" \
  --jq ".[] | select(.body | contains(\"${MARKER}\")) | .id" \
  | head -1 || true)"

if [[ -n "$existing_id" ]]; then
  gh api \
    --method PATCH \
    "repos/${REPO}/issues/comments/${existing_id}" \
    -f body="$(cat "$COMMENT_FILE")" \
    > /dev/null
else
  gh pr comment "$PR_NUMBER" --body-file "$COMMENT_FILE"
fi

if [[ "$VERDICT" == "pass" ]]; then
  gh pr edit "$PR_NUMBER" --add-label "ai-cr:passed" --remove-label "ai-cr:failed" || true
elif [[ "$VERDICT" == "fail" ]]; then
  gh pr edit "$PR_NUMBER" --add-label "ai-cr:failed" --remove-label "ai-cr:passed" || true
fi

echo "Posted review comment (verdict=${VERDICT})"
