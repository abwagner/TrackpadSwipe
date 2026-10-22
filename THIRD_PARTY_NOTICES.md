# Third-party notices and provenance

## SwipeType

TrackpadSwipe is derived from [SwipeType](https://github.com/ZimengXiong/swipeType), initially checked out at commit `e07a986398e3a424f9413d2f5ec44cc5833d0388`.

Copyright (c) 2026 Zimeng Xiong. The MIT copyright and permission notice are retained in [LICENSE](LICENSE), with the engine's original notice also in `crates/swipe-engine/LICENSE`. The native build includes the root license in its Resources directory. TrackpadSwipe modifications are identified separately in the root license.

## OpenMultitouchSupport

The private multitouch ABI structures and callback declarations in `native/TrackpadBridge.c` and `feasibility/trackpad_probe.c` were adapted from [OpenMTInternal.h](https://github.com/Kyome22/OpenMultitouchSupport/blob/main/Framework/OpenMultitouchSupportXCF/OpenMTInternal.h) in OpenMultitouchSupport by Takuto Nakamura.

Copyright (c) 2019 TakutoNakamura. MIT license: [full notice](licenses/OpenMultitouchSupport-MIT.txt). That notice is also bundled with native app builds. The OpenMultitouchSupport framework itself is not bundled or linked; the native bridge loads Apple's system framework.

## wordfreq English frequency data

`word_freq.txt` is derived from wordfreq 3.1.1 by **Robyn Speer**, copyright 2022 Robyn Speer. Source: https://pypi.org/project/wordfreq/3.1.1/ . The adapted dictionary is licensed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/), separately from the application's MIT code. The data is provided without warranty under the [license terms](https://creativecommons.org/licenses/by-sa/4.0/legalcode).

Changes: select the first 60,000 frequency-ranked lowercase ASCII words, allowing internal apostrophes, of length 2–22 from the English large list; multiply relative frequencies by 10^12, round to integers with minimum 1, and serialize as tab-separated UTF-8. Metadata and SHA-256 checksums are in `docs/dictionary.json`; the pinned generator is `native/tools/generate-dictionary.py`.

The [retained wordfreq notices](licenses/wordfreq-NOTICE.md) include credit to Robyn Speer, OpenSubtitles, Google Books Ngrams, and other source projects and SUBTLEX authors, including Marc Brysbaert and Boris New. SUBTLEX is freely available data. The native app bundles those notices and the generation metadata. The wordfreq Python library is used offline to prepare the data; it is not a runtime dependency or bundled code.

### Clean source snapshot

This repository was created from TrackpadSwipe source snapshot `a43bcda` without its prior Git history. The older Norvig/Google Web Trillion Word Corpus-derived dictionary is not included in this snapshot or its Git objects. The current dictionary is generated entirely from wordfreq 3.1.1. SwipeType and OpenMultitouchSupport source attributions and license notices remain intact.

## Platforms, development tools, and retained upstream apps

The native application uses Apple's system frameworks and system fonts, and is built with Swift and Clang. Those tools and Apple frameworks are not copied into the repository. Their use does not make OpenMultitouchSupport's or SwipeType's notices optional.

The retained Rust and web projects use dependencies described in `Cargo.toml` and `Cargo.lock`; they are not linked into the native TrackpadSwipe app. The inherited prebuilt web bundle has been omitted from this source snapshot. A future distribution of Rust or web binaries needs its own dependency-license inventory. This review covers the native application's identified borrowed source and dataset, not a complete audit of every upstream binary or historical revision.
