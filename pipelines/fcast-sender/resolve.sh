#!/usr/bin/env bash
# Resolver: FCast Sender.
#
# futo-org/fcast keeps several products in one tag namespace (sender-*,
# desktop-receiver-*, android-*, electron-*), so /releases/latest points at the
# wrong product most of the time. Page through the release list and keep only
# sender tags. The DMG lives on dl.fcast.org, not on GitHub, and the CDN upload
# does not always land at the same moment as the GitHub release: a 404 there is
# a skip, not a failure.

# shellcheck source=SCRIPTDIR/../../scripts/lib/common.sh
source "$(dirname "$0")/../../scripts/lib/common.sh"
load_pipeline "$(basename "$(cd "$(dirname "$0")" && pwd)")"
: "${RESOLVE_OUT:?RESOLVE_OUT (output file) is required}"

tag=""
for page in 1 2 3
do
  status="$(gh_api "repos/${UPSTREAM_REPO}/releases?per_page=100&page=${page}" "releases-${page}.json")"
  require_2xx "${status}" "listing ${UPSTREAM_REPO} releases (page ${page})" "releases-${page}.json"

  tag="$(jq -r '
    [.[] | select(.draft == false) | select(.tag_name | startswith("sender-"))]
    | sort_by(.published_at) | reverse | .[0].tag_name // empty
  ' "releases-${page}.json")"
  [[ -n "${tag}" ]] && break

  # A short page proves the list is exhausted.
  if [[ "$(jq 'length' "releases-${page}.json")" -lt 100 ]]; then break; fi
done
rm -f releases-*.json
[[ -n "${tag}" ]] || die "No sender-* release found in ${UPSTREAM_REPO}."

# Only accept tags like sender-0.0.3-beta or sender-1.2.0.
tag_re='^sender-[0-9]+\.[0-9]+\.[0-9]+(-(alpha|beta|rc)(\.?[0-9]+)?)?$'
[[ "${tag}" =~ ${tag_re} ]] || die "Unexpected upstream tag format: ${tag}"

# The published file drops the pre-release suffix the tag carries:
# sender-0.0.3-beta -> fcast-sender-0.0.3-macos-aarch64.dmg
version="${tag#sender-}"
version="${version%%-*}"
download_url="https://dl.fcast.org/sender/desktop/macos-aarch64/fcast-sender-${version}-macos-aarch64.dmg"

status="$(http_get "${download_url}" /dev/null -r 0-0)"
if [[ "${status}" = "404" ]]
then
  log "Upstream DMG is not published yet: ${download_url}"
  kv "${RESOLVE_OUT}" skip true
  exit 0 # resolvers run in a subshell; this ends only the resolver
fi
require_2xx "${status}" "probing ${download_url}"

kv "${RESOLVE_OUT}" version "${version}"
kv "${RESOLVE_OUT}" download_url "${download_url}"
kv "${RESOLVE_OUT}" ref "${tag}"
kv "${RESOLVE_OUT}" changes_url "${UPSTREAM_URL}/releases/tag/${tag}"
