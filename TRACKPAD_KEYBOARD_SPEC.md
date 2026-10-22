# Trackpad Keyboard Implementation Handoff

Draft specification for a native macOS utility that turns the trackpad into an absolute swipe keyboard while a popup is active. Launching and dismissing the keyboard must accept configurable built-in inputs and external commands. A single tap with three fingers is the preferred initial gesture, rather than a required dependency of the keyboard.

Prepared for implementation handoff on October 18, 2026. Working name: TrackpadSwipe. The present deliverable is a feasibility probe and this specification; the product is not implemented.

## Current implementation update

A local native prototype now exists in `native/`. Subsequent user testing revised the interaction: move the normal pointer onto a starting key, click to begin recording, trace with relative pointer motion, and click again to commit and release. Opening the popup and hovering do not start capture. Lifting or repositioning a finger does not end the stroke. Rendering and hit testing share one scaled screen viewport, and the system cursor is hidden only while a clicked stroke is active. This supersedes the absolute trackpad mapping and lift-to-commit proposal below. Configurable keyboard size, relative pointer sensitivity, placement presets, and a draggable saved position are implemented. See `native/README.md` and `native/TEST_RESULTS.md` for the current behavior and verified scope; the remaining sections preserve the original planning baseline.

## Confirmed requirements

- Show a popup containing a keyboard, a visible finger position and swipe trail, and word predictions.
- While active, map the trackpad surface to that keyboard and capture its input until explicitly dismissed. Pointer position on the desktop must not determine which key the finger touches.
- Support one simultaneous three-finger tap to toggle the popup. This means one tap with three fingers, not three successive taps with one finger.
- Accept generic launch inputs: configurable built-in gestures and shortcuts, a menu command, and external invocation by tools such as BetterTouchTool, Shortcuts, or Raycast.
- Preserve the original application's text destination across activation and word entry.
- Avoid depending on a particular global key combination. The existing Shift+Tab interaction was difficult to use and caused this redesign.

## Proposed first release behavior

The application runs in the menu bar with its icon visible by default. The menu always exposes Show Keyboard, Hide Keyboard, Settings, Diagnostics, and Quit. Opening the app a second time displays an accessible control surface instead of silently doing nothing.

Activation records the destination application and focused editable element, shows a nonactivating panel on the destination's display, and arms capture. Wait for every finger involved in activation to lift before accepting a typing stroke. The activation gesture must never become the first word.

One finger traces a word using absolute trackpad coordinates. The popup follows its path immediately. Lifting the finger finishes the stroke and, as a proposed default, inserts the highest-ranked word followed by one space. A short tap enters an individual key. Define a movement and duration threshold that distinguishes taps from strokes. The prediction row permits correction of the most recently inserted word without requiring ordinary pointer movement.

Map prediction cells and a bottom row containing Space, Backspace, Return, and Close to dedicated trackpad regions. A tap selects a cell; moving through these regions during a word stroke must not execute commands. Changing the selected prediction replaces only the application's own last committed word, and only while the destination and caret remain valid. If replacement cannot be verified, keep the alternative pending rather than delete unrelated text. The exact row proportions and correction interaction require usability testing.

A three-finger tap toggles capture off. Esc and the menu command provide independent ways to exit. Closing discards an unfinished stroke, releases input capture, hides the panel, and preserves already committed text. The product must never require the activation gesture as its only escape mechanism.

## Generic input contract

All launch adapters dispatch to one session controller. Gesture recognition must not directly create windows, intercept the pointer, or insert text. Each adapter produces the same intent: show, hide, or toggle, with a source identifier and monotonic timestamp.

| Input adapter | Required behavior |
| --- | --- |
| Built-in trackpad gesture | Initial recognizer supports a three-finger tap, enabled or disabled in Settings; keep recognizers replaceable |
| Global keyboard shortcut | Optional, configurable, removable; report registration failures rather than silently fall back |
| Menu and app launch | Always available without a working gesture or shortcut |
| CLI | Proposed commands: `trackpadswipe show`, `trackpadswipe hide`, `trackpadswipe toggle`, and `trackpadswipe status` |
| URL handler | Proposed URLs: `trackpadswipe://show`, `trackpadswipe://hide`, and `trackpadswipe://toggle`; usable by external automation |

Show and hide are idempotent. Toggle operates once per recognized input. Debounce duplicate delivery from the same gesture; serialize distinct intents in the controller. External adapters must address the running singleton without making a launcher process the typing destination. Do not open multiple capture sessions or multiple application instances. External commands control visibility only; accepting arbitrary text, executable code, or network commands is outside the first release.

Settings allow the native gesture to be disabled when an external gesture tool is used. Instructions should explain how an external tool invokes the URL or CLI without assuming that BetterTouchTool or another paid tool is installed.

## Session states and capture lifecycle

Use explicit states: idle, arming, capturing, releasing, and unavailable. Showing from idle enters arming. Capturing starts only when prerequisites pass, the popup is ready, and activation contacts have lifted. Hiding from arming or capturing enters releasing, then idle. A permission failure or lost device releases immediately and reports the unavailable reason. Show must not report success until capture is actually ready.

The trackpad backend supplies timestamped contact frames with device ID, contact ID, phase, and normalized position. Three-finger recognition uses duration, maximum displacement, maximum concurrent contacts, and finger arrival spread. Recognize on release and require a clean lift before rearming. Reject four-finger episodes, three-finger swipes, and resting palms. Initial calibration values may use a 350 ms duration and 3.5 percent movement bound, but these are tuning candidates rather than validated defaults.

Keep gesture recognition independent of word strokes. If extra contacts appear while a word is being traced, cancel that stroke and begin gesture classification; never commit it accidentally. Device changes and sleep or wake invalidate pending contacts. Reinitialize the selected device and require a clean lift after reconnection.

Capture means that the selected trackpad's normal pointer motion, clicks, scrolling, and conflicting gestures do not affect the destination while the keyboard is active. Raw contact observation alone does not provide this behavior. Prototype event suppression separately and verify conflicts with macOS three-finger lookup, dragging, Mission Control, and other gesture tools. Do not claim exclusive capture until these cases pass.

Prefer device-specific suppression. If the available interception path cannot distinguish trackpad events from an external mouse, document that limitation in the prototype and resolve the intended behavior before release; do not silently suppress every pointing device. Esc, system shortcuts, and the menu escape remain functional. On focus changes, screen lock, session switch, permission revocation, backend failure, or quit, discard uncommitted input and release capture. Watchdog and event-tap timeout paths must release rather than leave an invisible captured session.

## Keyboard mapping and prediction

Use one authoritative keyboard geometry for rendering, hit testing, and decoding. Normalize trackpad positions, verify axis orientation against physical movement, and map into keyboard coordinates with an aspect-correct transform. Account explicitly for padding, staggered rows, prediction cells, and command regions. Each point on the trackpad must correspond consistently to the same popup location.

Retain raw path geometry and timestamps. Filter jitter and resample by distance before decoding. The decoder should accept coordinate paths and return ranked words with scores. Keep decoding away from the touch callback, cancel stale work, and prevent a result from an old stroke or closed session from being inserted.

SwipeType's Rust engine and dictionary are candidates for reuse. Its current public prediction API accepts a character sequence and reconstructs positions from key centers. It does not accept the raw continuous path collected by a trackpad. Add and evaluate a coordinate-path API before assuming equivalent accuracy. Converting paths to crossed keys is acceptable as an explicitly measured baseline, not a substitute for evaluating continuous decoding.

The existing renderer and engine also use different row offsets: the engine uses 0, 0.5, and 1.5 while the current displayed keyboard uses 0, 1, and 1.5. Reconcile this before training user muscle memory or comparing prediction accuracy.

## Focus and text delivery

The overlay should remain nonactivating so the target retains its caret. Capture the target before any UI or external launcher changes focus. Validate that the target application and editable context still match before each commit. If the user changes applications or the insertion target disappears, release capture and require explicit reactivation.

Evaluate Accessibility insertion and synthetic Unicode events against TextEdit, a browser textarea, and an Electron editor. Retain a deliberate fallback for apps that need paste. Clipboard fallback must restore all original items and representations, avoid overwriting a newer user copy, and serialize multiple commits. Do not copy the current upstream implementation without reviewing its asynchronous paste timing and flattening of multiple clipboard items.

Do not insert into secure fields or silently redirect text. Diagnostics should identify missing permissions or unsupported targets without recording entered words or clipboard data.

## Platform and source strategy

Start as a separate native macOS application with its own bundle ID and preferences, leaving the installed SwipeType app intact. Reuse MIT-licensed upstream components with attribution. The investigation began from SwipeType commit `e07a986398e3a424f9413d2f5ec44cc5833d0388`.

Global raw touch observation can use Apple's private MultitouchSupport framework through a small isolated adapter or an evaluated wrapper. This creates an OS compatibility and distribution dependency. The initial target is a directly distributed macOS utility; App Store delivery is not a first release assumption. Feature-detect the backend and expose unsupported hardware or OS states explicitly. OpenMultitouchSupport currently lists macOS 15 or later; do not inherit SwipeType's macOS 13 minimum without checking the selected backend.

Accessibility permission belongs to the final application identity. Permission granted to SwipeType does not establish permission for a differently identified prototype. Ask only for permissions actually required by the selected implementation, and provide visible status and a retry path.

## Feasibility test results

On October 18, 2026, a 60-second passive probe ran successfully on this arm64 Mac with macOS 26.6.2, using the default multitouch device. The private framework loaded, device start returned zero, and the process completed normally. It received 2,123 contact frames and 3,224 active contact samples. Peak concurrent contacts were three, with 89 frames containing exactly three active contacts. Recorded normalized positions covered x 0.000 to 1.000 and y 0.302 to 0.999. These values establish raw contact delivery, not a calibrated keyboard transform or coverage of the full vertical surface.

The probe found no tap candidates under its initial thresholds. Two recorded three-finger contact episodes lasted approximately 8.3 and 13.9 seconds and exceeded the movement bound. This does not validate intentional tap recognition. Six synthetic gesture cases passed: a short three-finger tap, rejection of a swipe, rejection of a long hold, rejection of four-finger contact, rejection of a one-finger stroke, and acceptance of staggered finger arrival. Live gesture tuning is still required.

The probe had no Accessibility grant, and creation of an intercepting event tap returned unavailable. No event tap was installed, no normal input was suppressed, and no permission was requested. This result limits what the test establishes; it does not show that capture is impossible. The next feasibility milestone is a correctly identified application with user-granted Accessibility access, demonstrating capture and release, system gesture conflicts, and reliable three-finger toggling. Popup mapping, word prediction, text delivery, and target retention were not exercised.

Reproducible source, commands, raw summary, and scope are in `feasibility/trackpad_probe.c`, `feasibility/README.md`, `feasibility/probe-result.txt`, and `feasibility/self-test-result.txt` in the local checkout. The live probe logs only contact episode aggregates and overall coordinate bounds; it stores no typed text or clipboard contents.

## Implementation sequence

1. Complete a minimal hardware test for raw contact frames, three-finger activation, absolute mapping, capture and release, and conflicting system gestures. Provide explicit show and hide commands to test independently of gesture recognition.
2. Build the singleton session controller, menu recovery path, generic input adapters, and a nonactivating popup. Verify show and hide idempotency and focus preservation before enabling word entry.
3. Integrate shared keyboard geometry and the decoder baseline, then evaluate the coordinate-path decoder with recorded synthetic fixtures and a consented live test set.
4. Add text insertion, command regions, and prediction correction. Test target and clipboard races before using normal documents.
5. Harden device lifecycle, permissions, crash recovery, multi-display behavior, packaging, and diagnostics. Keep gesture thresholds configurable until usability results support defaults.

## Acceptance criteria

| Area | Required demonstration |
| --- | --- |
| Generic activation | Gesture, configured hotkey, menu, CLI, and URL all reach the same controller; repeated show or hide calls are safe |
| Three-finger tap | At least 19 of 20 deliberate taps toggle once each; zero toggles in a scripted set of 20 three-finger swipes and 20 single-finger strokes; record conditions |
| Absolute input | Corner and center touches map to corresponding keyboard regions independent of desktop pointer position |
| Real capture | Trace and tap while active without moving the desktop pointer, clicking underlying UI, scrolling, or invoking configured conflicting gestures |
| Release | Gesture, Esc, menu, device loss, sleep, permission loss, and process termination restore ordinary input; event-tap timeout never leaves invisible capture |
| Target retention | Insert ten consecutive words into TextEdit, a browser textarea, and an Electron editor with no focus theft, missing spaces, or delivery to the launcher |
| Correction | Choosing a replacement changes only the last app-owned word; target or caret changes invalidate replacement |
| Commands | Key taps, Space, Backspace, Return, and Close work without accidental commands during swipes |
| Performance | Proposed targets: p95 visible path response below 33 ms and p95 word prediction below 100 ms on this Mac; measure rather than infer |
| Prediction | Establish a fixed English test set and report top-one and top-five accuracy for crossed-key and coordinate-path decoding; choose release thresholds after the baseline |
| Permissions | Clean installation and revoked-permission cases explain the specific failure and offer recovery; no hidden icon by default |
| Privacy | No entered text or raw contact logging by default; explicit opt-in and bounded retention for diagnostic recordings |

## Decisions for the implementer

The confirmed interaction is trackpad swipe input plus generic activation. Proposed defaults that still need usability validation include committing the best prediction on lift, selecting corrections through trackpad regions, panel dimensions, gesture thresholds, and external mouse behavior during capture. Native raw-touch observation has to be distinguished from successful suppression of system gestures. The first implementation milestone must resolve that distinction before promising the complete interaction.

## References

- [SwipeType source](https://github.com/ZimengXiong/swipeType) and its [Rust prediction interface](https://github.com/ZimengXiong/swipeType/blob/e07a986398e3a424f9413d2f5ec44cc5833d0388/crates/swipe-engine/src/lib.rs).
- [Apple trackpad event handling](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/HandlingTouchEvents/HandlingTouchEvents.html).
- [OpenMultitouchSupport](https://github.com/Kyome22/OpenMultitouchSupport) and its [private ABI declarations](https://github.com/Kyome22/OpenMultitouchSupport/blob/main/Framework/OpenMultitouchSupportXCF/OpenMTInternal.h).
- [macOS trackpad demo](https://github.com/shaunlebron/macos-trackpad-demo), including discussion of cursor positioning for the public AppKit touch path.
