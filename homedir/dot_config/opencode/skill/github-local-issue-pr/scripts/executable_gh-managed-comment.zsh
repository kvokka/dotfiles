#!/usr/bin/env zsh
set -euo pipefail

repo=""
issue=""
marker=""
body_file=""
self_login="${AGENT_GITHUB_LOGIN:-kvokka-agent}"

usage() {
  cat >&2 <<'EOF'
Usage:
  gh-managed-comment.zsh --repo OWNER/REPO --issue NUMBER --marker MARKER --body-file FILE

Creates or updates the latest issue comment by the current agent containing:
  <!-- MARKER -->

The body file should already contain the marker.
EOF
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      repo="$2"; shift 2 ;;
    --issue)
      issue="$2"; shift 2 ;;
    --marker)
      marker="$2"; shift 2 ;;
    --body-file)
      body_file="$2"; shift 2 ;;
    *)
      usage ;;
  esac
done

[[ -n "$repo" && -n "$issue" && -n "$marker" && -n "$body_file" ]] || usage
[[ -f "$body_file" ]] || { echo "Body file not found: $body_file" >&2; exit 1; }

body="$(cat "$body_file")"

if ! grep -qF "<!-- $marker" "$body_file"; then
  echo "Body file must contain marker: <!-- $marker" >&2
  exit 1
fi

comments_json="$(
  gh api --paginate "repos/$repo/issues/$issue/comments"
)"

comment_id="$(
  jq -r \
    --arg self "$self_login" \
    --arg marker "<!-- $marker" \
    '[.[] | select(.user.login == $self and (.body | contains($marker)))] | last | .id // empty' \
    <<<"$comments_json"
)"

if [[ -n "$comment_id" ]]; then
  gh api \
    -X PATCH \
    "repos/$repo/issues/comments/$comment_id" \
    -f "body=$body" \
    --jq '.html_url'
else
  gh issue comment "$issue" \
    -R "$repo" \
    --body-file "$body_file"
fi
