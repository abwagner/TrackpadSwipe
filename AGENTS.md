# TrackpadSwipe development

- The current native application is in `native/`. `apps/` and `crates/` retain upstream SwipeType code.
- Run `native/check.sh` for native changes. It needs macOS and Xcode Command Line Tools but does not sign, install, or capture input.
- `native/build.sh` signs and installs the app and stops the running copy. Use it when an installed update is needed.
- Preserve the existing local development install at `~/Applications/TrackpadType.app`, its bundle ID, signing state, and legacy URL scheme. New distribution installs use `/Applications/TrackpadSwipe.app`; helpers prefer that installed copy. Keep the development path unchanged and document that switching to Developer ID distribution needs a one-time permission migration. Product-facing copy uses TrackpadSwipe.
- Never commit signing keys, keychains, passwords, or tokens. Keep MIT attribution intact.
- Forgejo is the source of truth for development. GitHub `origin` is the private `TrackpadSwipe-dev` development mirror and receives intermediate commits; `public-release` is the public `TrackpadSwipe` repository reserved for owner-approved releases. Never push routine development changes to the public release repository. Commit completed changes and run `scripts/sync-development.sh` to push Forgejo and synchronize its main branch/tags to the private development mirror. Do not push to the original SwipeType repository. Do not distribute binaries through GitHub Releases, Actions artifacts, or Pages unless the owner explicitly changes that policy. Publication requires separate authorization.
- `scripts/release.sh` is a disabled compatibility guard. Use `native/package.sh` for DMG/ZIP packaging; see docs/RELEASING.md. Packaging does not authorize publishing a binary release.
