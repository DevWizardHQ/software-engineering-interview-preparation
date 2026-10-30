#!/usr/bin/env bash
set -uo pipefail

hook="${1:-}"
protected='^refs/heads/(main|master|dev|develop)$'
ioc="folderOpen|allowAutomaticTasks|global\['(!|_V)'\]|_\\\$_1e42|rmcej%otb%|Cot%3t=shtP|node init &&"
skip=(':(exclude)**/devwizard-checks.sh' ':(exclude).github/workflows/supply-chain-scan.yml')

fail() { echo "devwizard: $*" >&2; exit 1; }

scan_tree() {
  local oid="$1" hits
  hits=$(git grep -lE "$ioc" "$oid" -- . "${skip[@]}" 2>/dev/null | sed "s/^$oid://")
  hits+=$'\n'$(git ls-tree -r --name-only "$oid" | grep -E '\.orc$|^init$')
  git show "$oid:.gitignore" 2>/dev/null | grep -qx 'config.bat' && hits+=$'\n.gitignore: config.bat'
  hits=$(sed '/^$/d' <<<"$hits")
  [[ -z "$hits" ]] || fail "PolinRider indicators in ${oid:0:8}, push blocked:"$'\n'"$hits"
}

pre_commit() {
  local staged
  staged=$(git diff --cached --name-only --diff-filter=ACMR)
  grep -E '(^|/)\.env($|\.)' <<<"$staged" | grep -v '\.env\.example$' && fail "refusing to commit .env files"
  grep -E '\.orc$|^init$' <<<"$staged" && fail "refusing to commit files matching PolinRider indicators"
  git diff --cached -U0 -- . "${skip[@]}" | grep -E '^\+' | grep -qE "$ioc" && fail "staged changes contain PolinRider indicators (folderOpen task, payload signature or 'node init &&')"
  if command -v gitleaks >/dev/null 2>&1; then
    gitleaks git --pre-commit --staged --redact --no-banner >&2 || fail "gitleaks found a secret in staged changes"
  else
    echo "devwizard: gitleaks not installed, secret scan skipped (brew install gitleaks / scoop install gitleaks)" >&2
  fi
}

pre_push() {
  local local_ref local_oid remote_ref remote_oid
  while read -r local_ref local_oid remote_ref remote_oid; do
    [[ -z "$local_ref" ]] && continue
    if [[ "$local_oid" =~ ^0+$ ]]; then
      [[ "$remote_ref" =~ $protected ]] && fail "deleting protected branch $remote_ref is blocked"
      continue
    fi
    scan_tree "$local_oid"
    [[ "$remote_oid" =~ ^0+$ || "${ALLOW_FORCE_PUSH:-}" == "1" ]] && continue
    git merge-base --is-ancestor "$remote_oid" "$local_oid" 2>/dev/null ||
      fail "force push to $remote_ref rewrites history (${remote_oid:0:8} -> ${local_oid:0:8}). Use 'git pull --rebase'. Deliberate feature-branch rewrite: ALLOW_FORCE_PUSH=1 git push --force-with-lease"
  done
}

case "$hook" in
  pre-commit) pre_commit ;;
  pre-push) pre_push ;;
esac
exit 0
