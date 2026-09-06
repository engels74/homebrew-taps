#!/usr/bin/env bash
# Resolve a source release independently of the availability of macOS binaries.
# Usage: scripts/resolve-formula.sh TOKEN > resolved.json
# shellcheck source=SCRIPTDIR/lib/common.sh
source "$(dirname "$0")/lib/common.sh"
load_pipeline "${1:?TOKEN}" formula
work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

if [[ "${FORMULA_SOURCE:-}" = homebrew-pipewire ]]
then
  status="$(http_get https://formulae.brew.sh/api/formula/pipewire.json "${work}/release.json")"
  require_2xx "${status}" "resolving PipeWire" "${work}/release.json"
  version="$(jq -er '.versions.stable' "${work}/release.json")"
  [[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "Unexpected PipeWire version"
  url="https://gitlab.freedesktop.org/pipewire/pipewire/-/archive/${version}/pipewire-${version}.tar.gz"
  [[ "$(jq -r '.urls.stable.url' "${work}/release.json")" = "${url}" ]] || die "Unexpected PipeWire source URL"
  tag="${version}"
  status="$(http_get "https://gitlab.freedesktop.org/api/v4/projects/pipewire%2Fpipewire/repository/tags/${tag}" "${work}/commit.json")"
  require_2xx "${status}" "pinning PipeWire commit" "${work}/commit.json"
  commit="$(jq -er '.commit.id' "${work}/commit.json")"
  [[ "${commit}" =~ ^[0-9a-f]{40}$ ]] || die "Unexpected PipeWire commit"
  url="https://gitlab.freedesktop.org/pipewire/pipewire/-/archive/${commit}/pipewire-${commit}.tar.gz"
else
  if [[ "${CASK_TOKEN}" = fcast-sender ]]
  then
    tag=""
    for page in 1 2 3
    do
      status="$(gh_api "repos/${UPSTREAM_REPO}/releases?per_page=100&page=${page}" "${work}/release.json")"
      require_2xx "${status}" "listing Sender releases" "${work}/release.json"
      tag="$(jq -r '[.[] | select(.draft == false and (.tag_name | startswith("sender-")))] | sort_by(.published_at) | last | .tag_name // empty' "${work}/release.json")"
      [[ -n "${tag}" ]] && break
      [[ "$(jq length "${work}/release.json")" -lt 100 ]] && break
    done
    version="${tag#sender-}"
    version="${version%%-*}"
  else
    status="$(gh_api "repos/${UPSTREAM_REPO}/releases/latest" "${work}/release.json")"
    require_2xx "${status}" "resolving ${CASK_TOKEN}" "${work}/release.json"
    tag="$(jq -er '.tag_name' "${work}/release.json")"
    version="${tag#v}"
  fi
  : "${FORMULA_TAG_RE:?Missing source tag guard}"
  [[ "${tag}" =~ ${FORMULA_TAG_RE} ]] || die "Unexpected source tag: ${tag}"
  status="$(gh_api "repos/${UPSTREAM_REPO}/commits/${tag}" "${work}/commit.json")"
  require_2xx "${status}" "pinning source commit" "${work}/commit.json"
  commit="$(jq -er '.sha' "${work}/commit.json")"
  [[ "${commit}" =~ ^[0-9a-f]{40}$ ]] || die "Unexpected source commit"
  url="https://github.com/${UPSTREAM_REPO}/archive/${commit}.tar.gz"
fi
require_safe_version "${version}"
jq -n --arg token "${CASK_TOKEN}" --arg version "${version}" --arg ref "${tag}" \
  --arg url "${url}" --arg file "${FORMULA_FILE}" \
  '{token: $token, version: $version, ref: $ref, url: $url, file: $file}'
