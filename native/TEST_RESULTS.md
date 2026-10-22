# Local prototype verification

## Automated checks

The current `native/build.sh` build succeeds and its production executable passes `--self-test`. The C bridge check exercises the production physical-click policy with three contacts, rejected counts, stale frames, consumed down/up pairs, Escape and watchdog release. Core checks cover idempotent session transitions, key geometry, continuous-coordinate decoding, empty paths, click anchoring, no movement before capture, stopping movement after click-off, relative sensitivity, clamping, and production layout-to-screen alignment across four scales, three fonts, expanded rows, and an offset display origin. Plist, shell syntax, and whitespace checks pass.

The coordinate decoder's earlier generated-path benchmark ranked 20 of 21 cases first with p95 approximately 21 ms on this Mac. The missing word was outside the selected 60,000-word vocabulary. These generated paths do not establish human accuracy.

## Dictionary replacement

wordfreq 3.1.1's English large list replaces the inherited Norvig dictionary. The pinned generator emits 60,000 eligible words and records input/output checksums. On the existing 21 generated-path cases, the replacement ranked 20 first and 20 in the top five, with p95 about 22 ms. This matches the previous top-one result; “trackpad” remains outside the selected vocabulary. This is not human swipe validation.

## Live checks

The user confirmed that the earlier raw-touch capture test drew a trail, held the desktop pointer still, and released on Esc or timeout. The settings UI was verified by changing size to 80 percent, sensitivity to 1.5, and position to Bottom right, then restoring the defaults. The subsequent launch retained a user-saved Custom position.

The current build supersedes the raw-touch typing model with click-controlled relative strokes. Its click-interaction live check is separate from the signing migration. The app is now installed at `~/Applications/TrackpadType.app`, signed with a dedicated persistent local certificate instead of an ad hoc signature. Two different generated executables passed the same certificate-pinned designated requirement. The migration initially hit a stale user privacy-service lookup for the deleted build path. After clearing that cached lookup and receiving the fresh grant, the installed app reported Accessibility allowed. A subsequent version-only rebuild to CFBundleVersion 2 was signed, installed at the same path, and relaunched; its status still reported `accessibility: true` without another approval. This verifies permission retention across an actual installed-app update on this Mac.

## Current live check

1. Add the installed `~/Applications/TrackpadType.app` to Accessibility and enable it.
2. Run `native/trackpadswipe test`. Moving the normal pointer should not freeze it or start a word.
3. Move the pointer onto an identifiable key such as H. Click once. The keyboard marker should begin exactly on H and the system cursor should hide.
4. Move one finger. The marker should follow relative motion. Lifting and repositioning a finger should not finish the stroke or make the marker jump.
5. Click again. Recording should stop and ordinary pointer movement should resume. The blue dot remains while hovering over the keyboard; the regular cursor returns when moving outside. Test Capture must enter no text.
6. Repeat and use Esc while recording. Recording and the popup must close with the system pointer restored.
7. In a scratch text field, open the normal keyboard and click–trace–click “hello” and “world.” Confirm the words go to that field. Check Space, Backspace, Return, and safe prediction replacement separately.

Device-specific suppression, three-finger system gesture conflicts, and editor compatibility remain prototype limitations.

## 0.2.0 release-candidate checks

Automated checks now cover partial-path completion, empty partial paths, fixed suggestion widths, dynamic text lines, unchanged selected fonts, and stable letter-key position as the suggestion area changes. The wordfreq generated-path benchmark still ranks 20/21 words first (p95 full match about 22 ms). On 84 generated prefix queries, p95 was about 61 ms and maximum about 71 ms on the development Apple silicon Mac. Prefix queries are approximate suggestions, not text-entry operations; the final click always runs the complete-path decoder.

A universal ad hoc signed preview DMG/ZIP builds and the host slice passes self-tests. This does not establish notarization, downloaded-app Gatekeeper behavior, Intel hardware compatibility, or live three-finger click recognition. Physical three-finger click, ordinary touch not toggling, no click leaking into the editor, final-word insertion, and Esc during a stroke still need a human hardware check for this release candidate.

The production editor transaction now has deterministic fake-editor checks for queued cancellation, cancellation during a delayed read, changed caret, changed previous text, failed selected-text setters, and field-bound writes after focus changes. Ordinary insertion, Backspace, Return, and correction use the same AX element-addressed path; there is no global keyboard-event fallback. These tests do not establish live editor compatibility. Cancellation prevents pending writes from beginning; an AX write already in flight cannot be revoked.

## Caret advancement regression

The field-addressed selected-text setter is now followed by an explicit collapsed selection after the inserted UTF-16 text. Production transaction tests model an editor that leaves its selection unchanged after text replacement and verify two consecutive words append correctly, corrections collapse at the new word end, selected emoji replacement uses UTF-16 offsets, and Backspace removes whole composed characters. Live validation in the user's affected editor remains separate.

## Codex insertion compatibility

The user reported no visible insertion in Codex while the native diagnostic recorded a successful AX write. Codex (`com.openai.codex`) now uses Unicode keyboard events posted only to its process, without forcing an AX caret position afterward. Backspace uses the native delete key. Validation runs on the AX queue immediately before posting and checks the frontmost application, original non-secure AX element, selection, and cancellation ticket. Other applications retain field-addressed writes, with a read-back check for nonempty inserted text. Errors remain visible for five seconds and the local status file includes the operation result, without entered text.

Automated checks cover backend selection, cancelled and invalid-target rejection, and avoiding a stale AX caret overwrite after native input. No test posts keyboard events. The user confirmed two consecutive words appear correctly in the Codex chat box with the caret advancing on build 8. Changes of focus inside Codex between validation and asynchronous event handling remain a limitation.

## Conditional word separators (build 9)

Recognized words no longer receive trailing spaces. Production transaction tests cover first-word insertion, consecutive words, preceding hyphens, spaces/tabs/newlines, UTF-16 context after emoji, selected-word replacement, and corrections preserving both spaced and unspaced prefixes. Individual letter taps and explicit Space/Return controls retain their existing behavior. The exact formatted insertion is recorded for safe correction. Context is read from the validated editor on the AX queue; field-value reads are a fallback for editors without a parameterized range reader. These automated checks do not establish live context-reading compatibility in every editor.

## Public-release candidate, build 10

The repeat source review found a value-only editor verification bug and a focus-predicate test gap. Both are covered by new production-boundary tests: context and verification share one bounded UTF-16 reader, value-only editors append consecutive words, uncertain verification does not restore a stale selection, and each app/field/selection mismatch or cancellation during validation prevents event emission. The tests post no real keyboard events. The previous Codex build-8 human result remains scoped to that build; this candidate's hardware/editor checks are still pending.

Packaging now verifies both mounted DMG and extracted ZIP contents, signatures, universal slices, exact version/build, dictionary and attribution resources, installation text, and checksums. Release verification additionally requires Developer ID, hardened runtime, stapled tickets, and Gatekeeper assessment. GitHub CI runs native checks and universal compilation without signing credentials.

The final local build-10 preview passed the automatic read-only DMG/ZIP verifier, including signatures, metadata, slices, notices, and installation files. Negative checks rejected a tampered ZIP, preview/release mode mismatch, and Apple Development identity supplied for distribution. Targeted follow-up Data-Integrity and Test reviews found the two source findings resolved.

GitHub macOS-15 CI exposed an older-toolchain CGFloat/Double overload ambiguity in keyboard drawing. Build 11 makes those coordinate conversions explicit. Local native checks pass; the GitHub rerun is recorded separately.

## Telegram Desktop compatibility, build 12

Telegram Desktop (`com.tdesktop.Telegram`) now uses the existing process-targeted Unicode keyboard input path, with the same app, field, selection, and cancellation checks as Codex. The path avoids an AX selection setter when the current selection already matches, and leaves caret advancement to the editor. Operation messages now say “editor” instead of “Codex.” Automated checks cover routing and consecutive words with conditional leading spaces in a model with read-only AX selection and native caret movement; they post no input events. Live Telegram insertion and correction remain unverified. The intra-process focus timing limitation also applies to Telegram.

## Contractions, word deletion, and symbols, build 13

The pinned wordfreq generator and native decoder retain words with internal ASCII apostrophes; matching skips the apostrophe in the drawn path and preserves it in output. The dictionary remains 60,000 entries, with updated checksums and adaptation notices. Fn toggles a click-to-enter page of digits and punctuation; ABC returns to letters. The on-screen delete command removes the selection or previous word (including trailing whitespace); AX editors use whitespace boundaries, while Codex and Telegram receive Option-Delete and use their own word boundaries. Hardware Delete is unchanged.

Automated checks cover contraction eligibility and prediction, symbol/letter geometry, Unicode word deletion, selected-text deletion, and deletion in the middle of a field. A full-dictionary check places don't, can't, it's, you're, I'm, we're, that's, and isn't in the top five for their exact letter paths; were ranks ahead of we're because the paths coincide. Native checks post no real input. Physical interaction and live target-editor behavior remain separate checks.

## Owner acceptance, 2026-10-22

For the current build-13 candidate, the owner reports live testing complete and clean-install testing passed, responding to the release-readiness gates. This supersedes the pending human-check status above. These are user-reported acceptance results, not independently observed automated results; exact hardware/account/artifact details were not supplied. This does not establish Developer ID signing, notarization, or Intel hardware validation.
