#!/usr/bin/env bash
# verify-assets.sh — publish verifykit proof assets to a hidden git ref that a
# normal `git clone` never fetches (refs/verify-assets/<slug>), then hand back
# SHA-pinned raw URLs that render inline in a GitHub PR body.
#
# Why a hidden ref: assets live in the repo (not a personal gist or the Releases
# tab), yet cost zero clone bloat — `git clone` fetches only refs/heads/* and
# tags, so this namespace and its blobs are never downloaded. Per-slug refs never
# race across parallel worktrees. Publishing uses an isolated index, so the
# working tree and current branch are never touched.
#
# Requires: git, gh (for the API-based rendering check), a PUBLIC origin repo
# (GitHub's image proxy cannot authenticate into a private repo, so inline
# rendering only works when the repo is public).
#
# Usage:
#   verify-assets.sh publish <slug> <file...>   # -> prints the commit SHA to embed
#   verify-assets.sh url     <slug> <sha> <file># -> prints the raw URL for one file
#   verify-assets.sh list                        # -> list all verify-assets refs
#   verify-assets.sh delete  <slug>              # -> delete one hidden ref
#   verify-assets.sh check                       # -> is origin public? (exit 0 = yes)
set -euo pipefail

ns="refs/verify-assets"

# owner/repo from the origin remote, whether SSH or HTTPS
repo_slug() {
  git remote get-url origin \
    | sed -E 's#^git@[^:]+:##; s#^https?://[^/]+/##; s#\.git$##'
}

cmd_check() {
  # exit 0 only when origin is a public GitHub repo (inline rendering works)
  [ "$(gh repo view "$(repo_slug)" --json visibility --jq .visibility 2>/dev/null)" = "PUBLIC" ]
}

cmd_publish() {
  local slug="$1"; shift
  local ref="$ns/$slug"
  local idx; idx="$(mktemp -u)"        # -u: a name only; git creates a fresh index
  export GIT_INDEX_FILE="$idx"

  local f base blob
  for f in "$@"; do
    base="$(basename "$f")"
    blob="$(git hash-object -w "$f")"  # write blob into the object DB
    git update-index --add --cacheinfo "100644,$blob,$slug-$base"
  done

  local tree parent commit
  tree="$(git write-tree)"
  parent="$(git rev-parse --verify --quiet "$ref" || true)"   # accumulate if it exists
  if [ -n "$parent" ]; then
    commit="$(git commit-tree "$tree" -p "$parent" -m "verify: $slug")"
  else
    commit="$(git commit-tree "$tree" -m "verify: $slug")"
  fi
  unset GIT_INDEX_FILE

  git update-ref "$ref" "$commit"
  git push -q origin "$ref:$ref"
  echo "$commit"                       # the SHA the caller embeds in raw URLs
}

cmd_url() {
  local slug="$1" sha="$2" file="$3"
  echo "https://raw.githubusercontent.com/$(repo_slug)/$sha/$slug-$file"
}

cmd_list()   { git ls-remote origin "$ns/*"; }

cmd_delete() {
  local slug="$1"
  git push -q origin ":$ns/$slug"
  git update-ref -d "$ns/$slug" 2>/dev/null || true
}

case "${1:-}" in
  publish) shift; cmd_publish "$@" ;;
  url)     shift; cmd_url "$@" ;;
  list)    cmd_list ;;
  delete)  shift; cmd_delete "$@" ;;
  check)   cmd_check ;;
  *) echo "usage: $0 {publish <slug> <file...>|url <slug> <sha> <file>|list|delete <slug>|check}" >&2; exit 2 ;;
esac
