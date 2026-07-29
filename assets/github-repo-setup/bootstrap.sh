#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
    echo "usage: bootstrap.sh OWNER/REPO [CHECK ...]" >&2
    exit 1
fi

REPO=$1
shift

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
MAIN_RULESET=$(mktemp)
TAG_RULESET=$(mktemp)
RULESET_LIST=$(mktemp)
CURRENT_RULESET=$(mktemp)
MERGED_RULESET=$(mktemp)

trap 'rm -f "$MAIN_RULESET" "$TAG_RULESET" "$RULESET_LIST" "$CURRENT_RULESET" "$MERGED_RULESET"' EXIT

export GH_PAGER=cat

command -v gh >/dev/null
command -v jq >/dev/null
gh auth status >/dev/null
gh repo view "$REPO" >/dev/null
gh api "repos/$REPO/rulesets" >"$RULESET_LIST"
OWNER_TYPE=$(gh api "repos/$REPO" --jq .owner.type)

if [ "$OWNER_TYPE" = "User" ]; then
    BYPASS_ACTORS='[{"actor_id":5,"actor_type":"RepositoryRole","bypass_mode":"always"}]'
else
    BYPASS_ACTORS='[{"actor_id":1,"actor_type":"OrganizationAdmin","bypass_mode":"always"}]'
fi

if [ "$#" -gt 0 ]; then
    CHECKS_JSON=$(printf '%s\n' "$@" | jq -R . | jq -s .)

    jq \
        --argjson bypass "$BYPASS_ACTORS" \
        --argjson checks "$CHECKS_JSON" \
        '
        .bypass_actors = $bypass |
        (.rules[] | select(.type == "required_status_checks") | .parameters.required_status_checks) =
        ($checks | map({context: .}))
        ' \
        "$SCRIPT_DIR/ruleset-main.json" >"$MAIN_RULESET"
else
    jq \
        --argjson bypass "$BYPASS_ACTORS" \
        '.bypass_actors = $bypass | del(.rules[] | select(.type == "required_status_checks"))' \
        "$SCRIPT_DIR/ruleset-main.json" >"$MAIN_RULESET"
fi

jq \
    --argjson bypass "$BYPASS_ACTORS" \
    '.bypass_actors = $bypass' \
    "$SCRIPT_DIR/ruleset-tags.json" >"$TAG_RULESET"

gh repo edit "$REPO" \
    --enable-squash-merge \
    --delete-branch-on-merge

gh repo edit "$REPO" --enable-merge-commit=false
gh repo edit "$REPO" --enable-rebase-merge=false

MAIN_RULESET_ID=$(
    jq -r '.[] | select(.name == "Protect main" and .target == "branch") | .id' "$RULESET_LIST" | head -n 1
)

TAG_RULESET_ID=$(
    jq -r '.[] | select(.name == "Protect tags" and .target == "tag") | .id' "$RULESET_LIST" | head -n 1
)

if [ -n "$MAIN_RULESET_ID" ]; then
    gh api "repos/$REPO/rulesets/$MAIN_RULESET_ID" >"$CURRENT_RULESET"
    jq \
        --slurpfile baseline "$MAIN_RULESET" \
        --argjson managed '["deletion","non_fast_forward","pull_request","required_status_checks","required_linear_history"]' \
        '
        .name = $baseline[0].name |
        .target = $baseline[0].target |
        .enforcement = $baseline[0].enforcement |
        .conditions = $baseline[0].conditions |
        .bypass_actors = $baseline[0].bypass_actors |
        .rules = ($baseline[0].rules + [.rules[] | select((.type as $t | $managed | index($t)) | not)]) |
        del(.id, .node_id, .source_type, .source, .created_at, .updated_at, .current_user_can_bypass, ._links)
        ' \
        "$CURRENT_RULESET" >"$MERGED_RULESET"
    mv "$MERGED_RULESET" "$MAIN_RULESET"
    gh api --method PUT "repos/$REPO/rulesets/$MAIN_RULESET_ID" \
        --input "$MAIN_RULESET"
else
    gh api --method POST "repos/$REPO/rulesets" \
        --input "$MAIN_RULESET"
fi

if [ -n "$TAG_RULESET_ID" ]; then
    gh api "repos/$REPO/rulesets/$TAG_RULESET_ID" >"$CURRENT_RULESET"
    jq \
        --slurpfile baseline "$TAG_RULESET" \
        --argjson managed '["deletion","non_fast_forward"]' \
        '
        .name = $baseline[0].name |
        .target = $baseline[0].target |
        .enforcement = $baseline[0].enforcement |
        .conditions = $baseline[0].conditions |
        .bypass_actors = $baseline[0].bypass_actors |
        .rules = ($baseline[0].rules + [.rules[] | select((.type as $t | $managed | index($t)) | not)]) |
        del(.id, .node_id, .source_type, .source, .created_at, .updated_at, .current_user_can_bypass, ._links)
        ' \
        "$CURRENT_RULESET" >"$MERGED_RULESET"
    mv "$MERGED_RULESET" "$TAG_RULESET"
    gh api --method PUT "repos/$REPO/rulesets/$TAG_RULESET_ID" \
        --input "$TAG_RULESET"
else
    gh api --method POST "repos/$REPO/rulesets" \
        --input "$TAG_RULESET"
fi
