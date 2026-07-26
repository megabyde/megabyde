#!/usr/bin/env bash
set -euo pipefail

REPO=${1:?usage: bootstrap.sh OWNER/REPO}
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

for tool in gh jq; do
    command -v "$tool" >/dev/null || {
        printf 'error: %s is required\n' "$tool" >&2
        exit 1
    }
done

# Rulesets have no natural upsert endpoint, so match on name to stay re-runnable.
apply_ruleset() {
    local input=$1
    local name id

    name=$(jq -r .name "$input")
    id=$(gh api "repos/$REPO/rulesets" --paginate \
        --jq "map(select(.name == \"$name\")) | first | .id // empty")

    if [[ -n $id ]]; then
        gh api --method PUT "repos/$REPO/rulesets/$id" --input "$input"
    else
        gh api --method POST "repos/$REPO/rulesets" --input "$input"
    fi
}

gh repo edit "$REPO" \
    --enable-squash-merge \
    --delete-branch-on-merge

gh repo edit "$REPO" --enable-merge-commit=false
gh repo edit "$REPO" --enable-rebase-merge=false

apply_ruleset "$SCRIPT_DIR/ruleset-main.json"
apply_ruleset "$SCRIPT_DIR/ruleset-tags.json"
