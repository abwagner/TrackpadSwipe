"""Append only the dedicated development keychain, preserving the user's list."""
import shlex
import subprocess
import sys

keychain = sys.argv[1]
current = shlex.split(subprocess.check_output(
    ["security", "list-keychains", "-d", "user"], text=True
))
if keychain not in current:
    subprocess.run(
        ["security", "list-keychains", "-d", "user", "-s", *current, keychain],
        check=True,
    )
