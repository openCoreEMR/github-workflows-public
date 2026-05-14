# github-workflows-public

Reusable GitHub Actions workflows for the openCoreEMR organization, hosted in a public repo so that public caller repos can use them. (GitHub blocks public repos from calling reusable workflows in private/internal repos.)

Consumers reference workflows here as:

```yaml
uses: opencoreemr/github-workflows-public/.github/workflows/<name>.yml@<ref>
```

## Caller permissions

When invoking these reusable workflows, the **caller** must declare the permissions the workflow needs. Org policy on `openCoreEMR` requires explicit caller-side declarations even when the reusable workflow declares its own internally. Omit them and the job never starts (`startup_failure` with empty logs).

| Workflow | Required caller permissions |
|----------|-----------------------------|
| `actionlint.yml` | `contents: read` |
| `conventional-pr-title.yml` | `pull-requests: read` |
| `dclint.yml` | `contents: read` |
| `hadolint.yml` | `contents: read` |
| `php-composer-script.yml` | `contents: read` |
| `php-tests.yml` | `contents: read` |
| `release-please-reusable.yml` | `contents: write`, `pull-requests: write` |

Example:

```yaml
jobs:
  conventional-pr-title:
    uses: openCoreEMR/github-workflows-public/.github/workflows/conventional-pr-title.yml@<tag>
    permissions:
      pull-requests: read
```

Each reusable's header comment shows the full recommended caller stanza, including the required `permissions:` block.

## Versioning

Releases are managed by [release-please](https://github.com/googleapis/release-please) using the openCoreEMR fork ([release-please-action](https://github.com/openCoreEMR/release-please-action)) which adds annotated-tag support. Conventional commits to `main` automatically open a release PR; merging that PR creates an annotated tag and GitHub release.

Pin to a specific version tag (e.g. `@1.0.0`). Pinning to `@main` works but may break without warning.

## Path filters live in the caller, not the reusable

GitHub evaluates `on: push.paths` and `on: pull_request.paths` *before* the reusable is invoked, so the reusable only sees `workflow_call` and cannot influence whether the workflow runs at all. Always declare an appropriately scoped `paths:` filter in the caller — running every PHP linter on every CSS-only PR wastes both runner minutes and reviewer attention.

Each reusable workflow file has a header comment with the recommended caller stanza (including paths). Copy from there.

Two rules of thumb:

1. **Include `composer.json` in every PHP linter caller.** The linters are invoked through composer scripts (`composer phpstan`, `composer phpcs`, etc.), so a change to `composer.json` can change what runs. For anything that runs `composer install`, also include `composer.lock`.
2. **Don't put a `paths` filter on `tests.yml`.** Tests depend on too many runtime assets (templates, SQL, config, fixtures) to safely enumerate, and missing a real test failure costs more than running tests on a docs-only PR.

And as a general rule, include the caller's own workflow file in the paths so the job re-runs whenever the caller changes.

## Workflows

### `release-please-reusable.yml`

Wraps the openCoreEMR release-please-action fork. Callers provide a `release-please-config.json` (with `"annotated-tag": true` to get annotated tags directly from the action) and a `.release-please-manifest.json`. Outputs include `releases_created`, `release_created`, `tag_name`, `version`, and `paths_released` so caller jobs can `needs:` the release-please job and gate on a release being created.

Inputs:

| Name                   | Type   | Default                          | Description                              |
|------------------------|--------|----------------------------------|------------------------------------------|
| `config-file`          | string | `release-please-config.json`     | Path to the release-please config        |
| `manifest-file`        | string | `.release-please-manifest.json`  | Path to the release-please manifest      |
| `runs-on`              | string | `ubuntu-latest`                  | Runner label                             |
| `checkout-fetch-depth` | number | `0`                              | `fetch-depth` for `actions/checkout`     |

Secrets:

| Name    | Required | Description                                                  |
|---------|----------|--------------------------------------------------------------|
| `token` | no       | Token for checkout and release-please. Falls back to caller's `GITHUB_TOKEN`. |

The pinned action ref (`openCoreEMR/release-please-action@v5.0.0-oce.1`) is hardcoded — GitHub Actions does not allow expressions in `uses:` references, so it can't be a workflow input.
