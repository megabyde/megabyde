# Setting up a GitHub repository

## Goals

- No direct pushes to `main`
- All changes go through pull requests
- CI is a required gate
- History is linear and readable
- No stale branches
- Release tags are immutable

> [!NOTE]
> Prefer **Rulesets** over legacy branch protection.

## Configure in the GitHub UI

### 1. Settings -> General -> Pull Requests

#### Merge configuration

- Enable squash merging
- Disable merge commits
- Optionally allow rebase merging
- Enable automatic deletion of head branches

### 2. Settings -> Rules -> Rulesets

Create:

- Target: Branches
- Apply to: `main`

### 3. Merge Strategy

Keep the allowed merge modes aligned with the history policy:

- Enable squash merge
- Disable merge commits
- Optionally disable rebase merge too if you want one merge style only

If you require linear history, allowing merge commits just creates dead settings.

### 4. Pull Request Requirements

```diff
+ Require a pull request before merging
+ Require approvals (1-2)
+ Dismiss stale approvals
+ Require approval of most recent push
```

### 5. Status Checks

```diff
+ Require status checks to pass
```

Typical checks:

- build
- test
- lint

> [!TIP] Require branches to be up to date before merging if you want a stricter merge queue.

### 6. Conversation Requirements

```diff
+ Require conversation resolution before merging
```

### 7. History Requirements

```diff
+ Require linear history
```

### 8. Protections

```diff
- Allow force pushes
- Allow deletions
```

### 9. CODEOWNERS

```text
.github/CODEOWNERS
```

Start from
[`assets/github-repo-setup/CODEOWNERS.example`](assets/github-repo-setup/CODEOWNERS.example) and
replace the placeholder teams.

```diff
+ Require review from Code Owners
```

### 10. Tag Protection

Ruleset:

- Target: Tags
- Apply to: `v*`

```diff
+ Restrict tag creation
- Allow deletion
- Allow updates
```

## Bootstrap Script

> [!IMPORTANT]
> Start by editing [`assets/github-repo-setup/CODEOWNERS.example`](assets/github-repo-setup/CODEOWNERS.example).
> Review [`assets/github-repo-setup/ruleset-main.json`](assets/github-repo-setup/ruleset-main.json)
> and [`assets/github-repo-setup/ruleset-tags.json`](assets/github-repo-setup/ruleset-tags.json),
> and adjust them only if your repository needs different checks or rules.

Then run [`assets/github-repo-setup/bootstrap.sh`](assets/github-repo-setup/bootstrap.sh) to apply
the repository settings and both rulesets in one pass. The script resolves its JSON inputs relative
to its own location, so you can invoke it from anywhere:

```bash
./assets/github-repo-setup/bootstrap.sh OWNER/REPO
```
