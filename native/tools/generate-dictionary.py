#!/usr/bin/env python3
"""Generate the bundled CC BY-SA dictionary with wordfreq==3.1.1, offline."""
import hashlib
import importlib.metadata
import json
from pathlib import Path
import re

from wordfreq import available_languages, iter_wordlist, word_frequency

VERSION = "3.1.1"
LIMIT = 60_000
SCALE = 1_000_000_000_000


def main():
    if importlib.metadata.version("wordfreq") != VERSION:
        raise SystemExit(f"Use wordfreq=={VERSION} to reproduce this dictionary")
    root = Path(__file__).resolve().parents[2]
    rows = []
    for word in iter_wordlist("en", wordlist="large"):
        if 2 <= len(word) <= 22 and re.fullmatch(r"[a-z]+(?:'[a-z]+)*", word):
            weight = max(1, round(word_frequency(word, "en", wordlist="large") * SCALE))
            rows.append(f"{word}\t{weight}\n")
            if len(rows) == LIMIT:
                break
    if len(rows) != LIMIT:
        raise SystemExit("Not enough eligible dictionary entries")
    data = "".join(rows).encode("utf-8")
    (root / "word_freq.txt").write_bytes(data)
    source = Path(available_languages(wordlist="large")["en"])
    metadata = {
        "provider": "wordfreq",
        "version": VERSION,
        "creator": "Robyn Speer",
        "source": "https://pypi.org/project/wordfreq/3.1.1/",
        "language": "en",
        "wordlist": "large",
        "entries": len(rows),
        "transform": "First 60000 frequency-ranked ASCII lowercase words, allowing internal apostrophes, of length 2–22; frequencies multiplied by 10^12 and rounded to integers, minimum 1; tab-separated UTF-8.",
        "license": "CC-BY-SA-4.0",
        "license_url": "https://creativecommons.org/licenses/by-sa/4.0/",
        "source_data_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "output_sha256": hashlib.sha256(data).hexdigest(),
    }
    (root / "docs/dictionary.json").write_text(json.dumps(metadata, indent=2) + "\n")
    print(f"Generated {len(rows)} entries; SHA256 {metadata['output_sha256']}")


if __name__ == "__main__":
    main()
