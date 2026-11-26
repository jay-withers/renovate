# renovate

Centralised [Renovate](https://docs.renovatebot.com/) configuration presets. Instead of maintaining a full `renovate.json` in every repository, each repo extends the shared presets defined here. Change the policy once, and every consuming repo picks it up.

Built on [`template-repo-base`](https://github.com/jay-withers/template-repo-base), so it also ships pinned tools (`mise.toml`), pre-commit hooks, CI/CD and branch-protection scaffolding.

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
| **default** | `github>jay-withers/renovate` | The recommended everything-included config. Extends every preset below plus `config:recommended`, the dependency dashboard, semantic commits, sign-off and stale-PR rebasing. Commits are prefixed `chore(deps):`, PRs get a `dependencies` label plus an ecosystem one (`docker`, `github-actions`, `terraform`, `javascript`, `go`), and Renovate opens at most 4 an hour and 20 at once. |
| **automerge** | `github>jay-withers/renovate:automerge` | Auto-merges every update — including majors — once CI passes and the release is at least 3 days old (`minimumReleaseAge`; this account's own `jay-withers/*` releases and security fixes don't wait). |
| **schedule** | `github>jay-withers/renovate:schedule` | Opens PRs on Mondays (all day, so the hosted app always gets a run in the window) to reduce mid-week churn (dev-containers' python app base images are the exception: docker.json opens those at any time, since they are security rebuilds), and keeps open PRs rebased onto the base branch the rest of the week so branch protection's up-to-date requirement cannot strand them. |
| **docker** | `github>jay-withers/renovate:docker` | Pins image digests and groups Docker updates (digests together, non-major together). A Python base-image minor gets its own PR and is never auto-merged. dev-containers' `python-app` and `python-app-builder` images always move together in one PR, at any time of the week (they are usually security rebuilds). |
| **github-actions** | `github>jay-withers/renovate:github-actions` | Pins Actions to commit SHAs, groups them, and holds runner labels at their current major — actionlint cannot validate a new runner label until it is released with one, so the bump would fail CI in every repo that pins a runner. |
| **terraform** | `github>jay-withers/renovate:terraform` | Groups Terraform/Terragrunt providers and modules, except a minor bump of a 0.x one, which gets its own PR (below 1.0 a minor may break the interface). |
| **npm** | `github>jay-withers/renovate:npm` | Node / npm: groups npm dev vs production dependencies and `@types`, moves the Dockerfile's `node` image minors and patches in the "mise tools" PR with `mise.toml`'s `node` (its digest updates stay in the docker digests group), never raises a Node major on its own (`mise.toml`'s `node`, the `node` image and `@types/node` move together by hand once the new major is LTS), and never touches `package.json`'s `engines.node` or `packageManager`. Lock-file maintenance (on estate-wide in automerge) refreshes `package-lock.json`'s transitive dependencies. |
| **pre-commit** | `github>jay-withers/renovate:pre-commit` | Enables the pre-commit manager and groups all hook updates into one PR (they share `.pre-commit-config.yaml`). |
| **mise** | `github>jay-withers/renovate:mise` | Enables the mise manager and groups every tool update in `mise.toml` (and its `mise.lock`) into one "mise tools" PR. A Python minor or major is never raised on its own: it moves with the `python-app` image, whose PR fails workflows' Python check until `mise.toml` is bumped in it. checkov is held at 3.4.5, since later releases ship no binaries. |
| **go** | `github>jay-withers/renovate:go` | Go modules: runs `go mod tidy` after every update (and rewrites import paths on a module major), groups non-major module updates into one "go modules" PR, never touches go.mod's `go` or `toolchain` directive, and moves the Dockerfile's `golang` builder image in the "mise tools" PR with `mise.toml`'s `go`, so the binary is built with the Go that CI tested. Extended last in `default.json` so its group wins. |

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

1. Set up a machine once with [jay-withers/toolchain](https://github.com/jay-withers/toolchain), which installs [mise](https://mise.jdx.dev).
2. In this repo: `mise trust && make install` (it runs `mise install` first, then wires up the pre-commit hooks).

## Commands

Run `make` (or `make help`) to list the available targets:

```bash
make install           # install mise tools and pre-commit hooks (run once after cloning)
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

Workflows are prefixed `ci-` (pull-request checks) or `cd-` (post-merge delivery). All but `ci-validate` call a shared workflow in [jay-withers/workflows](https://github.com/jay-withers/workflows), pinned by SHA:

- **`.github/workflows/ci-lint.yml`** — runs all pre-commit hooks on PRs to `main` via the shared reusable workflow `jay-withers/workflows/.github/workflows/pre-commit.yml`. Status check: `pre-commit / Pre-commit`.
- **`.github/workflows/ci-validate.yml`** — validates every root `*.json` preset with `renovate-config-validator --strict`. Status check: `validate`.
- **`.github/workflows/ci-codeql.yml`** — CodeQL code scanning of the workflows, on PRs, on `main` and weekly. Results land in Security → Code scanning; the job doesn't fail on findings.
- **`.github/workflows/cd-tag.yml`** — on every merge to `main`, creates a semver tag and matching GitHub release from the Conventional Commits since the last release (default bump: patch), via `jay-withers/workflows/.github/workflows/release.yml`.

## Structure

```text
mise.toml              # pinned tool versions, used locally and in CI
.github/
  workflows/
    ci-lint.yml        # lints all files on PRs to main (reusable workflow)
    ci-validate.yml    # validates Renovate presets on PRs to main
    ci-codeql.yml      # CodeQL over the workflows
    cd-tag.yml         # auto-tags + releases on merge to main
default.json           # the recommended shared preset (extend this)
automerge.json         # auto-merge policy preset
schedule.json          # update schedule preset
docker.json            # Docker / container preset
github-actions.json    # GitHub Actions preset
terraform.json         # Terraform / Terragrunt preset
npm.json               # Node / npm preset
pre-commit.json        # pre-commit hooks preset
mise.json              # mise tools preset
go.json                # Go modules preset
renovate.json          # this repo dogfoods its own config
.editorconfig          # baseline editor settings
.gitattributes         # git-level LF normalization
.pre-commit-config.yaml
commitlint.config.js   # commitlint (Conventional Commits) config
CLAUDE.md              # guidance for Claude Code
LICENSE
Makefile
```
