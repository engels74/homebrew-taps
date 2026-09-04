#!/usr/bin/env bash
# Decide whether TOKEN needs an update. Prints key=value lines for GITHUB_OUTPUT:
#   previous_version, rolling_release_exists, rolling_asset_exists, needed, reason
#
# An update is needed when the cask version differs from upstream, when the
# rolling release is missing, or when it exists but lacks the versioned asset.
# The last two conditions make a deleted release or asset self-heal.
#
# Usage: scripts/check-update.sh TOKEN NEW_VERSION ASSET
# shellcheck source=SCRIPTDIR/lib/common.sh
source "$(dirname "$0")/lib/common.sh"

load_pipeline "${1:?usage: check-update.sh TOKEN NEW_VERSION ASSET}"
new_version="${2:?NEW_VERSION}"
asset="${3:?ASSET}"

current_version="$(cask_version "${REPO_ROOT}/${CASK_FILE}")"
log "Cask ${CASK_TOKEN}: current=${current_version} upstream=${new_version} asset=${asset}"
echo "previous_version=${current_version}"

release_exists=false
asset_exists=false
tmp="$(mktemp)"
if gh release view "${RELEASE_TAG}" --json assets >"${tmp}" 2>/dev/null
then
  release_exists=true
  if jq -e --arg name "${asset}" '.assets[]? | select(.name == $name)' "${tmp}" >/dev/null
  then
    asset_exists=true
  fi
fi
echo "rolling_release_exists=${release_exists}"
echo "rolling_asset_exists=${asset_exists}"

if [[ "${current_version}" != "${new_version}" ]]
then
  echo "needed=true"
  echo "reason=version changed"
elif [[ "${release_exists}" != "true" ]]
then
  echo "needed=true"
  echo "reason=rolling release ${RELEASE_TAG} is missing"
elif [[ "${asset_exists}" != "true" ]]
then
  echo "needed=true"
  echo "reason=rolling release is missing ${asset}"
else
  echo "needed=false"
  echo "reason=up to date"
fi
