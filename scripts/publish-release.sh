#!/usr/bin/env bash
# Upsert the rolling release for TOKEN with ASSET_PATH attached, verify the
# asset is present afterwards, then prune the release to its newest KEEP assets.
#
# Existing assets with the same name are left in place (the checksum in the cask
# was computed from the freshly downloaded upstream file, so a stale re-hosted
# copy must be deleted by hand before re-running; see AGENTS.md).
#
# Usage: scripts/publish-release.sh TOKEN ASSET_PATH NOTES_FILE [KEEP=2]
# shellcheck source=SCRIPTDIR/lib/common.sh
source "$(dirname "$0")/lib/common.sh"

load_pipeline "${1:?usage: publish-release.sh TOKEN ASSET_PATH NOTES_FILE [KEEP]}"
asset_path="${2:?ASSET_PATH}"
notes_file="${3:?NOTES_FILE}"
keep="${4:-2}"
asset="$(basename "${asset_path}")"

if gh release view "${RELEASE_TAG}" --json assets --jq '.assets[].name' >existing-assets.txt 2>/dev/null
then
  if grep -Fxq "${asset}" existing-assets.txt
  then
    log "Release ${RELEASE_TAG} already contains ${asset}; leaving the existing asset in place."
  else
    gh release upload "${RELEASE_TAG}" "${asset_path}" --clobber
  fi
  gh release edit "${RELEASE_TAG}" --title "${RELEASE_TITLE}" --notes-file "${notes_file}"
else
  gh release create "${RELEASE_TAG}" "${asset_path}" \
    --title "${RELEASE_TITLE}" \
    --notes-file "${notes_file}" \
    --latest=false
fi

# The cask URL must resolve after this step.
if ! gh release view "${RELEASE_TAG}" --json assets --jq '.assets[].name' | grep -Fxq "${asset}"
then
  die "Release ${RELEASE_TAG} does not contain ${asset} after upload."
fi

# Prune: keep the newest $keep assets so the release does not grow forever, while
# the previous version stays downloadable for users whose tap is not yet updated.
gh release view "${RELEASE_TAG}" --json assets \
  --jq ".assets | sort_by(.createdAt) | reverse | .[${keep}:] | .[].name" |
  while IFS= read -r old
  do
    [[ -n "${old}" ]] || continue
    [[ "${old}" != "${asset}" ]] || continue
    log "Pruning old asset ${old} from ${RELEASE_TAG}"
    gh release delete-asset "${RELEASE_TAG}" "${old}" --yes
  done

log "Rolling release ${RELEASE_TAG} now serves ${asset}."
