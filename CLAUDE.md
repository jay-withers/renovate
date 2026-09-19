# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo does

A centralised [Renovate](https://docs.renovatebot.com/) configuration repo. Instead of every repository carrying its own full `renovate.json`, each repo extends the shared presets defined here (`extends: ["github>jay-withers/renovate"]`). Policy — schedule, auto-merge rules, ecosystem grouping — is changed once here and inherited everywhere. The repo also carries the language-agnostic scaffolding it was derived from `jay-withers/template-base-repo` (dev container, pre-commit hooks, CI/CD, branch protection).

## Presets

Each preset is a self-contained JSON file at the repo root, consumed via `github>jay-withers/renovate:<name>` (the bare repo reference loads `default.json`):

- **default.json** — the recommended everything-included config. Extends `config:recommended`, the dependency dashboard, semantic commits, git sign-off, and all the ecosystem presets below except the opt-in **dev-container.json**.
- **automerge.json** — auto-merges every update once CI is green (`platformAutomerge`), including major updates; squash-merges (`automergeStrategy: squash`).
- **schedule.json** — opens pull requests `before 6am on monday`, and keeps the
  open ones rebased the rest of the week (`updateNotScheduled` left at its
  default, `rebaseWhen: behind-base-branch`). The schedule governs *creation*;
  it must not govern rebasing, because branch protection requires an
  up-to-date branch — `updateNotScheduled: false` stranded every open pull
  request behind a moving `main` until the next Monday, with platform
  automerge waiting on a requirement that could never be met.
- **docker.json** — pins image digests, groups Docker updates.
- **github-actions.json** — pins Actions to commit SHAs (`helpers:pinGitHubActionDigests`), groups them.
- **terraform.json** — groups Terraform/Terragrunt providers and modules.
- **npm.json** — groups npm dev vs production dependencies and `@types`.
- **pre-commit.json** — enables the `pre-commit` manager and groups all hook updates into one PR (every hook shares `.pre-commit-config.yaml`, so separate PRs would conflict). Derived repos get frozen-hook updates for free.
- **dev-container.json** — **opt-in, not extended by `default.json`.** Custom `regex` managers that track binary versions pinned as `ARG *_URL="…download/v<currentValue>/…"` links in dev-container image Dockerfiles (`images/{base,terraform,k8s}/Dockerfile`), grouped into one `dev container tools` PR. Consumed by `jay-withers/dev-container`, which extends the bare template plus this preset. Kept out of `default.json` because its file paths and toolset are specific to that repo's layout, not general policy.

Consumers override the shared config by setting options locally after the `extends` — later config wins (scalars replace, `packageRules` concatenate with later rules taking precedence).

`renovate.json` in this repo dogfoods the shared config (`extends: ["local>jay-withers/renovate"]`) plus `autoApprove`.

### Editing presets

- Keep each preset a standalone, valid Renovate config object with a `$schema` and a `description`.
- Validate before pushing: `make validate` (or `npx --yes --package renovate -- renovate-config-validator --strict <files>`).
- Every root-level `*.json` is validated in CI (see below). When you add a new preset file, add a matching row to the README table and the presets list above.
- `renovate-config-validator` does **not** resolve remote `extends` over the network, so `default.json`'s self-references (`github>jay-withers/renovate:...`) validate offline.

## Dev container

Built around `.devcontainer/devcontainer.json` (image `ghcr.io/jay-withers/dev-containers/base:latest`), which runs `make install` on creation to wire up the pre-commit hooks. Prefer working inside the container so tooling versions match CI.

## Commands

`make` with no target prints the self-documenting help (the default goal).

```bash
make install           # install pre-commit hooks (run once after cloning)
make validate          # validate all Renovate presets with renovate-config-validator
make lint              # run all pre-commit hooks against every file
```

## Commit messages

Commits must follow [Conventional Commits](https://www.conventionalcommits.org/) — enforced by commitlint at commit-msg time. Examples: `feat: add terraform preset`, `fix: correct docker digest grouping`, `chore: bump pre-commit hooks`.

## Pre-commit config

Hooks are in `.pre-commit-config.yaml`, pinned by commit SHA with the tag as a frozen comment: `pre-commit/pre-commit-hooks` basics, `gitleaks` (secrets), `actionlint` (workflows), `shellcheck` (shell), and `commitlint` (at the `commit-msg` stage). The Renovate `pre-commit` manager (enabled via `default.json`) keeps these revisions up to date.

## CI

Workflows are prefixed `ci-` (pull-request checks) or `cd-` (post-merge delivery):

- **ci-lint** (`.github/workflows/ci-lint.yml`): runs all linters on PRs to `main` via the reusable workflow `jay-withers/template-pipelines/.github/workflows/pre-commit.yml`. Its status-check context is `pre-commit / Pre-commit` (`<caller job id> / <reusable job name>`).
- **ci-validate** (`.github/workflows/ci-validate.yml`): runs `renovate-config-validator --strict` over every root `*.json` preset on PRs to `main`. Its status-check context is `validate`.
- **cd-tag** (`.github/workflows/cd-tag.yml`): auto-creates a semver tag and matching GitHub release on every merge to `main` from the Conventional Commits since the last release, via `jay-withers/template-pipelines/.github/workflows/release.yml` (default bump: patch).
