#!/usr/bin/env python3
"""Require every formula/architecture, verify hashes, and normalize upload names."""

import hashlib
import json
from pathlib import Path
import re
import sys


def verify(directory, root_url):
    formulae = {p.stem for p in Path("Formula").glob("*.rb")}
    expected = set(json.loads(Path("pipelines/bottles.json").read_text()))
    if not expected or not expected <= formulae:
        raise ValueError("Invalid bottle publication allowlist")
    versions = {}
    for name in expected:
        recipe = Path(f"Formula/{name}.rb").read_text()
        version = re.search(r'^  version "([^"]+)"$', recipe, re.M)[1]
        revision = re.search(r'^  revision (\d+)$', recipe, re.M)
        versions[name] = version + (f"_{revision[1]}" if revision else "")
    seen = set()
    allowed_assets = set()
    for metadata in sorted(directory.glob("*.bottle.json")):
        for full_name, entry in json.loads(metadata.read_text()).items():
            name = full_name.removeprefix("edbfi/taps/")
            if name not in expected or full_name != f"edbfi/taps/{name}":
                raise ValueError(f"Unexpected formula: {full_name}")
            if entry["bottle"]["root_url"] != root_url:
                raise ValueError("Bottle belongs to another release")
            if entry["formula"]["pkg_version"] != versions[name]:
                raise ValueError(f"Bottle version differs from recipe: {name}")
            for arch, bottle in entry["bottle"]["tags"].items():
                key = (name, arch)
                if arch not in ("arm64_linux", "x86_64_linux") or key in seen:
                    raise ValueError(f"Unexpected/duplicate bottle: {key}")
                seen.add(key)
                for field in ("local_filename", "filename"):
                    if Path(bottle[field]).name != bottle[field]:
                        raise ValueError("Unsafe bottle filename")
                if bottle["filename"] != f"{name}-{versions[name]}.{arch}.bottle.tar.gz":
                    raise ValueError("Unexpected bottle filename")
                source = directory / bottle["local_filename"]
                if not source.exists():
                    source = directory / bottle["filename"]
                with source.open("rb") as stream:
                    digest = hashlib.file_digest(stream, "sha256").hexdigest()
                if digest != bottle["sha256"]:
                    raise ValueError(f"Checksum mismatch: {source}")
                source.rename(directory / bottle["filename"])
                allowed_assets.add(bottle["filename"])
    required = {(name, arch) for name in expected for arch in ("arm64_linux", "x86_64_linux")}
    if seen != required:
        raise ValueError(f"Incomplete bottle set: missing {sorted(required - seen)}")
    for name in formulae:
        text = Path(f"Formula/{name}.rb").read_text()
        version = re.search(r'^  version "([^"]+)"$', text, re.M)[1]
        if not (directory / f"{name}-{version}-source.tar.gz").is_file():
            raise ValueError(f"Missing corresponding source for {name}")
        allowed_assets.add(f"{name}-{version}-source.tar.gz")
    unexpected = {p.name for p in directory.glob("*.tar.gz")} - allowed_assets
    if unexpected:
        raise ValueError(f"Unexpected release assets: {sorted(unexpected)}")
    with (directory / "SHA256SUMS").open("w") as checksums:
        for asset in sorted([*directory.glob("*.tar.gz"), *directory.glob("*.bottle.json")]):
            with asset.open("rb") as stream:
                digest = hashlib.file_digest(stream, "sha256").hexdigest()
            checksums.write(f"{digest}  {asset.name}\n")


if __name__ == "__main__":
    verify(Path(sys.argv[1]), sys.argv[2])
