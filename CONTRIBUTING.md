# Contributing

## npm releases

Publishing uses [npm Trusted Publishing](https://docs.npmjs.com/trusted-publishers/) via GitHub Actions (`.github/workflows/publish.yml`, OIDC; no `NPM_TOKEN`).

### Normal release

Push an **annotated semver tag** matching `package.json` (e.g. `v0.7.0`). The workflow checks out that tag, verifies the pack layout, and runs `npm publish` when the version is not already on npm.

### Fallback (manual tag without repushing)

When a version tag already exists but was not published (or `workflow_dispatch` is unavailable), merge a PR that sets **`.github/npm-publish-tag`** to the tag to publish (one line, e.g. `v0.7.0`). A push to `main` that changes only that file triggers the same publish path as dispatch: tag sources, tooling from `main`, then publish.

Do not commit npm tokens. Configure the trusted publisher on npmjs.com for repository `jose-compu/curated-erc`, workflow filename `publish.yml`, with no GitHub Environment unless you add one there too.