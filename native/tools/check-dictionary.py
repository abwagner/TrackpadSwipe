#!/usr/bin/env python3
"""Check the committed dictionary without requiring the wordfreq package."""
import hashlib
import json
from pathlib import Path
import re

root = Path(__file__).resolve().parents[2]
data = (root / "word_freq.txt").read_bytes()
metadata = json.loads((root / "docs/dictionary.json").read_text())
assert metadata["provider"] == "wordfreq" and metadata["version"] == "3.1.1"
assert metadata["license"] == "CC-BY-SA-4.0"
assert hashlib.sha256(data).hexdigest() == metadata["output_sha256"]
rows = [line.split("\t") for line in data.decode("utf-8").splitlines()]
assert len(rows) == metadata["entries"] == 60_000
assert all(len(row) == 2 and 2 <= len(row[0]) <= 22 and re.fullmatch(r"[a-z]+(?:'[a-z]+)*", row[0]) for row in rows)
assert len({row[0] for row in rows}) == len(rows)
weights = [int(row[1]) for row in rows]
assert all(weight >= 1 for weight in weights)
assert weights == sorted(weights, reverse=True)
assert {"hello", "don't", "can't", "it's", "you're"} <= {row[0] for row in rows}
notice = (root / "licenses/wordfreq-NOTICE.md").read_text()
assert "Robyn Speer" in notice and "CC BY-SA 4.0" in notice
print("PASS: pinned wordfreq dictionary checksum, vocabulary, ranks, and notices")
