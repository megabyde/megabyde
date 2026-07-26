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

## Add `CODEOWNERS`

```text
.github/CODEOWNERS
```

Start from
[`assets/github-repo-setup/CODEOWNERS.example`](assets/github-repo-setup/CODEOWNERS.example) and
replace the placeholder teams.

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

> [!IMPORTANT]
>
> The shipped rulesets encode the team-oriented policy above. Read
> [`assets/github-repo-setup/ruleset-main.json`](assets/github-repo-setup/ruleset-main.json) and
> [`assets/github-repo-setup/ruleset-tags.json`](assets/github-repo-setup/ruleset-tags.json) and
> adjust three things before you run anything:
>
> - `required_status_checks`: replace `build`, `test`, and `lint` with the checks your repository
>   really reports. Extra names block every pull request.
> - `required_approving_review_count` and `bypass_actors`: set the count to 0 or add yourself to the
>   bypass list if you are the only maintainer.
> - `require_code_owner_review`: leave it on only if you are going to commit a `CODEOWNERS` file
>   with owners who can actually review.
>
> If you want code owners, copy
> [`assets/github-repo-setup/CODEOWNERS.example`](assets/github-repo-setup/CODEOWNERS.example) to
> `.github/CODEOWNERS` in the target repository and replace the placeholder teams.

Then run [`assets/github-repo-setup/bootstrap.sh`](assets/github-repo-setup/bootstrap.sh). It
applies the repository settings and both rulesets in one pass. The script resolves its JSON inputs
relative to its own location, so you can invoke it from anywhere. It matches existing rulesets by
name and updates them in place, so re-running it after editing the JSON is safe. Commit `CODEOWNERS`
separately; the script does not copy it into the target repository.

```bash
./assets/github-repo-setup/bootstrap.sh OWNER/REPO
```
