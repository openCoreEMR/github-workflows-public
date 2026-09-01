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

Releases are managed by [release-please](https://github.com/googleapis/release-please) using the openCoreEMR fork ([release-please-action](https://github.com/openCoreEMR/release-please-action)), which creates annotated tags by default. Conventional commits to `main` automatically open a release PR; merging that PR creates an annotated tag and GitHub release.

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

Wraps the openCoreEMR release-please-action fork. Callers provide a `release-please-config.json` and a `.release-please-manifest.json`. The action creates annotated tags by default; set `"annotated-tag": false` in the config to opt out and get the lightweight tag the GitHub Releases API creates instead. The reusable workflow does not tag or release anything itself; it only invokes the action. Outputs include `releases_created`, `release_created`, `tag_name`, `version`, and `paths_released` so caller jobs can `needs:` the release-please job and gate on a release being created.

Inputs:

| Name                   | Type   | Default                          | Description                              |
|------------------------|--------|----------------------------------|------------------------------------------|
| `config-file`          | string | `release-please-config.json`     | Path to the release-please config        |
| `manifest-file`        | string | `.release-please-manifest.json`  | Path to the release-please manifest      |
| `runs-on`              | string | `ubuntu-latest`                  | Runner label                             |
| `checkout-fetch-depth` | number | `0`                              | `fetch-depth` for `actions/checkout`     |

Secrets:

| Name              | Required | Description                                                                                                             |
|-------------------|----------|-------------------------------------------------------------------------------------------------------------------------|
| `token`           | no       | Pre-minted token for checkout and release-please. Falls back to App-minted token, then `GITHUB_TOKEN`.                  |
| `app-client-id`   | no       | GitHub App Client ID. Overrides the org-level `RELEASE_PLEASE_CLIENT_ID` variable. Paired with `app-private-key`.       |
| `app-private-key` | no       | GitHub App private key (PEM). Overrides the org-level `RELEASE_PLEASE_PRIVATE_KEY` secret. Paired with `app-client-id`. |

Callers in the `openCoreEMR` org should use `secrets: inherit`. The reusable workflow reads the org variable `RELEASE_PLEASE_CLIENT_ID` (auto-inherited) and the org secret `RELEASE_PLEASE_PRIVATE_KEY` (forwarded by `inherit`), mints a short-lived App installation token, and uses it for checkout and release-please. PRs opened by the App identity trigger downstream `pull_request` workflows; PRs opened by the default `GITHUB_TOKEN` do not (GitHub anti-recursion).

The pinned action ref (`openCoreEMR/release-please-action@v5.0.0-oce.2`) is hardcoded — GitHub Actions does not allow expressions in `uses:` references, so it can't be a workflow input.
