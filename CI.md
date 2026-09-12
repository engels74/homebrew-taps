# Required CI and checked cask updates

Every pull request and default-branch push runs `ci`. The required `ci / required`
aggregate depends on the complete native cask and shell validation workflow;
missing, failed, skipped or cancelled lanes cannot pass. Generated PR dispatches
verify their live head before and after CI. Review all jobs and exact head/base, author/DCO and relevant artifacts before
merging through the maintainer ghmerge function. No branch protections or
rulesets are configured; automerge remains disabled.

The existing `brew readall --no-simulate`, `brew style` and `brew audit --cask`
checks run against the exact PR checkout on macOS 15 ARM64. The Linux lane runs
Bash syntax, ShellCheck and five Python fixtures exercising the real rewrite and
discovery scripts: Ruby-valid updates, unsafe version/hash rejection, missing
rewrite anchors, and one-to-one cask/pipeline discovery. Run
`bash .github/scripts/check.sh` locally with Python, Ruby, jq and ShellCheck.
CI rejects tracked-file changes. Native Homebrew validation remains required;
Linux syntax/fixture checks are not a substitute for the macOS result.

The existing sequential updater still resolves/downloads/hashes upstream assets,
publishes rolling releases and optionally reports VirusTotal results. It now
proposes only the generated cask on `fix/update-cask-<token>` and explicitly
runs full CI for that PR's exact SHA. Enable **Allow GitHub Actions to create and
approve pull requests**; the repository token needs contents, pull-requests and
actions write permissions in the publisher only. The scheduled updater and
keepalive run only on the configured default branch. The dedicated edbfi WORKFLOW_KEEPALIVE_TOKEN-backed
keepalive and optional VirusTotal configuration are preserved. Manual CI recovery
inputs are printed if dispatch fails. Cask versions, checksums, resolver rules, existing release assets and vendored
keepalive source are preserved. The updater checks out its exact triggering
revision and requires a successful main-push CI run for that SHA before publishing.

The versioned `edbfi/automation` preset replaces unconditional major automerge
and `ignoreTests: true`. Full action version tags are bot-managed; automerge stays
off pending the shared pre-1.0 policy correction and activation. Renovate's
Homebrew manager is disabled because the cask updater owns verified re-hosted
versions/checksums. The macOS CI does not launch applications; the updater now inspects bundle identity
and architectures before publication. VirusTotal remains optional. Published assets are preserved while cask PRs await manual review. The Linux integration adds reusable formulae.yml to the same required gate. It
builds all four source formulae on native Ubuntu ARM64 and x86_64, runs linkage,
strict audits and X11/Wayland GUI checks, then locally reinstalls the three eligible
bottles and repeats checks. Fred TV stays source-installed. Complete combined
bottle/source artifacts are verified in a read-only aggregation job. Neither
Linux source resolution nor release publication runs automatically; recipe updates
require a reviewed PR. Existing keepalive credentials remain unchanged.
