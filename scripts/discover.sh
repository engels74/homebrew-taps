#!/usr/bin/env bash
# Print the GitHub Actions matrix for update-casks.yml as JSON: {"cask":["a","b"]}.
# Every pipelines/<token>/ directory is one matrix entry. Pass a token to select
# only that cask (used by workflow_dispatch).
#
# Usage: scripts/discover.sh [TOKEN]
# shellcheck source=SCRIPTDIR/lib/common.sh
source "$(dirname "$0")/lib/common.sh"

filter="${1:-}"
casks=()

for dir in "${REPO_ROOT}"/pipelines/*/
do
  cask="$(basename "${dir}")"
  load_pipeline "${cask}" >/dev/null # validates config, resolver, and cask file
  if [[ -z "${filter}" ]] || [[ "${filter}" = "${cask}" ]]
  then
    casks+=("${cask}")
  fi
done

[[ "${#casks[@]}" -gt 0 ]] || die "No pipeline matches '${filter}'"
printf '%s\n' "${casks[@]}" | jq -R . | jq -cs '{cask: .}'
