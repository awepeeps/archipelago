# Git Workflow

This repository lives in `awepeeps/archipelago` (remote `origin`). Work on a branch in that repository and open a pull request into `main`; `main` is the source of truth. A working branch such as `feature/<topic>` should normally track its matching `origin` branch.

## Inspect first

```sh
git status
git remote -v
git branch -vv
```

An `ahead` or `behind` count is relative to the branch's configured upstream. Changing the upstream changes that comparison only; it does not copy commits between branches.

## Sync a working branch

```sh
git fetch origin
git switch feature/<topic>
git merge origin/main
git push origin feature/<topic>
```

Replace `feature/<topic>` with the actual working branch. Keep the working branch's upstream pointed at its matching remote branch so normal status and push behavior remain clear. Do not set it to `origin/main` merely to hide a behind count.

## GitHub identity

For HTTPS remotes, inspect available GitHub CLI accounts before changing remotes or branch tracking:

```sh
gh auth status
```

Prefer a per-command `GH_TOKEN` selected from an existing authenticated account instead of changing the global active identity. For example, in a POSIX shell, capture `gh auth token --hostname github.com --user <github-account>` directly into a local variable without displaying it, set `GH_TOKEN` only for the intended `gh` command, and `unset` it afterwards. Never echo the token, enable shell tracing (`set -x`), save it to a tracked file, or include it in a command argument or URL. `GH_TOKEN` selects credentials for `gh`; plain `git push` uses Git's credential helper and requires its own account verification.

Use the account that has permission to push to the repository. Global `gh auth switch` and `gh auth setup-git` changes are only appropriate when intentionally requested. Never put passwords, personal access tokens, or credential-manager contents in this repository or in a command copied into documentation. Personal commit email settings are a separate maintainer decision; do not change them as part of account troubleshooting.

## Agent boundary

AI agents may inspect Git state, history, diffs, remotes, and ignore behavior. Staging, commits, pushes, switching branches, and reverts require explicit maintainer request or authorization; existing authorization remains valid within its scope. Destructive cleanup, branch deletion, force pushes, and history rewrites need authorization for that specific action. Preserve feature branches and unrelated work. Run the validator and review the diff before an authorized upload. The bot's distinct mirror/deployment policy is in [Discord bot](discord-bot.md).
