# renovate

Centralised [Renovate](https://docs.renovatebot.com/) configuration presets. Instead of maintaining a full `renovate.json` in every repository, each repo extends the shared presets defined here. Change the policy once, and every consuming repo picks it up.

Built on [`template-base-repo`](https://github.com/jay-withers/template-base-repo), so it also ships a dev container, pre-commit hooks, CI/CD and branch-protection scaffolding.

## Usage

Add a `renovate.json` (or `.github/renovate.json`) to a consuming repo:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["github>jay-withers/renovate"]
}
```

That single line pulls in [`default.json`](default.json), which wires up all the presets below.

## Presets

| Preset | Extend as | What it does |
| --- | --- | --- |
| **default** | `github>jay-withers/renovate` | The recommended everything-included config. Extends every ecosystem preset below plus `config:recommended`, dependency dashboard, semantic commits and sign-off, and enables the `pre-commit` manager. (Does not include **dev-container**, which is opt-in.) |
| **automerge** | `github>jay-withers/renovate:automerge` | Auto-merges every update — including majors — once CI passes. |
| **schedule** | `github>jay-withers/renovate:schedule` | Opens PRs before 6am on Monday to reduce mid-week churn, and keeps open PRs rebased onto the base branch the rest of the week so branch protection's up-to-date requirement cannot strand them. |
| **docker** | `github>jay-withers/renovate:docker` | Pins image digests and groups Docker updates. |
| **github-actions** | `github>jay-withers/renovate:github-actions` | Pins Actions to commit SHAs and groups them. |
| **terraform** | `github>jay-withers/renovate:terraform` | Groups Terraform/Terragrunt providers and modules. |
| **npm** | `github>jay-withers/renovate:npm` | Groups npm dev vs production dependencies and `@types`. |
| **pre-commit** | `github>jay-withers/renovate:pre-commit` | Enables the pre-commit manager and groups all hook updates into one PR (they share `.pre-commit-config.yaml`). |
| **dev-container** | `github>jay-withers/renovate:dev-container` | **Opt-in, not in default.** Custom managers that track binary versions pinned as `ARG *_URL` download links in dev-container image Dockerfiles (tflint, checkov, terraform-docs, pre-commit, gh, node, kubectl, helm, k9s), grouped into one "dev container tools" PR. |

### Picking individual presets

You don't have to take everything. Compose only what you need:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "config:recommended",
    "github>jay-withers/renovate:docker",
    "github>jay-withers/renovate:github-actions"
  ]
}
```

### Overriding

Extend the shared config, then override anything locally — later entries win:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["github>jay-withers/renovate"],
  "schedule": ["at any time"],
  "packageRules": [
    {
      "matchPackageNames": ["react", "react-dom"],
      "automerge": false
    }
  ]
}
```

## Getting started (developing this repo)

1. Open it in the dev container (VS Code: **Reopen in Container**, or GitHub Codespaces). The container runs `make install` on creation to wire up the pre-commit hooks.
2. Outside a dev container, install the hooks manually with `make install`.

## Commands

Run `make` (or `make help`) to list the available targets:

```bash
make install           # install pre-commit hooks (run once after cloning)
make validate          # validate all Renovate presets with renovate-config-validator
make lint              # run all pre-commit hooks against every file
```

Validate presets directly without make:

```bash
npx --yes --package renovate -- renovate-config-validator --strict *.json
```

## Commit messages

Commits must follow [Conventional Commits](https://www.conventionalcommits.org/), enforced by commitlint at commit-msg time. The commit type drives the automatic version bump on merge. Examples:

```text
feat: add terraform preset
fix: correct docker digest grouping
chore: bump pre-commit hooks
```

## CI/CD

Workflows are prefixed `ci-` (pull-request checks) or `cd-` (post-merge delivery):

- **`.github/workflows/ci-lint.yml`** — runs all pre-commit hooks on PRs to `main` via the shared reusable workflow `jay-withers/template-pipelines/.github/workflows/pre-commit.yml`. Status check: `pre-commit / Pre-commit`.
- **`.github/workflows/ci-validate.yml`** — validates every root `*.json` preset with `renovate-config-validator --strict`. Status check: `validate`.
- **`.github/workflows/cd-tag.yml`** — on every merge to `main`, creates a semver tag and matching GitHub release from the Conventional Commits since the last release (default bump: patch), via `jay-withers/template-pipelines/.github/workflows/release.yml`.

## Structure

```text
.devcontainer/
  devcontainer.json    # dev container (ghcr.io/jay-withers/dev-containers/base)
.github/
  workflows/
    ci-lint.yml        # lints all files on PRs to main (reusable workflow)
    ci-validate.yml    # validates Renovate presets on PRs to main
    cd-tag.yml         # auto-tags + releases on merge to main
default.json           # the recommended shared preset (extend this)
automerge.json         # auto-merge policy preset
schedule.json          # update schedule preset
docker.json            # Docker / container preset
github-actions.json    # GitHub Actions preset
terraform.json         # Terraform / Terragrunt preset
npm.json               # Node / npm preset
pre-commit.json        # pre-commit hooks preset
dev-container.json     # dev-container image toolchain preset (opt-in)
renovate.json          # this repo dogfoods its own config
.editorconfig          # baseline editor settings
.gitattributes         # git-level LF normalization
.pre-commit-config.yaml
commitlint.config.js   # commitlint (Conventional Commits) config
CLAUDE.md              # guidance for Claude Code
LICENSE
Makefile
```
