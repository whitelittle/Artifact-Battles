#!/usr/bin/env python3
"""Verify and reassemble the two original handoff ZIPs without third-party packages."""
import argparse
import hashlib
import json
from pathlib import Path


def restore(package, base, output_dir):
    target = output_dir / package["name"]
    temporary = target.with_name(target.name + ".partial")
    if target.exists() or temporary.exists():
        raise FileExistsError(f"Refusing to overwrite {target} or {temporary}")
    whole = hashlib.sha256()
    written = 0
    try:
        with temporary.open("xb") as output:
            for part in package["parts"]:
                part_hash = hashlib.sha256()
                part_bytes = 0
                with (base / "parts" / part["name"]).open("rb") as source:
                    while True:
                        block = source.read(1024 * 1024)
                        if not block:
                            break
                        output.write(block)
                        whole.update(block)
                        part_hash.update(block)
                        written += len(block)
                        part_bytes += len(block)
                if part_bytes != part["size"] or part_hash.hexdigest() != part["sha256"]:
                    raise ValueError(f"Part failed verification: {part['name']}")
        if written != package["size"] or whole.hexdigest() != package["sha256"]:
            raise ValueError(f"Package failed verification: {package['name']}")
        temporary.rename(target)
    except Exception:
        temporary.unlink(missing_ok=True)
        raise
    print(f"OK  {target}  SHA-256 {whole.hexdigest()}")


def main():
    base = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=base / "restored")
    args = parser.parse_args()
    manifest = json.loads((base / "manifest.json").read_text(encoding="utf-8"))
    if manifest.get("format_version") != 1:
        raise ValueError("Unsupported manifest format")
    args.output_dir.mkdir(parents=True, exist_ok=True)
    for package in manifest["packages"]:
        restore(package, base, args.output_dir)


if __name__ == "__main__":
    main()
