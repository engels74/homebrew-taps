#!/usr/bin/env bash
# Download the upstream artifact into the current directory as ASSET and print
# its SHA256 as "sha256=<hex>". When ARCHIVE_MEMBER is given the download is a
# zip and the named member is extracted and renamed to ASSET.
#
# Usage: scripts/fetch-asset.sh DOWNLOAD_URL ASSET [ARCHIVE_MEMBER]
# shellcheck source=SCRIPTDIR/lib/common.sh
source "$(dirname "$0")/lib/common.sh"

url="${1:?DOWNLOAD_URL}"
asset="${2:?ASSET}"
member="${3:-}"

if [[ -z "${member}" ]]
then
  log "Downloading ${url}"
  curl -fsSL --retry 5 --retry-all-errors --retry-max-time 300 -o "${asset}" "${url}"
else
  log "Downloading archive ${url}"
  curl -fsSL --retry 5 --retry-all-errors --retry-max-time 300 -o upstream-archive.zip "${url}"
  unzip -o -q upstream-archive.zip "${member}"
  [[ -f "${member}" ]] || die "${member} not found inside the downloaded archive"
  mv -f "${member}" "${asset}"
  rm -f upstream-archive.zip
fi

[[ -s "${asset}" ]] || die "Downloaded asset ${asset} is empty"
ls -la "${asset}" >&2
echo "sha256=$(shasum -a 256 "${asset}" | awk '{print $1}')"
