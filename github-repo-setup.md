# Setting up a GitHub repository

_Last verified: 2026-07-23._

The target policy keeps `main` pull-request-only, requires CI, preserves linear history, deletes
merged head branches, and prevents release tags from moving.

## Target policy

- No direct pushes to `main`
- All changes go through pull requests
- CI is a required gate
- History is linear and readable
- Merged head branches are deleted automatically
- Release tags are immutable

> [!NOTE]
>
> Prefer **Rulesets** over legacy branch protection.

## Choose a setup path

- **Bootstrap script (recommended):** review the policy sections below, then run the shipped script
  to apply the repository settings and both rulesets consistently.
- **Manual setup:** follow the settings sections in the GitHub UI when the repository needs a policy
  that the script does not encode.

The sections below define the baseline for both paths. Do not apply both unless you are correcting
or verifying an existing configuration.

## Configure merge policy

In `Settings -> General -> Pull Requests`:

- Enable squash merging
- Disable merge commits
- Optionally allow rebase merging if you want to preserve commit boundaries
- Enable automatic deletion of head branches

The bootstrap script below leaves squash as the only merge mode. Drop the
`--enable-rebase-merge=false` line if you want rebase merges as well.

Keep the allowed merge modes aligned with the history policy. If you require linear history, leaving
merge commits enabled just creates dead settings.

## Create a branch ruleset for `main`

In `Settings -> Rules -> Rulesets`, create a ruleset with:

- Target: Branches
- Apply to: `main`

Then enable the following requirements.

### Pull request requirements

```diff
+ Require a pull request before merging
+ Require approvals (1-2)
+ Dismiss stale approvals
+ Require approval of most recent push
```

> [!WARNING]
>
> GitHub does not let you approve your own pull request. On a repository with one maintainer,
> requiring at least one approval and leaving the bypass list empty means nothing can ever merge
> into `main`. For a solo repository, set the approval count to 0, or add yourself to the ruleset
> bypass list.

### Status checks

```diff
+ Require status checks to pass
```

> [!TIP]
>
> Require branches to be up to date before merging if you want a stricter merge queue. The shipped
> ruleset turns this on through `strict_required_status_checks_policy`.

Typical checks:

- build
- test
- lint

> [!WARNING]
>
> A required check that no workflow reports stays pending forever and blocks the pull request. It
> does not pass by default. Every context you list here must match the name of a check the
> repository actually produces, which for a GitHub Actions job is the job name.

### Conversation requirements

```diff
+ Require conversation resolution before merging
```

### History requirements

```diff
+ Require linear history
```

### Protections

Leave both of these off:

```diff
- Allow force pushes
- Allow deletions
```

## Optionally add `CODEOWNERS`

The baseline ruleset does not require code-owner review. If the repository has stable owners, add:

```text
.github/CODEOWNERS
```

Start from
[`assets/github-repo-setup/CODEOWNERS.example`](assets/github-repo-setup/CODEOWNERS.example) and
replace the placeholder teams. Then change `require_code_owner_review` to `true` in the branch
ruleset.

```diff
+ Require review from Code Owners
```

## Create a tag ruleset

Create a second ruleset with:

- Target: Tags
- Apply to: `v*`

Leave both of these off, which is what makes a published tag immutable:

```diff
- Allow deletion
- Allow updates
```

## Bootstrap script

The script requires repository administration access, `gh`, `jq`, an authenticated GitHub CLI, and
the exact names of any required status checks. Verify the local prerequisites and repository access:

```bash
command -v gh
command -v jq
gh auth status
gh repo view OWNER/REPO
```

All four commands must succeed before continuing. If authentication fails, authenticate `gh` using
your normal credential provider, then rerun `gh auth status`.

> [!IMPORTANT]
>
> The shipped rulesets encode the baseline policy above. Read
> [`assets/github-repo-setup/ruleset-main.json`](assets/github-repo-setup/ruleset-main.json) and
> [`assets/github-repo-setup/ruleset-tags.json`](assets/github-repo-setup/ruleset-tags.json) and
> confirm these points before you run anything:
>
> - Required status checks: pass the exact checks your repository reports as command arguments.
>   Extra names block every pull request. Pass no checks only when CI should not be required.
> - Approval bypass: the script selects repository admins for personal repositories and organization
>   admins for organization repositories. Review this if admins should not bypass the rulesets.
> - Code-owner review: the baseline leaves it off. Enable it only after committing a `CODEOWNERS`
>   file with owners who can actually review.
>
> If you want code owners, copy
> [`assets/github-repo-setup/CODEOWNERS.example`](assets/github-repo-setup/CODEOWNERS.example) to
> `.github/CODEOWNERS` in the target repository and replace the placeholder teams.

Then run [`assets/github-repo-setup/bootstrap.sh`](assets/github-repo-setup/bootstrap.sh). It
applies the repository settings and both rulesets in one pass. The script resolves its JSON inputs
relative to its own location, so you can invoke it from anywhere. It matches existing rulesets by
name, updates them in place, and preserves rules outside this baseline. Commit `CODEOWNERS`
separately; the script does not copy it into the target repository.

```bash
./assets/github-repo-setup/bootstrap.sh OWNER/REPO build test lint

# Or, if status checks should not be required:
./assets/github-repo-setup/bootstrap.sh OWNER/REPO
```

## Verify the setup

Verify the repository merge settings:

```bash
gh api repos/OWNER/REPO \
  --jq '{allow_squash_merge, allow_merge_commit, allow_rebase_merge, delete_branch_on_merge}'
```

The result should be:

```json
{
  "allow_merge_commit": false,
  "allow_rebase_merge": false,
  "allow_squash_merge": true,
  "delete_branch_on_merge": true
}
```

Verify that both rulesets are active:

```bash
gh api repos/OWNER/REPO/rulesets \
  --jq '.[] | select(.name == "Protect main" or .name == "Protect tags") | "\(.name): \(.enforcement)"'
```

The output should contain:

```text
Protect main: active
Protect tags: active
```

Finally, open the `Protect main` ruleset in GitHub and confirm that its required status checks match
the checks produced by the repository workflows. The setup is complete when the merge settings match
the JSON above, both rulesets are active, and every required status check has an exact workflow
check match.

If verification fails, correct the inputs and rerun the script. It updates matching rulesets in
place and preserves rules outside this baseline.
