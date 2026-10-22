# Contributing to TrackpadSwipe

TrackpadSwipe is an experimental native macOS application. Development happens in [GitHub](https://github.com/abwagner/TrackpadSwipe); submit issues and pull requests there. Hosting may require an account.

## Development

Use macOS 15 or later with Xcode Command Line Tools, Python 3, and OpenSSL on your PATH. No submodules are required.

```sh
native/check.sh
```

This compiles the native app and runs core checks without installing, signing, requesting Accessibility access, or capturing input. It does not validate live gestures or text entry.

For live testing, run `native/setup-signing.sh` once, then `native/build.sh`. The build stops the current app and replaces `~/Applications/TrackpadType.app`; the old filename and bundle ID preserve existing permissions and preferences. Open that app and grant Accessibility manually. Keep the dedicated signing keychain and password outside the repository. Do not share your development signing identity.

Work in `native/` for the current app. The Rust engine and original apps are retained upstream source. Keep changes focused, explain user-visible behavior, and run the checks above. For capture or placement changes, also try the relevant steps in [native/TEST_RESULTS.md](native/TEST_RESULTS.md) and describe your macOS version, hardware, editor, and actual results. Never substitute generated path accuracy for human testing.

## Bug reports

Include macOS version, built-in or external trackpad, activation method, keyboard size and location, target editor, expected behavior, actual behavior, and reproduction steps. Remove private text from screenshots and logs. Do not attach signing keys, keychain files, passwords, or tokens. For a suspected security issue, use the private reporting form linked in [SECURITY.md](SECURITY.md); do not post exploit details or sensitive data in public issues.

## Distribution and attribution

The repository supports universal DMG/ZIP packaging through `native/package.sh`. See [release packaging](docs/RELEASING.md). No notarized release is published automatically, and no Homebrew formula is provided. The legacy `make release` command only points to these packaging instructions; it cannot publish.

Contributions are under the repository's MIT license. Preserve SwipeType attribution and license notices. The demo GIF is an illustration generated from app geometry and decoder output, not a live screen recording.
