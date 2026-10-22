# Trackpad input feasibility probe

This is a temporary passive test, not a keyboard application. It loads macOS's private MultitouchSupport framework, observes the default device, prints contact episode aggregates, and checks whether an intercepting event tap can be created. It never installs that tap, suppresses input, inserts text, or asks for permissions. The process stops after the selected duration, at most 120 seconds.

The private contact ABI follows [OpenMultitouchSupport's declarations](https://github.com/Kyome22/OpenMultitouchSupport/blob/main/Framework/OpenMultitouchSupportXCF/OpenMTInternal.h). These declarations are undocumented Apple interfaces and require compatibility validation on other OS releases.

Build from the checkout root with Xcode command line tools:

```sh
clang -Wall -Wextra -Werror -O2 feasibility/trackpad_probe.c \
  -framework ApplicationServices -framework CoreFoundation \
  -o /private/tmp/trackpad-probe
/private/tmp/trackpad-probe --self-test
/private/tmp/trackpad-probe 60
```

For the live run, keep another application active. Lift all fingers, make a short simultaneous three-finger tap, lift all fingers again, then trace a path with one finger. Avoid resting fingers before or after the tap; this minimal detector measures a whole contact episode. Tap duration and movement limits are provisional, not production calibration. A resting contact can extend an episode and cause rejection.

The six synthetic fixtures verify basic recognizer decisions only. The live result proves raw contact observation on this Mac; no intentional three-finger tap was recognized in that recording. An unavailable event tap with no Accessibility grant is expected to require a separate app permission test. SwipeType's permission does not transfer to this command line probe.

The run leaves no daemon, login item, event interceptor, or persistent cursor setting. Logs are local to this directory. See the implementation handoff for remaining acceptance criteria.
