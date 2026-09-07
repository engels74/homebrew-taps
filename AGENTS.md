# AGENTS.md

This file provides guidance to AI coding agents when working with code in this
repository.

## What this is

`engels74/taps`, one Homebrew tap that re-hosts macOS builds of several upstream
apps as casks. There is no application source, build system, or test suite here.
Three moving parts:

1. `Casks/<category>/<token>.rb`, the casks. Categories are folders only; Homebrew
   loads `Casks/**/*.rb` and the token is the filename.
2. `pipelines/<token>/` plus `scripts/`, the update pipeline. One resolver per cask,
   everything else shared.
3. `.github/workflows/`, the schedule (`update-casks.yml`), the reusable per-cask
   pipeline (`_update-cask.yml`), validation (`lint.yml`) and the cron keepalive
   (`immortality.yml`).

## The contract that spans files

- A cask's `url` points at **this** repo's rolling release `<token>-latest`, asset
  `<ASSET_PREFIX>-#{version}.dmg`. `ASSET_PREFIX` lives in `pipelines/<token>/config.env`
  and the release tag is derived from the token in `scripts/lib/common.sh`
  (`load_pipeline`). Change the cask `url` and `ASSET_PREFIX` together, then
  dispatch the workflow and confirm the release really holds the new filename.
- `version` and `sha256` in every cask are machine-owned. To move them run
  `gh workflow run update-casks.yml -f cask=<token>`; never hand-edit. If you must,
  hash the DMG from this repo's `<token>-latest` release, not the upstream file.
- Those two lines must keep exactly two leading spaces with the quoted value on the
  same line. `scripts/write-cask.sh` rewrites them with an anchored `sed` and, unlike
  the old per-repo workflows, **fails loudly** if the rewrite did not take effect.
- The updater commits as `github-actions[bot]` with `chore(<token>): update to <version>`
  through a checked cask PR with an explicit full-CI dispatch. See `CI.md` for
  required settings, local checks and generated update behavior.

## Adding a cask

1. `Casks/<category>/<token>.rb` with `url` as above and a donation `caveats` block
   (see the existing casks; qView and FCast Sender show the wording for upstreams
   with no donation page).
2. `pipelines/<token>/config.env` with `DISPLAY_NAME`, `UPSTREAM_REPO`, `UPSTREAM_URL`,
   `ASSET_PREFIX`, `DONATE_LINKS` (`Label: URL|Label: URL`, may be empty).
3. `pipelines/<token>/resolve.sh`. It runs with `lib/common.sh` helpers and the
   `config.env` variables loaded and must `kv "$RESOLVE_OUT" …` the keys documented
   at the top of `scripts/resolve.sh` (`version`, `download_url`, `ref`,
   `changes_url`, optional `archive_member`, or `skip true`). Validate the upstream
   tag with a strict regex before it becomes a version; `scripts/resolve.sh`
   re-checks against `^[A-Za-z0-9][A-Za-z0-9._+-]*$` as a last line of defence.
4. Test locally: `GH_TOKEN=$(gh auth token) bash scripts/resolve.sh <token>` must
   print the expected version. `bash scripts/discover.sh` must list the token.
5. Add the app to the README tables (Apps, Support, License).

No workflow edit is needed; `update-casks.yml` discovers `pipelines/*` at run time.

## Verifying changes locally

`brew style` and `brew audit` refuse bare paths, so link the working copy in as the
tap, run the checks, and unlink:

```bash
T="$(brew --repository)/Library/Taps/engels74"; mkdir -p "$T"; ln -sfn "$PWD" "$T/homebrew-taps"
brew readall --no-simulate engels74/taps
brew style engels74/taps          # rubocop on casks + shfmt/shellcheck on scripts
brew audit --cask --tap engels74/taps
rm "$T/homebrew-taps"
```

`brew style` runs shellcheck with all checks enabled and fails on info-level
findings; keep `.shellcheckrc` in mind before disabling checks inline. `actionlint`
validates the workflows. `lint.yml` runs the same native checks behind the unfiltered required `ci` gate.
`bash .github/scripts/check.sh` also runs four offline Python updater fixtures.

## Footguns

- **An upstream re-release under an existing version is never picked up.**
  `check-update.sh` says `needed=false` when the cask version matches and the
  rolling release already holds the asset, and `publish-release.sh` leaves a
  same-named asset in place. Recovery: delete that asset from `<token>-latest`, then
  dispatch the workflow for that cask.
- **`publish-release.sh` prunes the rolling release to its newest 2 assets** after a
  verified upload. Do not rely on older versioned DMGs staying downloadable.
- **Resolver guards are load-bearing, not defensive noise**: the tag regexes, the
  exact asset-name matches (`qView-<v>.dmg` excludes `qView-<v>-legacy.dmg`;
  `Fred.TV_<v>_universal.dmg` excludes other architectures), the exact expected URL
  checks, and FCast's `sender-` prefix filter (several products share one tag
  namespace upstream). Add guards; do not remove them.
- **FCast: a 404 on the derived `dl.fcast.org` URL is deliberately a skip**, not a
  failure. The GitHub release and the CDN upload land at different times.
- **Paicord: the version must end in exactly 7 hex chars** (`YYYY-MM-DD-sha7`); the
  "Changes" compare link is built from that suffix.
- **Flixor's app bundle is `FlixorMac.app` / `com.flixor.mac`** although the token
  is `flixor`; **Fred TV's bundle id is upstream's `dev.fredol.open-tv`**. Every `zap`
  path keys off those. Verify against an installed build before editing.
- **fcast-sender has no `postflight_steps` quarantine strip by design** (signed and
  notarized) and `depends_on arch: :arm64` because upstream ships aarch64 only. The
  other four casks strip `com.apple.quarantine` with `must_succeed: false`; keep that.
- **Step outputs enter shell only through `env:`.** Never interpolate `${{ }}` inside
  a `run:` block; the old flixor and paicord workflows did and it was a script
  injection path.
- `_update-cask.yml` runs casks with `max-parallel: 1`. Raising it reintroduces push
  races and VirusTotal rate-limit failures.
- The `virustotal-scan` job no-ops when `secrets.VT_API_KEY` is unset; missing scan
  results in release notes is expected, not a bug.
- `immortality.yml` needs `secrets.PERSONAL_TOKEN`; `github.token` cannot re-enable a
  workflow GitHub disabled for inactivity. If the 6-hour cron silently stops, check
  that secret first.
- `scripts/vendor/gh-workflow-immortality.sh` is vendored third-party MIT code
  (Daniel Rudolf, v1.1.1) in an AGPL-3.0 repo. Re-vendor from upstream rather than
  patching in place; its header points at a "LICENSE file" that here holds the AGPL
  text.
- Renovate uses the shared preset and required CI gate; `ignoreTests` is never
  enabled. Cask version/hash updates remain owned by the download/re-hosting
  publisher. See `CI.md` for the activation state and limitations.

## Conventions

- Conventional Commits for human commits; pipeline commits are
  `chore(<token>): update to <version>`.
- `README.md` is the user-facing description of the cadence, re-hosting, donation
  links and migration path. Keep it in sync when any of those change.
