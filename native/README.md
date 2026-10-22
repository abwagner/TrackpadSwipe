# TrackpadSwipe local prototype

Native macOS trackpad swipe keyboard. Source is maintained in the GitHub repository `abwagner/TrackpadSwipe`.

## Build and run

```sh
native/build.sh
```

Open `~/Applications/TrackpadType.app`. Each successful build installs this same app path, stops the previous local process, and retains a generated backup in `native/build/TrackpadType.previous`. Opening the app or reopening it shows the keyboard. The menu bar dropdown contains only Settings and Quit. Settings groups size and location under Keyboard, cursor speed under Pointer, and gestures and shortcuts under Open and close the keyboard. A missing Accessibility grant leaves the keyboard visible with an actionable permission message instead of redirecting to Settings. You can open the keyboard before selecting a text field; a valid field is required when starting a typing stroke. Give **TrackpadSwipe** its own Accessibility permission. Local builds now use a persistent certificate and a designated requirement pinned to that certificate and the bundle ID. A fresh Accessibility approval is needed once when migrating from the old ad hoc build to the installed copy. Subsequent builds retain the signing identity. Permission is never bypassed or reset by the build script.

Run `native/setup-signing.sh` once before building on each development Mac. Its private key stays in a dedicated user keychain at `~/Library/Application Support/TrackpadTypeSigning/TrackpadType.keychain-db`. The generated password file is private to the user. The helper adds that keychain to the existing user search list without replacing other entries; it does not change system certificate trust or Accessibility permissions. Signing fails rather than silently falling back to ad hoc identity. Keep this keychain and its state when moving the source into another repository; never commit the key or password.

`native/test-signing.sh` signs two different executables, verifies that their designated requirements match, and verifies the second executable against the first requirement.

The build uses Xcode command line tools, C, and Swift. It does not require Rust or third-party package downloads. The bundled dictionary is generated from wordfreq 3.1.1 by Robyn Speer under CC BY-SA 4.0; the prototype's continuous-coordinate decoder is implemented in Swift.

If macOS silently ignores adding the installed copy during the initial migration, a stale Accessibility record may still contain an old ad hoc build hash. After confirming that mismatch in `tccd` logs, reset only this app with `tccutil reset Accessibility com.andz.TrackpadType`, reopen the Accessibility pane, and manually add the installed app again. This removes the old approval; it does not grant access. During the initial migration on this Mac, the user privacy service also cached the deleted build path; restarting that user service cleared the stale lookup. Permission retention was then verified across a real installed-app rebuild to version 2. The build scripts never reset privacy permissions or restart privacy services.

## Interaction

The product menu and Settings page contain no test controls, diagnostic counters, or show/hide buttons. An engineering-only capture test remains available through `native/trackpadswipe test`; it ends after ten seconds and never enters text.

For typing, focus an editable text field and rest three fingers and click the trackpad to open the keyboard. Opening leaves normal pointer movement enabled. Move onto a starting key, click to record, trace a word, and click again to enter the highest-ranked prediction. A separator is inserted before the word unless it is at the start of the field or immediately follows a hyphen or whitespace. Words receive no trailing space; corrections preserve their original leading separator. Lifting or repositioning a finger does not end a stroke. Hovering alone never enters text. A click-on/click-off stroke with negligible movement enters one letter. Prediction and command cells accept normal clicks between strokes. A three-finger click or Esc closes the keyboard. Sessions release after 120 seconds, on destination change, permission loss, sleep, or event-tap failure.

The regular cursor hides while hovering over the active keyboard and during an explicitly clicked stroke, leaving the blue marker visible. It stays hidden after click-off while still over the keyboard, then returns when moving outside, closing, or cancelling. Pointer capture restores its screen position to the marker’s endpoint. Rendering, click hit testing, and pointer warping use the same scaled keyboard viewport, including the popup's display position. Raw finger positions are used only to recognize the activation gesture; they no longer produce a second unrelated typing cursor.

Prediction cells can replace the last inserted word only if the original application, AX element, caret, and exact text range still match. Replacement normally writes directly to that owned AX element; Codex instead receives process-targeted typing after its original range is selected and verified. Editors that do not expose those Accessibility attributes cannot use replacement. Most editors use writes addressed directly to the validated Accessibility element. Codex uses Unicode keyboard events posted to its process because its chat input can acknowledge AX text writes without entering visible text. Both paths leave the clipboard untouched; the Codex path revalidates the frontmost app, original AX element, selection, and cancellation ticket immediately before posting. Other unsupported editors fail closed. Human swipe accuracy and compatibility across editors still require live validation.

## Appearance and tracking settings

- **Keyboard size:** 50–400 percent. The new 100 percent default is 370 × 235 points, half the original keyboard’s width and height. Text, keys, trail, and command cells scale together. The panel is clamped to the available display area.
- **Tracking sensitivity:** 0.5–2.5× linear gain for relative pointer motion during a stroke. Hover uses the normal macOS pointer. Each click anchors the marker exactly to the clicked key; changing sensitivity never changes that starting position.
- **Opening position:** Next to cursor (default), Bottom center, Center, Bottom left, Bottom right, Top center, or Custom. Cursor placement leaves a 16-point gap, switches sides near display edges, and stays inside the usable screen. The first update to this behavior selects Next to cursor for existing installs; later location changes are retained.
- **Place:** displays the keyboard without capturing input or entering text. Drag anywhere on its background to save a Custom position, then click Done. Saved centers are relative to the display so placement remains usable across display sizes.

All three settings persist in the app's preferences. Sensitivity applies to relative movement of the captured marker and word path; hover and key hit testing use screen coordinates. Gesture classification continues to use raw positions.

Suggestion cells reserve ten letter positions in width. They use one line until a longer word needs a second line (or, for the longest words, a third). The suggestion area grows upward while the letter keyboard stays in place when screen space allows. The font size stays unchanged. Slots wrap to another row only when required by the screen width. The letter keyboard keeps its own scale and uses the same viewport for rendering and hit testing. Suggestion text has its own System, Rounded, or Monospaced font and 8–24 point size, independent of keyboard zoom. Pointer settings offer a blue Dot, Ring, Crosshair, or Hidden typing marker. Hiding the marker preserves the swipe trail and key highlighting. The regular macOS pointer stays hidden over the keyboard and restores outside it.

## Generic triggers

The native three-finger trigger can be disabled. A global shortcut is optional: Record Shortcut accepts a key with Control, Option, or Command and reports registration conflicts. The menu contains only Settings and Quit. Show and hide remain available through the gesture, app launch, and external commands.

External tools can open `trackpadswipe://show`, `trackpadswipe://hide`, `trackpadswipe://toggle`, or `trackpadswipe://test`. The helper supports the same commands:

```sh
native/trackpadswipe show
native/trackpadswipe hide
native/trackpadswipe toggle
native/trackpadswipe test
native/trackpadswipe status
```

The helper launches in the background. Status contains phase (`idle`, `arming`, or `ready`), actual pointer-capture state, permissions, contact-frame and suppressed-event counts, dictionary size, and the last capture-test aggregate. It contains no entered words, clipboard data, or raw paths. External triggers must still preserve a valid target text field; launcher-specific focus behavior needs validation.

## Checks and known limits

The full `native/check.sh` suite checks the production C activation/click-pair routing and idempotent session transitions, all key centers, coordinate-path prediction, degenerate paths, and click anchoring, no recording while hovering, click-off isolation, relative sensitivity, viewport edges, and key alignment at multiple panel scales and display origins. `feasibility/` retains the earlier passive hardware probe.

The decoder benchmark with the wordfreq replacement uses generated paths with deterministic jitter. On this Mac it ranked 20 of 21 words first, with p95 around 22 ms; the missing word, “trackpad,” was outside the first 60,000 eligible dictionary entries. This does not measure human swipe accuracy. Reproduce by compiling `Core.swift` with `benchmark.swift` copied to a temporary `main.swift`, then passing `word_freq.txt` to the executable.

During an explicitly started stroke, the prototype suppresses **all pointing-device mouse events**, including an external mouse. Between strokes the normal pointer is free. Device-specific suppression is not implemented. System gestures such as three-finger lookup and Mission Control may still run; those conflicts need live verification. Raw contact handling uses an undocumented framework ABI and only the default trackpad. Modern macOS versions and external devices need compatibility checks.

The Rust-based upstream app remains intact. No login item, background service, network API, telemetry, or automatic publishing is installed by this prototype.

The product is named TrackpadSwipe. The local development filename `TrackpadType.app`, bundle ID `com.andz.TrackpadType`, and local signing state retain their original identifiers to preserve Accessibility access and preferences. The old `trackpadtype://` URLs and `native/trackpadtype` helper remain compatible.

## Rebuilding the dictionary

Normal app builds use the committed data and need no wordfreq installation. To regenerate it, create an isolated Python environment, install `wordfreq==3.1.1`, then run `native/tools/generate-dictionary.py` with that environment's Python. The script filters, ranks, and scales the data deterministically, and updates `docs/dictionary.json`. Keep `licenses/wordfreq-NOTICE.md` with the data. Review wordfreq's license and source notices before changing its version.

## Live predictions and activation

Activation requires a physical click while exactly three fingers are touching the trackpad; touch alone never toggles. A global event tap is installed after Accessibility is granted so the gesture works while the keyboard is hidden. The activation down/up pair is consumed. Raw contact state must be recent (150 ms).

During a clicked stroke, partial word matches run on the serial decoder queue, at most one in flight. The next request waits at least 120 ms and at least three times the previous compute duration after completion, targeting at most 25% of one CPU core for decoding while moving. Unchanged paths cause no new work; stale stroke results are discarded. Final matching runs on click-off, and only that result can enter text. See docs/RELEASING.md for packaging.

Editor Accessibility queries and editing operations run on a dedicated serial queue with 50 ms proxy messaging timeouts. Event-tap callbacks perform hit testing and enqueue target validation; capture begins only after validation returns for the same session/request. Pending clicks are consumed, Esc invalidates the request, and background focus checks do not block final insertion. Corrections require the original AX field even if another field contains identical text. Codex additionally uses process-targeted typing after validation; a focus change within that process between final validation and asynchronous event delivery remains a compatibility limitation.

Queued editor edits carry a cancellation ticket. Closing the keyboard cancels edits that have not begun. A remote Accessibility write already in progress cannot be revoked. No editor RPC runs on the event-tap callback or main queue.
