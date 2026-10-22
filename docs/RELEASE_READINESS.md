# 0.2.0 release readiness

## Current status — build 13, 2026-10-22

- Source/privacy preparation is complete; the reachable history uses a GitHub noreply email. The current commit's native checks and universal compilation pass CI.
- The owner reports live testing complete and clean-install testing passed for the current candidate. These are user-reported acceptance results; exact hardware/account/artifact details were not supplied. Earlier pending-check statements below are historical.
- Repository roles are confirmed: private GitHub `TrackpadSwipe-dev` mirrors Forgejo development, including intermediate commits; public `TrackpadSwipe` receives only approved release updates. In this checkout, `origin` points to the private mirror; the separate `public-release` remote has ordinary pushes disabled. Download hosting is awaiting the owner’s decision. The existing unpublished, asset-free GitHub release draft was removed; GitHub currently has no release assets, stored Actions artifacts, or Pages site.
- Build-13 release notes include Telegram input, contractions, word deletion, and the Fn symbols page. Refreshed local preview DMG/ZIP packages passed checksum, signature, universal-slice, version/resource, and installation-file verification. These previews are explicitly unnotarized.
- Public download remains blocked on a valid Developer ID Application identity, notarization/stapling, release-artifact verification, and selection of the download host. The visible Apple Development identity does not satisfy distribution signing. Intel hardware is unverified. No binary release has been published.

## Historical review and preparation evidence

The [full independent source review](REVIEW-2026-10-18.md) audits the frozen candidate before fixes, including retained upstream code. Its original verdict and findings are preserved verbatim. Nine specialist personas ran; cost review was skipped because no material paid services were identified.

## Review dispositions

| Finding | Resolution |
|---|---|
| Mutable web dictionary reaching HTML | Bundled dictionary, HTTP error check, DOM textContent/createTextNode |
| Correction crossing editor fields | Immutable application/AX element ownership and exact caret/text checks |
| Retired activation tests | Removed detector; tests call production C click/contact handlers |
| Distribution/development path mismatch | Helpers prefer distribution install; documented one-time permission migration |
| AX RPCs blocking event tap | Dedicated serial AX queue with bounded proxy timeouts |
| Unused viewport helper | Production screen transform tested against independent screen points |
| Clipboard item flattening in retained app | Preserve one pasteboard item per original item |
| Duplicated maximum word length | Shared dictionary rule and actual loaded maximum |
| Ambiguous session capture state | Ready phase separated from actual capture flag |
| Version authority unclear | Native Info.plist documented as authoritative |

Targeted follow-up review found asynchronous output could follow a focus change and queued correction could outlive cancellation. Most native text edits address the exact AX field directly, without global keyboard-event fallback. Subsequent Codex compatibility testing found AX writes could be acknowledged without visible insertion; that app now uses process-targeted keyboard input with immediate app/field/selection/cancellation checks. A focus change within Codex between final validation and asynchronous event delivery remains an open limitation. Cancellation tickets guard pending setters; deterministic production transaction tests cover queued/read cancellation, invalid caret/text, and setter failure. Destination switches also cancel pending edits. The targeted adversarial review found no remaining findings in the AX-only implementation (static review); that verdict does not cover the later Codex compatibility path. A remote write already begun cannot be revoked.

## Evidence and remaining release gates

- Native automated checks, pinned dictionary validation, universal compilation, preview packaging, and bundle checks run locally. See [test results](../native/TEST_RESULTS.md).
- Complete-path synthetic benchmark: 20/21 top-one; p95 about 22 ms. Partial-path p95 about 61 ms. Human accuracy is unverified.
- The user confirmed consecutive-word insertion and caret advancement in Codex on build 8. Broader physical three-finger click and editor compatibility checks remain, including no click leakage, correction, Esc, permission loss, sleep/wake, and screen edges.
- Preview packages are explicitly unnotarized. The visible valid signing identity is Apple Development; Developer ID Application identity and a notarytool profile must be resolved before a notarized public download. Never publish the preview as an Apple-verified release.
- Universal slices compile, but Intel hardware and a clean downloaded/quarantined installation have not been tested.

## Final preparation, build 11

The [post-audit input review](REVIEW-2026-10-21.md) found one Important issue and one Minor test gap. The AX range/value reader is now shared by context and verification, and uncertain verification after a successful mutation no longer restores a stale original selection. Tests exercise value-only editors, verified consecutive writes, uncertain postconditions, and actual typing eligibility checks for changed app/field/selection and cancellation. The acknowledged intra-Codex asynchronous focus limitation remains documented.

Public-repository preparation includes macOS CI for native tests/universal compilation, private vulnerability reporting and a [security policy](../SECURITY.md), [prepared release notes](releases/v0.2.0.md), a plain-text installation guide inside the DMG, and automatic DMG/ZIP verification. The original review reports describe pre-fix snapshots; current dispositions are recorded here.

The 2026-10-21 signing check still found only Apple Development in configured keychains. No Developer ID signature, notarization, clean downloaded-app result, or unperformed physical check is claimed. The source changes and preview package are reviewable. Public binary release remains gated by signing/notarization and live hardware/editor validation.

## Telegram Desktop compatibility, build 12

Telegram Desktop uses the same process-targeted input backend as Codex, retaining immediate app/field/selection/cancellation checks. Regression checks cover backend selection and consecutive word spacing with native caret advancement. Local compilation and checks pass; live Telegram insertion and correction still need validation. The existing asynchronous focus limitation applies to both apps.

## Keyboard controls, build 13

The wordfreq adaptation now includes internal apostrophes, with updated provenance/checksums and notices. Fn toggles a single-click number/punctuation page, and the on-screen delete command removes words or selected text. Native regression checks and full-dictionary contraction probes pass; physical interaction and live editor checks remain separate. The illustrated walkthrough was regenerated with the new command row.
