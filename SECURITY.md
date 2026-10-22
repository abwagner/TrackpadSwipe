# Security reports

Report suspected vulnerabilities privately through
[GitHub's vulnerability reporting form](https://github.com/abwagner/TrackpadSwipe/security/advisories/new).
Private vulnerability reporting is enabled for this repository. Include the app
version/build, macOS version, affected editor, and reproduction steps. Remove
private text and credentials from screenshots and logs.

Do not post exploit details, passwords, signing material, or personal text in a
public issue. Ordinary bugs belong in GitHub Issues. The project is experimental;
there is no guaranteed response time or support commitment for older builds.

## Input and permission boundaries

TrackpadSwipe needs Accessibility permission. During a stroke it captures mouse
events from all pointing devices. Esc releases capture. Trackpad contact handling
uses an undocumented Apple framework and needs compatibility testing after macOS
updates.

Most editors receive writes addressed to the original Accessibility element.
Codex uses process-targeted typing because its chat input can acknowledge AX
writes without entering visible text. Its app, field, selection, and cancellation
state are checked immediately before posting. Focus changes inside Codex between
validation and event delivery remain a limitation. A remote write already in
progress cannot be revoked by cancellation.

There is no telemetry or network typing service. See [privacy details](docs/PRIVACY.md)
and [release validation status](docs/RELEASE_READINESS.md).
