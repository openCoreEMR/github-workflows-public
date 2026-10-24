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
| `opentofu.yml` | `contents: read` |
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

GitHub evaluates `on: push.paths` and `on: pull_request.paths` *before* the reusable is invoked, so the reusable only sees `workflow_call` and cannot influence whether the workflow runs at all. Scope the caller's `push` trigger with an appropriate `paths:` filter — running every PHP linter on every CSS-only push wastes both runner minutes and reviewer attention. Do not put `paths:` on `pull_request` for a check you require: a PR outside the filter skips the workflow, the required check never reports, and the merge stalls pending.

Each reusable workflow file has a header comment with the recommended caller stanza (including paths). Copy from there.

Two rules of thumb:

1. **Include `composer.json` in every PHP linter caller.** The linters are invoked through composer scripts (`composer phpstan`, `composer phpcs`, etc.), so a change to `composer.json` can change what runs. For anything that runs `composer install`, also include `composer.lock`.
2. **Don't put a `paths` filter on `tests.yml`.** Tests depend on too many runtime assets (templates, SQL, config, fixtures) to safely enumerate, and missing a real test failure costs more than running tests on a docs-only PR.

And as a general rule, include the caller's own workflow file in the `push` paths so the job re-runs whenever the caller changes.

## Workflows

### `release-please-reusable.yml`

Wraps the openCoreEMR release-please-action fork. Callers provide a `release-please-config.json` and a `.release-please-manifest.json`. The action creates annotated tags by default; set `"annotated-tag": false` in the config to opt out and get the lightweight tag the GitHub Releases API creates instead. The reusable workflow does not tag or release anything itself; it only invokes the action. Outputs include `releases_created`, `release_created`, `tag_name`, `version`, and `paths_released` so caller jobs can `needs:` the release-please job and gate on a release being created. A sixth output, `release_outputs`, carries the action's entire step-outputs object serialised as JSON, including the per-component keys named `<path>--<key>` (root-package keys are unprefixed) that the outputs above cannot express — in a multi-component manifest setup `paths_released` says *which* paths released, but only `release_outputs` says what tag or version each one got. Parse it with `fromJSON` and index the key you want:

```yaml
jobs:
  release-please:
    uses: openCoreEMR/github-workflows-public/.github/workflows/release-please-reusable.yml@<tag>
    permissions:
      contents: write
      pull-requests: write
    secrets: inherit

  deploy-web:
    needs: release-please
    if: ${{ fromJSON(needs.release-please.outputs.release_outputs)['apps/web--release_created'] == 'true' }}
    uses: ./.github/workflows/deploy.yml
    with:
      release_tag: ${{ fromJSON(needs.release-please.outputs.release_outputs)['apps/web--tag_name'] }}
```

`release_outputs` is always a parseable JSON object, even on a push that released nothing. Beyond the named outputs above it carries, for example, `prs_created`, `pr` and `prs`, and per released path `sha`, `html_url`, `upload_url`, `major`/`minor`/`patch` and `body` (the full release notes text). That list is illustrative, not exhaustive — the full key set is whatever the pinned action's `outputReleases()` and `outputPRs()` emit, so it can change when the action ref is bumped. `body` makes the blob large, and all of a job's outputs together must fit GitHub's 1 MB per-job output limit (50 MB across a whole workflow run), so prefer the named outputs above when they already answer the question.

Treat `body`, `pr`, `prs` and `name` as untrusted text: they come from commit messages and PR titles. Pass them to a script through `env:` — never interpolate them directly into a `run:` block.

The job runs in a repo-wide `release-please-reusable` concurrency group with `queue: max` and without `cancel-in-progress`, so overlapping pushes (a burst of merges, or a single push GitHub delivers twice) wait their turn instead of racing to update the release PR branch. Each queued run reads the branch's current HEAD, so a run that starts after its commit has been overtaken finds nothing left to do. The job times out after 30 minutes so a hung run cannot hold the group indefinitely. Don't declare a concurrency group of the same name in the caller; caller and callee would deadlock on it.

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

The pinned action ref (`openCoreEMR/release-please-action@v5.0.0-oce.4`) is hardcoded — GitHub Actions does not allow expressions in `uses:` references, so it can't be a workflow input.

### `opentofu.yml`

Checks an OpenTofu module: a merge-conflict-marker scan, then `tofu fmt -check -recursive`, `tofu init -backend=false`, `tofu validate` and `tofu test`, the last four run in `working-directory`. The conflict-marker step runs `git grep` over every tracked file in the repo, not just `working-directory`, because `tofu fmt` only notices markers in OpenTofu files and a conflicted `.gitignore` or workflow would otherwise pass. It matches only the exact 7-character markers at the start of a line (`<<<<<<<` and `>>>>>>>` followed by a space or end of line, `=======` alone on its line, and the diff3 `|||||||`). Install uses `opentofu/setup-opentofu` with its output wrapper disabled, so `tofu` behaves as the plain binary.

Known limits:

- A line of exactly `=======` (for example a setext Markdown heading underline below a 7-character title) fails the conflict-marker check.
- A guard step fails the run when `working-directory` contains no `.tf`, `.tofu`, `.tf.json` or `.tofu.json` file, because `tofu init`, `validate` and `test` all exit 0 on an empty directory.
- `tofu init` downloads modules even with `-backend=false`, and the workflow has no SSH key or token input, so for now module sources must be fetchable without credentials (public registry or `https://` sources, not private `git@github.com:` ones).

Path filters belong in the caller (see above); the header comment of the workflow has the recommended stanza. Do not put `paths:` on the caller's `pull_request`, or a skipped run leaves a required check missing.

Inputs:

| Name                | Type   | Default         | Description                                                                                                  |
|---------------------|--------|-----------------|--------------------------------------------------------------------------------------------------------------|
| `tofu-version`      | string | `~1.10.0`       | OpenTofu version or semver range, as accepted by setup-opentofu. The default matches `required_version = "~> 1.10.0"`. |
| `working-directory` | string | `.`             | Directory containing the module, relative to the repo root                                                   |
| `runs-on`           | string | `ubuntu-latest` | Runner label                                                                                                 |

This repo tests the workflow with `opentofu-selftest.yml`, which calls it against the mocked fixture module in `tests/opentofu/` (a `mock_provider` test, so no credentials and no real resources) on every PR to `main`. Its `scripts` job also extracts the conflict-marker and OpenTofu-files steps' `run:` blocks from `opentofu.yml` with `yq` and runs them against scratch repos, so a regression in either script fails the PR.
