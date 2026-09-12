#!/usr/bin/env bash
set -euo pipefail
for file in scripts/*.sh scripts/lib/*.sh pipelines/*/resolve.sh; do
  bash -n "$file"
done
shellcheck -S warning -x scripts/*.sh scripts/lib/*.sh pipelines/*/resolve.sh
python3 -m unittest discover -s tests -v
