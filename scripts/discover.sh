#!/usr/bin/env bash
# Print the GitHub Actions matrix for update-casks.yml as JSON: {"cask":["a","b"]}.
# Every pipelines/<token>/ directory is one matrix entry. Pass a token to select
# only that cask (used by workflow_dispatch).
#
# Usage: scripts/discover.sh [TOKEN]
# shellcheck source=SCRIPTDIR/lib/common.sh
source "$(dirname "$0")/lib/common.sh"

filter="${1:-}"
kind="${2:-cask}"
[[ "${kind}" = cask || "${kind}" = formula ]] || die "Expected cask or formula"
casks=()

for dir in "${REPO_ROOT}"/pipelines/*/
do
  cask="$(basename "${dir}")"
  PACKAGE_KINDS=cask
  # shellcheck disable=SC1091
  source "${dir}/config.env"
  [[ ",${PACKAGE_KINDS}," = *",${kind},"* ]] || continue
  load_pipeline "${cask}" "${kind}" >/dev/null
  if [[ -z "${filter}" ]] || [[ "${filter}" = "${cask}" ]]
  then
    casks+=("${cask}")
  fi
done

[[ "${#casks[@]}" -gt 0 ]] || die "No pipeline matches '${filter}'"
printf '%s\n' "${casks[@]}" | jq -R . | jq -cs --arg kind "${kind}" '{($kind): .}'
