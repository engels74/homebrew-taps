#!/usr/bin/env bash
# Resolver: Flixor.
#
# Reads /releases/latest (non-draft, non-prerelease). Upstream names its DMG
# inconsistently, so the first .dmg asset is taken, but it must live under the
# release's own download path. Tags look like beta2.4.0 or 1.0.0.

# shellcheck source=SCRIPTDIR/../../scripts/lib/common.sh
source "$(dirname "$0")/../../scripts/lib/common.sh"
load_pipeline "$(basename "$(cd "$(dirname "$0")" && pwd)")"
: "${RESOLVE_OUT:?RESOLVE_OUT (output file) is required}"

status="$(gh_api "repos/${UPSTREAM_REPO}/releases/latest" release.json)"
if [[ "${status}" = "404" ]]
then
  log "No upstream release found."
  kv "${RESOLVE_OUT}" skip true
  exit 0 # resolvers run in a subshell; this ends only the resolver
fi
require_2xx "${status}" "fetching latest ${UPSTREAM_REPO} release" release.json

tag="$(jq -r '.tag_name // empty' release.json)"
[[ -n "${tag}" ]] || die "Latest release payload has no tag_name."

tag_re='^[A-Za-z]*[0-9]+(\.[0-9]+)*$'
[[ "${tag}" =~ ${tag_re} ]] || die "Unexpected upstream tag format: ${tag}"

download_url="$(jq -r '[.assets[] | select(.name | test("\\.dmg$"; "i"))][0].browser_download_url // empty' release.json)"
[[ -n "${download_url}" ]] || die "No DMG asset in upstream release ${tag}."

expected_prefix="https://github.com/${UPSTREAM_REPO}/releases/download/${tag}/"
[[ "${download_url}" == "${expected_prefix}"* ]] || die "Unexpected DMG download URL: ${download_url}"
rm -f release.json

kv "${RESOLVE_OUT}" version "${tag}"
kv "${RESOLVE_OUT}" download_url "${download_url}"
kv "${RESOLVE_OUT}" ref "${tag}"
kv "${RESOLVE_OUT}" changes_url "${UPSTREAM_URL}/releases/tag/${tag}"
