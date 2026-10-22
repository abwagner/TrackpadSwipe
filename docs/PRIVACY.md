# Input and privacy

TrackpadSwipe processes trackpad contacts and word prediction locally. The native app does not send telemetry, make network requests, or use the clipboard to insert text.

Accessibility permission allows pointer capture and text insertion into the selected editor. While recording a word, the prototype suppresses mouse events from all pointing devices. Esc cancels capture. Three-finger activation uses an undocumented macOS framework; compatibility and system gesture conflicts remain limitations.

Settings are stored in macOS preferences. The local status file at `~/Library/Application Support/TrackpadType/status.json` contains operational state, permissions, counters, and capture-test aggregates. It also contains the latest editor-operation result or Accessibility error code, without editor text. It contains no entered words or raw paths. Word paths and candidate words are held in memory during interaction. The selected editor receives committed text and controls its own storage and synchronization.

Development signing credentials are stored separately in `~/Library/Application Support/TrackpadTypeSigning/`. Do not upload this directory or copy its private contents into the source tree.

Codex compatibility uses Unicode keyboard events delivered only to its process, after checking the original focused text field, selection, frontmost application, and cancellation state. This is asynchronous input: focus changes inside Codex between validation and event handling cannot be ruled out. Other editors use direct AX element writes. The clipboard is not used.
