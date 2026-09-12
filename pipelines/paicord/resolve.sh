#!/usr/bin/env bash
# Resolver: Paicord.
#
# Version = <commit date>-<short sha> of the newest successful main push build.
# The release and asset must belong to that exact run, never a moving branch URL.

# shellcheck source=SCRIPTDIR/../../scripts/lib/common.sh
source "$(dirname "$0")/../../scripts/lib/common.sh"
load_pipeline "$(basename "$(cd "$(dirname "$0")" && pwd)")"
: "${RESOLVE_OUT:?RESOLVE_OUT (output file) is required}"

status="$(gh_api "repos/${UPSTREAM_REPO}/actions/workflows/build.yml/runs?branch=main&event=push&status=success&per_page=1" runs.json)"
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
run_id="$(jq -r '.workflow_runs[0].id' runs.json)"
[[ "${run_id}" =~ ^[0-9]+$ ]] || die "Unexpected run ID: ${run_id}"
rm -f runs.json

tag="paicord-nightly-${run_id}"
status="$(gh_api "repos/${UPSTREAM_REPO}/releases/tags/${tag}" release.json)"
if [[ "${status}" = "404" ]]
then
  log "Release for successful run ${run_id} is not published yet."
  kv "${RESOLVE_OUT}" skip true
  exit 0
fi
require_2xx "${status}" "fetching ${tag}" release.json
jq -e --arg tag "${tag}" '.tag_name == $tag and .draft == false' release.json >/dev/null || die "Unexpected Paicord release"
asset="Paicord-macOS-${short_sha}.dmg"
download_url="$(jq -er --arg name "${asset}" '[.assets[] | select(.name == $name)] | if length == 1 then .[0].browser_download_url else error("Expected one matching Paicord DMG") end' release.json)"
[[ "${download_url}" = "https://github.com/${UPSTREAM_REPO}/releases/download/${tag}/${asset}" ]] || die "Unexpected Paicord asset URL"
status="$(gh_api "repos/${UPSTREAM_REPO}/commits/${tag}" tag-commit.json)"
require_2xx "${status}" "verifying ${tag}" tag-commit.json
[[ "$(jq -r '.sha' tag-commit.json)" = "${head_sha}" ]] || die "Paicord release tag does not match build commit"
rm -f release.json tag-commit.json

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
kv "${RESOLVE_OUT}" download_url "${download_url}"
kv "${RESOLVE_OUT}" ref "${head_sha}"
kv "${RESOLVE_OUT}" changes_url "${changes_url}"
