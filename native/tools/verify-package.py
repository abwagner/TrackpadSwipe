#!/usr/bin/env python3
"""Verify an existing DMG/ZIP pair without installing or launching the app."""
import argparse
import hashlib
from pathlib import Path
import plistlib
import subprocess
import tempfile

REPO = Path(__file__).resolve().parents[2]


def run(*args):
    return subprocess.check_output(args, stderr=subprocess.STDOUT)


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify_bundle(app, preview):
    info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    source_info = plistlib.loads((REPO / "native/Info.plist").read_bytes())
    for key in ("CFBundleIdentifier", "CFBundleExecutable", "CFBundleShortVersionString",
                "CFBundleVersion", "LSMinimumSystemVersion"):
        require(info[key] == source_info[key], f"Bundle metadata differs: {key}")
    executable = app / "Contents/MacOS" / info["CFBundleExecutable"]
    require(set(run("lipo", "-archs", str(executable)).decode().split()) == {"arm64", "x86_64"},
            "Both architecture slices are required")
    run("codesign", "--verify", "--strict", str(app))
    resources = app / "Contents/Resources"
    expected = {
        "word_freq.txt": "word_freq.txt",
        "SwipeType-LICENSE.txt": "LICENSE",
        "OpenMultitouchSupport-LICENSE.txt": "licenses/OpenMultitouchSupport-MIT.txt",
        "wordfreq-NOTICE.md": "licenses/wordfreq-NOTICE.md",
        "THIRD_PARTY_NOTICES.md": "THIRD_PARTY_NOTICES.md",
        "dictionary.json": "docs/dictionary.json",
    }
    for bundled, source in expected.items():
        require(digest(resources / bundled) == digest(REPO / source),
                f"Missing or stale bundled resource: {bundled}")
    if not preview:
        signature = run("codesign", "--display", "--verbose=4", str(app)).decode()
        require("Authority=Developer ID Application:" in signature,
                "Release app must have a Developer ID Application signature")
        require("runtime" in signature, "Release app must enable hardened runtime")
        run("xcrun", "stapler", "validate", str(app))
        run("spctl", "--assess", "--type", "execute", str(app))


def verify(dmg, preview):
    require(dmg.suffix == ".dmg", "Pass a DMG path")
    require(("UNNOTARIZED-preview" in dmg.stem) == preview,
            "Package name and verification mode disagree")
    zip_path = dmg.with_suffix(".zip")
    lines = dmg.with_suffix(".sha256").read_text().splitlines()
    checksums = dict(line.split(maxsplit=1)[::-1] for line in lines)
    require(set(checksums) == {dmg.name, zip_path.name}, "Unexpected checksum manifest contents")
    for path in (dmg, zip_path):
        require(digest(path) == checksums[path.name], f"Checksum mismatch: {path.name}")
    mount = plistlib.loads(run("hdiutil", "attach", "-readonly", "-nobrowse", "-plist", str(dmg)))
    volume = next(Path(item["mount-point"]) for item in mount["system-entities"] if "mount-point" in item)
    try:
        verify_bundle(volume / "TrackpadSwipe.app", preview)
        require((volume / "Applications").is_symlink(), "Missing Applications installation link")
        require((volume / "Applications").readlink() == Path("/Applications"), "Wrong Applications link")
        require((volume / "INSTALL.txt").read_bytes() == (REPO / "docs/INSTALL_PACKAGE.txt").read_bytes(),
                "Missing or stale package installation guide")
        require((volume / "UNNOTARIZED-PREVIEW.txt").exists() == preview,
                "Preview warning does not match verification mode")
        if not preview:
            run("codesign", "--verify", "--strict", str(dmg))
            run("xcrun", "stapler", "validate", str(dmg))
        with tempfile.TemporaryDirectory(prefix="trackpadswipe-verify-") as destination:
            run("ditto", "-x", "-k", str(zip_path), destination)
            verify_bundle(Path(destination) / "TrackpadSwipe.app", preview)
    finally:
        run("hdiutil", "detach", str(volume))
    print("PASS: package checksums, DMG/ZIP signatures, universal slices, version, resources, and installation files")
    if not preview:
        print("PASS: Developer ID, hardened runtime, notarization tickets, and app Gatekeeper assessment")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dmg", type=Path)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--preview", action="store_true")
    mode.add_argument("--release", action="store_true")
    args = parser.parse_args()
    try:
        verify(args.dmg.resolve(), args.preview)
    except (OSError, ValueError, KeyError, StopIteration, subprocess.CalledProcessError) as error:
        parser.exit(1, f"FAIL: {error}\n")
