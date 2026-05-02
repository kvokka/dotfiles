#!/usr/bin/env zsh
set -euo pipefail

mkdir -p tmp
cache_file="tmp/github-repo-context.json"

mode="--json"
refresh="false"

for arg in "$@"; do
  case "$arg" in
    --json|--target-repo|--work-repo|--issue-repo|--pr-base-repo|--default-branch|--pr-head-owner)
      mode="$arg"
      ;;
    --refresh)
      refresh="true"
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 2
      ;;
  esac
done

origin_url="$(git remote get-url origin)"

parse_repo() {
  local url="$1"
  local repo=""

  case "$url" in
    git@github.com:*)
      repo="${url#git@github.com:}"
      ;;
    ssh://git@github.com/*)
      repo="${url#ssh://git@github.com/}"
      ;;
    https://github.com/*)
      repo="${url#https://github.com/}"
      ;;
    http://github.com/*)
      repo="${url#http://github.com/}"
      ;;
    *)
      echo "Unsupported GitHub origin URL: $url" >&2
      exit 1
      ;;
  esac

  repo="${repo%.git}"
  echo "$repo"
}

work_repo="$(parse_repo "$origin_url")"

if [[ "$refresh" != "true" && -f "$cache_file" ]]; then
  cached_origin="$(jq -r '.origin_url // empty' "$cache_file")"
  if [[ "$cached_origin" == "$origin_url" ]]; then
    case "$mode" in
      --json) cat "$cache_file" ;;
      --target-repo) jq -r '.target_repo' "$cache_file" ;;
      --work-repo) jq -r '.work_repo' "$cache_file" ;;
      --issue-repo) jq -r '.issue_repo' "$cache_file" ;;
      --pr-base-repo) jq -r '.pr_base_repo' "$cache_file" ;;
      --default-branch) jq -r '.default_branch' "$cache_file" ;;
      --pr-head-owner) jq -r '.pr_head_owner' "$cache_file" ;;
    esac
    exit 0
  fi
fi

repo_json="$(
  gh repo view "$work_repo" \
    --json nameWithOwner,isFork,parent,defaultBranchRef,url,sshUrl
)"

is_fork="$(jq -r '.isFork' <<<"$repo_json")"

target_repo="$(
  jq -r '
    if .isFork == true and .parent != null
    then .parent.nameWithOwner
    else .nameWithOwner
    end
  ' <<<"$repo_json"
)"

default_branch="$(
  jq -r '
    if .isFork == true and .parent != null and .parent.defaultBranchRef != null
    then .parent.defaultBranchRef.name
    else .defaultBranchRef.name
    end
  ' <<<"$repo_json"
)"

work_owner="${work_repo%%/*}"

context="$(
  jq -n \
    --arg origin_url "$origin_url" \
    --arg work_repo "$work_repo" \
    --arg target_repo "$target_repo" \
    --arg issue_repo "$target_repo" \
    --arg pr_base_repo "$target_repo" \
    --arg pr_head_owner "$work_owner" \
    --arg default_branch "$default_branch" \
    --argjson is_fork "$is_fork" \
    --arg cached_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{
      origin_url: $origin_url,
      work_repo: $work_repo,
      target_repo: $target_repo,
      issue_repo: $issue_repo,
      pr_base_repo: $pr_base_repo,
      pr_head_owner: $pr_head_owner,
      default_branch: $default_branch,
      is_fork: $is_fork,
      cached_at: $cached_at
    }'
)"

echo "$context" > "$cache_file"

case "$mode" in
  --json) cat "$cache_file" ;;
  --target-repo) jq -r '.target_repo' "$cache_file" ;;
  --work-repo) jq -r '.work_repo' "$cache_file" ;;
  --issue-repo) jq -r '.issue_repo' "$cache_file" ;;
  --pr-base-repo) jq -r '.pr_base_repo' "$cache_file" ;;
  --default-branch) jq -r '.default_branch' "$cache_file" ;;
  --pr-head-owner) jq -r '.pr_head_owner' "$cache_file" ;;
esac
