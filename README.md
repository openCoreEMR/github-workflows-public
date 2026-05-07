# github-workflows-public

Reusable GitHub Actions workflows for the openCoreEMR organization, hosted in a public repo so that public caller repos can use them. (GitHub blocks public repos from calling reusable workflows in private/internal repos.)

Consumers reference workflows here as:

```yaml
uses: opencoreemr/github-workflows-public/.github/workflows/<name>.yml@<ref>
```

## Versioning

Releases are managed by [release-please](https://github.com/googleapis/release-please) using the openCoreEMR fork ([release-please-action](https://github.com/openCoreEMR/release-please-action)) which adds annotated-tag support. Conventional commits to `main` automatically open a release PR; merging that PR creates an annotated tag and GitHub release.

Pin to a specific version tag (e.g. `@1.0.0`). Pinning to `@main` works but may break without warning.

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
