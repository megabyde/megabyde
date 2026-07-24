# Setting up a GitHub repository

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

### Status checks

```diff
+ Require status checks to pass
```

Typical checks:

- build
- test
- lint

> [!TIP]
>
> Require branches to be up to date before merging if you want a stricter merge queue.

### Conversation requirements

```diff
+ Require conversation resolution before merging
```

### History requirements

```diff
+ Require linear history
```

### Protections

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

```diff
- Allow deletion
- Allow updates
```

## Bootstrap script

> [!IMPORTANT]
>
> Copy [`assets/github-repo-setup/CODEOWNERS.example`](assets/github-repo-setup/CODEOWNERS.example)
> to `.github/CODEOWNERS` in the target repository and replace the placeholder teams.
> Review [`assets/github-repo-setup/ruleset-main.json`](assets/github-repo-setup/ruleset-main.json)
> and [`assets/github-repo-setup/ruleset-tags.json`](assets/github-repo-setup/ruleset-tags.json).
> Change them only if your repository needs different checks or exceptions.

Then run [`assets/github-repo-setup/bootstrap.sh`](assets/github-repo-setup/bootstrap.sh). It
applies the repository settings and both rulesets in one pass. The script resolves its JSON inputs
relative to its own location, so you can invoke it from anywhere. Commit `CODEOWNERS` separately;
the script does not copy it into the target repository.

```bash
./assets/github-repo-setup/bootstrap.sh OWNER/REPO
```
