# scoop-bucket

Personal Scoop bucket for packages published by AspireOne.

## Usage

Add the bucket once:

```powershell
scoop bucket add AspireOne https://github.com/AspireOne/scoop-bucket
```

Then install any app from this bucket:

```powershell
scoop install <app>
```

## Apps

- `codex-manage`

For example:

```powershell
scoop install codex-manage
```

## Updating manifests

This bucket owns manifest updates. Package release workflows send an existing app name and a published stable release tag. The manifest's `checkver.github` identifies the upstream repository; its `autoupdate` templates tell Scoop how to update the URLs and hashes while preserving other settings.

The candidate must pass the same Windows validation, downloads, installation, and package smoke tests as regular CI before it reaches `main`. Repeating the current version succeeds without a commit; older versions and prereleases are rejected. Concurrent requests queue. If `main` changes during validation, publication fails safely; send a fresh update request.

To request an update manually:

```sh
gh workflow run update-manifest.yml \
  --repo AspireOne/scoop-bucket \
  -f app=codex-manage \
  -f version=v1.9.2
```

Follow the result in [Update manifest runs](https://github.com/AspireOne/scoop-bucket/actions/workflows/update-manifest.yml). A delayed run whose CI definition has changed also requires a fresh request.

### Connecting a package

Add and test its manifest here first, including `checkver.github` and `autoupdate`. In the package repository, set `SCOOP_BUCKET_REPO` to `AspireOne/scoop-bucket` and add a `SCOOP_BUCKET_TOKEN` secret with **Contents: write** access to this bucket. The token sends a repository dispatch event; it needs no Actions permission. The package's built-in `GITHUB_TOKEN` cannot access another repository.

Add this notification to the package's stable-release workflow, using its app name:

```yaml
- name: Request Scoop update
  if: github.event.release.prerelease == false
  env:
    GH_TOKEN: ${{ secrets.SCOOP_BUCKET_TOKEN }}
    BUCKET_REPO: ${{ vars.SCOOP_BUCKET_REPO }}
    VERSION: ${{ github.event.release.tag_name }}
  run: |
    gh api --method POST "repos/$BUCKET_REPO/dispatches" \
      -f event_type=update-manifest \
      -f 'client_payload[app]=codex-manage' \
      -f "client_payload[version]=$VERSION"
```

This example assumes a `release: published` event. A workflow that publishes releases itself should send its resolved release tag after publishing and skip prereleases. A successful notification means the request was accepted; validation and publishing run separately in this bucket.
