# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo does

A centralised [Renovate](https://docs.renovatebot.com/) configuration repo. Instead of every repository carrying its own full `renovate.json`, each repo extends the shared presets defined here (`extends: ["github>jay-withers/renovate"]`). Policy — schedule, auto-merge rules, ecosystem grouping — is changed once here and inherited everywhere. The repo also carries the language-agnostic scaffolding it was derived from `jay-withers/template-base-repo` (pinned tools in `mise.toml`, pre-commit hooks, CI/CD, branch protection).

## Presets

Each preset is a self-contained JSON file at the repo root, consumed via `github>jay-withers/renovate:<name>` (the bare repo reference loads `default.json`):

- **default.json** — the recommended everything-included config. Extends `config:recommended`, the dependency dashboard, semantic commits, git sign-off, and all the ecosystem presets below.
- **automerge.json** — auto-merges every update once CI is green (`platformAutomerge`), including major updates; squash-merges (`automergeStrategy: squash`). Every update waits `minimumReleaseAge: 3 days` first, and `internalChecksFilter: strict` keeps the PR unopened until then — platform auto-merge does not wait for Renovate's own pending stability check, so a PR opened early could merge early. `jay-withers/**` and `ghcr.io/jay-withers/**` are exempt; security fixes ignore the age by default.
- **schedule.json** — opens pull requests `on monday` (all day: a six-hour
  window was missed entirely by Mend's hosted runs in some repos), and keeps the
  open ones rebased the rest of the week (`updateNotScheduled` left at its
  default, `rebaseWhen: behind-base-branch`). The schedule governs *creation*;
  it must not govern rebasing, because branch protection requires an
  up-to-date branch — `updateNotScheduled: false` stranded every open pull
  request behind a moving `main` until the next Monday, with platform
  automerge waiting on a requirement that could never be met.
- **docker.json** — pins image digests, groups Docker updates, holds Python base-image minors (a new interpreter) for review instead of auto-merging, and always raises dev-containers' `python-app` and `python-app-builder` together in one PR, since an app's venv only runs under the interpreter that built it, and `dotnet-app` with `dotnet-app-builder` the same way (the builder is dotnet-app plus the SDK). Both groups also update `at any time`, outside the Monday window, because their releases are security rebuilds (dev-containers' `cd-patch-check` dispatches one mid-week) that every app's Trivy gate needs promptly.
- **github-actions.json** — pins Actions to commit SHAs
  (`helpers:pinGitHubActionDigests`), groups them, and holds runner labels at
  their current major. That last rule exists because actionlint compiles its
  known-label list in and is released rarely: GitHub shipped `ubuntu-26.04` in
  August 2026 while v1.7.12, from March, was still the newest actionlint, so a
  runner major is a pull request no repository that pins a runner can make
  green. Adopting one needs a `.github/actionlint.yaml` per repo.
- **terraform.json** — groups Terraform/Terragrunt providers and modules, except a minor bump of a 0.x one, which gets its own PR: below 1.0 a minor may break the interface (Key Vault AVM 0.13 did), and grouped it held back every other update with it.
- **npm.json** — Node / npm, for repos that call workflows' `node.yml`. Groups npm dev vs production dependencies and `@types`. A minor or patch of the Dockerfile's `node` image goes in the `mise tools` group, so it moves with mise.toml's `node` (the official image ships within a day of a Node release, so, like Go and unlike Python, they can land together); workflows' `docker.yml` (v1.36.0+) fails `container-build` when their majors differ. Its digest updates deliberately stay in docker.json's digest group: they are OS security rebuilds, and in `mise tools` one failing tool would hold them back. **A Node major is never raised** in mise.toml, the `node` image or `@types/node` (minors and patches are): odd majors never become LTS and even ones only six months after release, so a person moves all three in one PR once the new major is LTS. That rule matches `matchDepNames` (`node` for both the mise and dockerfile managers), scoped to the mise, dockerfile and npm managers; `.nvmrc`, docker-compose and `setup-node` versions are not covered. `package.json`'s `engines.node` (the package's minimum Node, raised by hand like go.mod's `go` line) and `packageManager` (there should be none: `node.yml` runs the npm bundled with mise's Node) are never updated. `package-lock.json`'s transitive dependencies are refreshed by lock-file maintenance, which automerge.json turns on for every manager. Its `mise tools` rule needs npm to stay after `docker` in `default.json`'s `extends`.
- **pre-commit.json** — enables the `pre-commit` manager and groups all hook updates into one PR (every hook shares `.pre-commit-config.yaml`, so separate PRs would conflict). Derived repos get frozen-hook updates for free.
- **mise.json** — enables the `mise` manager and groups every tool update in a repo's `mise.toml` into one `mise tools` PR (all tools share `mise.toml` and `mise.lock`, so separate PRs would conflict). `mise.toml` is where each repo pins its developer and CI toolchain (terraform, tflint, python, uv, ...), replacing `.terraform-version` and the dev-container images. **A Python minor or major in `mise.toml` is never raised** (patches are): CI's interpreter must stay the runtime image's, and workflows' `docker.yml` (v1.35.0+) fails `container-build` when they differ. The dev-containers `python-app` PR that moves the interpreter fails that check, and the fix is to bump `mise.toml`'s `python` in the same PR. Grouping the two instead would have held the python-app group's weekly security rebuilds behind every new CPython minor. That rule matches `matchDepNames`, not `matchPackageNames`: the mise manager looks core tools up under another packageName (Python is `python/cpython`), so a `matchPackageNames: ["python"]` rule silently never fires. Renovate rewrites `mise.lock` only where it may run mise (`allowedUnsafeExecutions` includes `mise`) and the lock already exists. Mend's hosted app does: #90 bumped Python in `mise.toml` and regenerated every platform's URL and checksum in `mise.lock`, so every repo carries a lock. Lock-file maintenance has nothing to do while every tool is pinned exactly, so expect no PR from it. **checkov is held at 3.4.5** (`allowedVersions`): releases since 3.4.6 ship no binaries, so `mise lock` refuses them and the whole grouped PR fails; lift the hold once one ships `checkov_linux_X86_64.zip` again.
- **go.json** — Go modules (`gomod`). Runs `gomodTidy` and `gomodUpdateImportPaths` after updates, groups minor/patch/digest `require` updates into one `go modules` PR (majors stay alone, since a module major changes the import path and the code with it), and disables updates to go.mod's `go` and `toolchain` directives: the `go` line is the module's minimum language version, raised by hand, and there should be no `toolchain` line because workflows' `go.yml` sets `GOTOOLCHAIN=local`, so mise.toml's `go` builds. The Dockerfile's `golang` builder image is put in the `mise tools` group so it always moves with mise.toml's `go` (Go publishes the image the day it tags a release, so, unlike Python, the two can land together). It must stay after `docker` and `mise` in `default.json`'s `extends`, so its `groupName` wins.
- **dotnet.json** — .NET. **The mise manager skips `mise.toml`'s `dotnet`** (`unsupported-datasource`: it has no lookup for core:dotnet), so two regex managers do it: one for `dotnet = "X"` in `mise.toml`, one for the `[[tools.dotnet]]` entry in `mise.lock`, both on the `dotnet-version` datasource (`dotnet-sdk`). They must move together, because CI's `mise install --locked` fails on a version the lock does not list, and a core:dotnet lock entry has no checksums, so a text rewrite of its `version` and `specifiers` (`autoReplaceGlobalMatch`) is the whole update. Both are put in the `mise tools` group. That rule must beat `config:recommended`'s `dotnet monorepo` group, which claims the SDK by its source URL; it does because `default.json` extends `config:recommended` before `dotnet`, and a later rule wins. (Testing locally with `renovate --platform=local`, pass the config as the repo's `renovate.json` and an empty global `RENOVATE_CONFIG_FILE`: a global config's rules sort *before* the repo's `extends`, and the monorepo group then wins, which looks like a broken rule.) **SDK majors are never raised**, and neither are majors of ASP.NET Core, EF Core and its providers, or Microsoft's `mcr.microsoft.com/dotnet/*` images, which all target one runtime: a major moves `TargetFramework`, the SDK and the image runtime together, by hand. The package hold matches by name: since .NET 10 those packages are built from the VMR and their source URL is `github.com/dotnet/dotnet`, shared with every runtime and Microsoft.Extensions package. Microsoft's `aspnet` and `sdk` images (and `runtime`, `runtime-deps`) are grouped into one `dotnet base images` PR, because dev-containers' `dotnet-app-builder` copies the SDK image's runtime onto dotnet-app's and its smoke test fails on two runtimes. Non-major NuGet updates are grouped into one `nuget packages` PR, since each rewrites `packages.lock.json`. Renovate regenerates the lock files with `dotnet restore` on the SDK `mise.toml` pins (the mise manager shares it as the `dotnet` constraint), so repos need no `global.json` `sdk` block. Write the regexes without inline flags such as `(?m)`: without RE2 Renovate falls back to JavaScript's RegExp, which rejects them and fails the whole run with `config-validation`.

Consumers override the shared config by setting options locally after the `extends` — later config wins (scalars replace, `packageRules` concatenate with later rules taking precedence).

`renovate.json` in this repo dogfoods the shared config (`extends: ["local>jay-withers/renovate"]`) plus `autoApprove`.

### Editing presets

- Keep each preset a standalone, valid Renovate config object with a `$schema` and a `description`.
- Validate before pushing: `make validate` (or `npx --yes --package renovate -- renovate-config-validator --strict <files>`).
- Every root-level `*.json` is validated in CI (see below). When you add a new preset file, add a matching row to the README table and the presets list above.
- `renovate-config-validator` does **not** resolve remote `extends` over the network, so `default.json`'s self-references (`github>jay-withers/renovate:...`) validate offline.

## Tools

`mise.toml` pins Python, pre-commit, shellcheck and Node (for `make validate`'s `npx renovate-config-validator`). `make install` runs `mise install`, then wires up the hooks; CI installs the same versions. `mise.lock` records each tool's download URL and checksum for the platforms it lists, and CI's `jdx/mise-action` runs `mise install --locked` whenever one exists, so after editing `mise.toml` by hand run `mise lock` and commit both. Renovate refreshes it in its own mise PRs (see mise.json above). A machine is set up once with jay-withers/toolchain. There is no dev container.

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

- **ci-lint** (`.github/workflows/ci-lint.yml`): runs all linters on PRs to `main` via the reusable workflow `jay-withers/workflows/.github/workflows/pre-commit.yml`. Its status-check context is `pre-commit / Pre-commit` (`<caller job id> / <reusable job name>`).
- **ci-validate** (`.github/workflows/ci-validate.yml`): runs `renovate-config-validator --strict` over every root `*.json` preset on PRs to `main`. Its status-check context is `validate`.
- **cd-tag** (`.github/workflows/cd-tag.yml`): auto-creates a semver tag and matching GitHub release on every merge to `main` from the Conventional Commits since the last release, via `jay-withers/workflows/.github/workflows/release.yml` (default bump: patch).
