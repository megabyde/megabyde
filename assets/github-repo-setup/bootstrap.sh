#!/usr/bin/env bash
set -euo pipefail

REPO=${1:?usage: bootstrap.sh OWNER/REPO}
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

gh repo edit "$REPO" \
    --enable-squash-merge \
    --delete-branch-on-merge

gh repo edit "$REPO" --enable-merge-commit=false
gh repo edit "$REPO" --enable-rebase-merge=false

gh api --method POST "repos/$REPO/rulesets" \
    --input "$SCRIPT_DIR/ruleset-main.json"

gh api --method POST "repos/$REPO/rulesets" \
    --input "$SCRIPT_DIR/ruleset-tags.json"
