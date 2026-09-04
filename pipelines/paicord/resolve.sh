#!/usr/bin/env bash
# Resolver: Paicord.
#
# Upstream publishes no releases. Version = <commit date>-<short sha> of the
# newest successful build.yml run on main; the DMG comes zipped from
# nightly.link, which mirrors that run's artifact.

# shellcheck source=SCRIPTDIR/../../scripts/lib/common.sh
source "$(dirname "$0")/../../scripts/lib/common.sh"
load_pipeline "$(basename "$(cd "$(dirname "$0")" && pwd)")"
: "${RESOLVE_OUT:?RESOLVE_OUT (output file) is required}"

status="$(gh_api "repos/${UPSTREAM_REPO}/actions/workflows/build.yml/runs?branch=main&status=success&per_page=1" runs.json)"
require_2xx "${status}" "listing ${UPSTREAM_REPO} build runs" runs.json

if [[ "$(jq '.total_count' runs.json)" -eq 0 ]]
then
  log "No successful upstream build runs found."
  kv "${RESOLVE_OUT}" skip true
  exit 0 # resolvers run in a subshell; this ends only the resolver
fi

head_sha="$(jq -r '.workflow_runs[0].head_sha // empty' runs.json)"
[[ "${head_sha}" =~ ^[0-9a-f]{40}$ ]] || die "Unexpected head_sha: ${head_sha}"
short_sha="${head_sha:0:7}"
rm -f runs.json

status="$(gh_api "repos/${UPSTREAM_REPO}/commits/${head_sha}" commit.json)"
require_2xx "${status}" "fetching commit ${head_sha}" commit.json
commit_date="$(jq -r '.commit.author.date // empty' commit.json | cut -dT -f1)"
[[ "${commit_date}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || die "Unexpected commit date: ${commit_date}"
rm -f commit.json

version="${commit_date}-${short_sha}"

# Link "Changes" to the diff from the version currently in the cask, when known.
previous="$(cask_version "${REPO_ROOT}/${CASK_FILE}")"
prev_sha="$(printf '%s' "${previous}" | grep -oE '[0-9a-f]{7}$' || true)"
if [[ -n "${prev_sha}" ]] && [[ "${prev_sha}" != "${short_sha}" ]]
then
  changes_url="${UPSTREAM_URL}/compare/${prev_sha}...${short_sha}"
else
  changes_url="${UPSTREAM_URL}/commit/${head_sha}"
fi

kv "${RESOLVE_OUT}" version "${version}"
kv "${RESOLVE_OUT}" download_url "https://nightly.link/${UPSTREAM_REPO}/workflows/build/main/Paicord-macOS.zip"
kv "${RESOLVE_OUT}" archive_member "Paicord.dmg"
kv "${RESOLVE_OUT}" ref "${short_sha}"
kv "${RESOLVE_OUT}" changes_url "${changes_url}"
