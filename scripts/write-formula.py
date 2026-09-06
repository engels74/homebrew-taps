#!/usr/bin/env python3
"""Update the three top-level source fields; never rewrite resource checksums."""

import hashlib
import json
from pathlib import Path
import re
import sys
import urllib.request


def rewrite(text, release, digest):
    version = release["version"]
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._+-]*", version):
        raise ValueError("Unsafe version")
    if not re.fullmatch(r"https://[A-Za-z0-9./_~%+=-]+", release["url"]):
        raise ValueError("Unsafe source URL")
    if not re.fullmatch(r"[a-f0-9]{64}", digest):
        raise ValueError("Invalid source checksum")
    old = {}
    for key in ("url", "version", "sha256"):
        matches = re.findall(r'^  ' + key + r' "([^"]+)"$', text, re.M)
        if len(matches) != 1:
            raise ValueError(f"Expected one top-level {key} field")
        old[key] = matches[0]
    if old == {"url": release["url"], "version": version, "sha256": digest}:
        return text
    if old["version"] == version:
        raise ValueError("Source changed under an existing version; review and explicitly revise the formula")
    for key, value in (("url", release["url"]), ("version", version), ("sha256", digest)):
        text = re.sub(r'^  ' + key + r' "[^"]+"$', lambda _: f'  {key} "{value}"', text, flags=re.M)
    text = re.sub(r"^  bottle do\n.*?^  end\n\n", "", text, flags=re.M | re.S)
    return re.sub(r"^  revision \d+\n", "", text, flags=re.M)


def main():
    release = json.loads(Path(sys.argv[1]).read_text())
    token = release["token"]
    if not re.fullmatch(r"[a-z0-9][a-z0-9-]*", token) or release["file"] != f"Formula/{token}.rb":
        raise ValueError("Unexpected formula path")
    path = Path(release["file"])
    with urllib.request.urlopen(release["url"], timeout=120) as response:
        digest = hashlib.file_digest(response, "sha256").hexdigest()
    text = path.read_text()
    updated = rewrite(text, release, digest)
    if text != updated:
        path.write_text(updated)
    print(f"{token}: {'unchanged' if text == updated else 'updated'} ({digest})")


if __name__ == "__main__":
    main()
