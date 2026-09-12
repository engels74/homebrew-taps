#!/usr/bin/env bash
# Compose the rolling release body for TOKEN on stdout.
#
# Usage: VERSION=… PREV_VERSION=… REF=… CHANGES_URL=… ASSET=… DOWNLOAD_URL=… \
#        scripts/release-notes.sh TOKEN
# shellcheck source=SCRIPTDIR/lib/common.sh
source "$(dirname "$0")/lib/common.sh"

load_pipeline "${1:?usage: release-notes.sh TOKEN}"
: "${VERSION:?}" "${ASSET:?}" "${DOWNLOAD_URL:?}"
PREV_VERSION="${PREV_VERSION:-}"
REF="${REF:-}"
CHANGES_URL="${CHANGES_URL:-}"

timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if [[ -n "${PREV_VERSION}" ]] && [[ "${PREV_VERSION}" != "${VERSION}" ]] && [[ -n "${CHANGES_URL}" ]]
then
  changes="[View changes on the upstream repo](${CHANGES_URL})"
else
  changes="_First tracked release — no previous version to compare._"
fi

ref_cell="—"
if [[ -n "${REF}" ]]
then
  ref_cell="[\`${REF}\`](${CHANGES_URL:-${UPSTREAM_URL}})"
fi

support=""
if [[ -n "${DONATE_LINKS}" ]]
then
  support="### Support the developer

Enjoying ${DISPLAY_NAME}? Remember to support the people who build it:
"
  IFS='|' read -ra links <<<"${DONATE_LINKS}"
  for link in "${links[@]}"
  do
    support+="
- ${link}"
  done
  support+="

---
"
fi

cat <<NOTES
## ${DISPLAY_NAME} — Rolling Release

This is an automatically maintained rolling release. The attached DMG always reflects the latest macOS build published by the upstream [${DISPLAY_NAME}](${UPSTREAM_URL}) project.

---

### Build Information

| Field | Value |
|-------|-------|
| **Version** | \`${VERSION}\` |
| **Upstream Ref** | ${ref_cell} |
| **Upstream Download** | [\`${DOWNLOAD_URL}\`](${DOWNLOAD_URL}) |
| **Build Timestamp** | \`${timestamp}\` |
| **Asset** | \`${ASSET}\` |

### Changes

${changes}

---

${support}
### Installation

\`\`\`bash
brew install --cask edbfi/taps/${CASK_TOKEN}
\`\`\`
NOTES
