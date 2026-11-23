# Canonical task entry point. Requires just >= 1.59.0 and Python >= 3.12 on PATH.
# Script recipes forward argv directly; user paths are never interpolated into code.
set positional-arguments

season := "2026/3. Fall"
archipelago := if os_family() == "windows" { "C:/ProgramData/Archipelago" } else { "" }
input := season + "/YAML"
output := season + "/.secrets/hidden"
export AWEPEEPS_TASK_SEASON := season
export AWEPEEPS_TASK_ARCHIPELAGO := archipelago
export AWEPEEPS_TASK_INPUT := input
export AWEPEEPS_TASK_OUTPUT := output

# List available recipes.
[script('python')]
@default:
    import subprocess
    raise SystemExit(subprocess.call(["just", "--list"]))

# Install the pinned tools and validation/test dependencies.
install: setup

# Lefthook re-stages the fixes (`stage_fixed`).
# Format the given files, or the whole repository when none are given.
fmt *files:
    #!/usr/bin/env bash
    set -euo pipefail
    if (( $# )); then
        bun scripts/format.ts -- "$@"
    else
        bun scripts/format.ts
    fi

# Fail when a file needs formatting.
fmt-check:
    bun scripts/format.ts --check

# No JavaScript or TypeScript linter here; `core-shell` covers a staged script.
# Validator plus workflow lint.
lint *files: validate
    actionlint
    zizmor .github/workflows

# Refuses a global or foreign core.hooksPath; migrates only `.githooks`.
# Enable the shared Lefthook hooks without changing global Git settings.
hooks:
    #!/usr/bin/env bash
    set -euo pipefail

    command -v lefthook >/dev/null || {
        printf 'lefthook is not installed; run `mise install` first.\n' >&2
        exit 1
    }

    global=$(git config --global --get core.hooksPath || true)
    if [[ -n "$global" ]]; then
        printf 'A global core.hooksPath is set (%s); lefthook install refuses it.\n' "$global" >&2
        printf 'Remove it yourself, or use `lefthook install --force` only if you really mean it.\n' >&2
        exit 1
    fi

    existing=$(git config --get core.hooksPath || true)
    case "$existing" in
        ""|.githooks) ;;
        *)
            printf 'core.hooksPath is %s; integrate it manually.\n' "$existing" >&2
            exit 1
            ;;
    esac

    if [[ "$existing" == ".githooks" ]]; then
        git config --unset-all --local core.hooksPath
    fi

    lefthook install
    # A failed remote sync only warns in 2.2.2 and still exits 0, so assert the
    # shared jobs loaded before declaring success.
    dump=$(lefthook dump)
    if ! grep -q 'name: core-' <<<"$dump" || ! grep -q 'name: owner-' <<<"$dump"; then
        printf 'The shared hook config did not load; check access to the awepeeps/.github repository.\n' >&2
        exit 1
    fi
    hookdir=$(git rev-parse --path-format=absolute --git-path hooks)
    if [[ ! -x "$hookdir/pre-commit" || ! -x "$hookdir/pre-push" ]]; then
        printf 'Lefthook did not write the pre-commit and pre-push shims.\n' >&2
        exit 1
    fi
    printf 'Shared Lefthook hooks installed; no global settings changed.\n'

# Fail when .agents/skills and .claude/skills disagree.
agent-files:
    bun scripts/agent-files.ts

# Install validation/test dependencies.
[script('python')]
@setup:
    import os, subprocess, sys
    raise SystemExit(subprocess.call([sys.executable, "-m", "pip", "install", "--disable-pip-version-check", "-r", "requirements-dev.txt"]))

# Validate tracked files and public archives.
[script('python')]
@validate:
    import os, subprocess, sys
    raise SystemExit(subprocess.call([sys.executable, "scripts/validate_repo.py"]))

# Compile the repository scripts.
[script('python')]
@compile:
    import os, subprocess, sys
    raise SystemExit(subprocess.call([sys.executable, "-m", "compileall", "-q", "scripts"]))

# Run the offline script and recipe tests.
[script('python')]
@test *args:
    import os, subprocess, sys
    raise SystemExit(subprocess.call([sys.executable, "-m", "unittest", "discover", "-s", "tests", *sys.argv[1:]]))

# Exercise the real just wrappers using isolated synthetic tools.
[script('python')]
@smoke:
    import os, subprocess, sys
    raise SystemExit(subprocess.call([sys.executable, "-m", "unittest", "discover", "-s", "tests", "-p", "test_just_recipes.py", "-v"]))

# Read-only checkout/config diagnostics.
[script('python')]
@doctor *args:
    import os, subprocess, sys
    raise SystemExit(subprocess.call([sys.executable, "scripts/session_doctor.py", *sys.argv[1:]]))

# Check a private config without displaying values.
[script('python')]
@config-check config *args:
    import os, subprocess, sys
    raise SystemExit(subprocess.call([sys.executable, "scripts/session_doctor.py", "--config-only", "--bot-config", *sys.argv[1:]]))

# Plan closure only; never stop services or mutate a room.
[script('python')]
@close-session run *args:
    import os, subprocess, sys
    raise SystemExit(subprocess.call([sys.executable, "scripts/close_session.py", "--season", os.environ["AWEPEEPS_TASK_SEASON"], "--run", sys.argv[1], "--dry-run", *sys.argv[2:]]))

# Redacted full-history Gitleaks scan (native CLI or --container).
[script('python')]
@secrets *args:
    import os, subprocess, sys
    raise SystemExit(subprocess.call([sys.executable, "scripts/check_secrets.py", *sys.argv[1:]]))

# Staged secret scan; gitleaks never prints a finding value.
[private]
secrets-staged:
    gitleaks git --staged --redact --no-banner

# Reject env files, private keys, kubeconfigs and files over 5 MB.
forbidden-files *files:
    #!/usr/bin/env bash
    set -euo pipefail
    bun scripts/forbidden-files.ts "$@"

# actionlint and zizmor over the given workflows, or every workflow.
workflows *files:
    #!/usr/bin/env bash
    set -euo pipefail
    if (( $# )); then
        actionlint -- "$@"
        zizmor --quiet "$@"
    else
        actionlint
        zizmor --quiet .github/workflows
    fi

# shellcheck over the given scripts; nothing to do when none are given.
shellcheck *files:
    #!/usr/bin/env bash
    set -euo pipefail
    if (( $# )); then
        shellcheck --severity=warning --external-sources -- "$@"
    fi

# Advisory Conventional Commit check (C2.4); never fails the commit.
commit-msg file:
    bun scripts/commit-msg.ts {{ quote(file) }}

# Refuse a push to a protected branch and scan the exact pushed range (C7.10).
[private]
hook-pre-push:
    bun scripts/hook.ts pre-push

# Fast subset for pre-push (C7.10), under 30 seconds.
pre-push-check: fmt-check lint

# Refresh locked dependencies when a manifest changed (post-checkout, post-merge).
deps-refresh:
    bun scripts/deps-refresh.ts mise.toml

# Owner job `owner-public-data`: this is a public repository, so the scan runs.
public-data-staged:
    bun scripts/public-data.ts --staged

# Scaffold/import a season; start with --dry-run.
[script('python')]
@scaffold *args:
    import os, subprocess, sys
    raise SystemExit(subprocess.call([sys.executable, "scripts/scaffold_session.py", *sys.argv[1:]]))

# Compare player YAML settings.
[script('python')]
@compare *args:
    import os, subprocess, sys
    raise SystemExit(subprocess.call([sys.executable, "scripts/compare_player_yaml.py", *sys.argv[1:]]))

# Generate a session; start with --dry-run.
[script('python')]
@generate *args:
    import os, subprocess, sys
    raise SystemExit(subprocess.call([sys.executable, "scripts/generate_session.py", "--season", os.environ["AWEPEEPS_TASK_SEASON"], "--archipelago", os.environ["AWEPEEPS_TASK_ARCHIPELAGO"], "--input", os.environ["AWEPEEPS_TASK_INPUT"], "--output", os.environ["AWEPEEPS_TASK_OUTPUT"], *sys.argv[1:]]))

# Host a generated run; start with --dry-run.
[script('python')]
@host run *args:
    import os, subprocess, sys
    raise SystemExit(subprocess.call([sys.executable, "scripts/host_session_room.py", "--season", os.environ["AWEPEEPS_TASK_SEASON"], "--run", sys.argv[1], *sys.argv[2:]]))

# Publish a saved run; start with --dry-run.
[script('python')]
@publish run *args:
    import os, subprocess, sys
    raise SystemExit(subprocess.call([sys.executable, "scripts/publish_session_artifacts.py", "--season", os.environ["AWEPEEPS_TASK_SEASON"], "--run", sys.argv[1], *sys.argv[2:]]))

# Publish explicit staged artifacts; start with --dry-run.
[script('python')]
@publish-files *args:
    import os, subprocess, sys
    raise SystemExit(subprocess.call([sys.executable, "scripts/publish_session_artifacts.py", "--season", os.environ["AWEPEEPS_TASK_SEASON"], *sys.argv[1:]]))

# Validate, compile, and run all offline tests through the same entry point as CI.
check: fmt-check lint compile test
