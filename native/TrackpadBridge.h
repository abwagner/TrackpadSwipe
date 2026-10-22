#pragma once
#include <stdbool.h>
#include <stdint.h>
typedef struct { int32_t id; float x, y; } TPContact;
typedef void (*TPFrameHandler)(const TPContact *, int, double);
typedef void (*TPReleaseHandler)(int reason);
// Session event tap callbacks run on the main run loop. Return true to consume.
typedef bool (*TPPointerHandler)(int type,double x,double y,double dx,double dy,double timestamp);
typedef bool (*TPActivationHandler)(void);
// reason: 1 Escape, 2 event-tap timeout, 3 main-thread watchdog.
bool TPStart(TPFrameHandler handler);
void TPStop(void);
bool TPInstallEventTap(TPReleaseHandler handler,TPPointerHandler pointerHandler,TPActivationHandler activationHandler);
void TPSetOverlayActive(bool enabled);
void TPRemoveEventTap(void);
void TPSetCapture(bool enabled);
bool TPIsCapturing(void);
void TPHeartbeat(void);
uint64_t TPFrameCount(void);
uint64_t TPDroppedEventCount(void);
const char *TPError(void);
// Zero when no recent raw frame is available; timestamps use the monotonic clock.
int TPActiveContactCount(void);
