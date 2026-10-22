// ABI declarations adapted from OpenMultitouchSupport by Takuto Nakamura.
// Copyright (c) 2019 TakutoNakamura. MIT: licenses/OpenMultitouchSupport-MIT.txt.
#include "TrackpadBridge.h"
#include <ApplicationServices/ApplicationServices.h>
#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <pthread.h>
#include <stdatomic.h>
#include <time.h>

// Undocumented ABI, isolated here; see OpenMultitouchSupport/OpenMTInternal.h.
typedef struct { float x,y; } MTPoint;
typedef struct { MTPoint position,velocity; } MTVector;
typedef struct {
    int frame; double timestamp; int identifier,state,fingerId,handId;
    MTVector normalizedPosition; float total,pressure,angle,majorAxis,minorAxis;
    MTVector absolutePosition; int field14,field15; float density;
} MTTouch;
typedef void (*MTCallback)(void *,MTTouch *,int,double,int);
static void *library,*device;
static void (*regFrame)(void *,MTCallback),(*unregFrame)(void *,MTCallback),(*releaseDevice)(void *);
static int (*startDevice)(void *,int),(*stopDevice)(void *);
static TPFrameHandler frameHandler;
static TPReleaseHandler releaseHandler;
static TPPointerHandler pointerHandler;
static TPActivationHandler activationHandler;
static CFMachPortRef eventTap;
static CFRunLoopSourceRef tapSource;
static atomic_bool capturing=false;
static atomic_bool overlayActive=false;
static bool consumeLeftUp=false;
static atomic_uint_fast64_t frames=0;
static atomic_uint_fast64_t dropped=0;
static _Atomic double heartbeat=0;
static atomic_int contactCount=0;
static _Atomic double contactUpdated=0;
static const char *lastError="Not started";
static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC,&t);return t.tv_sec+t.tv_nsec/1e9; }
static void receive(void *sender,MTTouch *touches,int count,double timestamp,int frame) {
    (void)sender;(void)frame; atomic_fetch_add(&frames,1);
    TPContact contacts[16];int active=0;
    for(int i=0;i<count && active<16;i++) if(touches[i].state==3 || touches[i].state==4) {
        contacts[active++]=(TPContact){touches[i].identifier,touches[i].normalizedPosition.position.x,touches[i].normalizedPosition.position.y};
    }
    atomic_store(&contactCount,active);atomic_store(&contactUpdated,now());
    if(frameHandler) frameHandler(contacts,active,timestamp);
}
bool TPStart(TPFrameHandler handler) {
    if(device) return true;
    library=dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport",RTLD_NOW);
    if(!library){lastError="MultitouchSupport is unavailable";return false;}
    void *(*create)(void)=dlsym(library,"MTDeviceCreateDefault");
    regFrame=dlsym(library,"MTRegisterContactFrameCallback");unregFrame=dlsym(library,"MTUnregisterContactFrameCallback");
    startDevice=dlsym(library,"MTDeviceStart");stopDevice=dlsym(library,"MTDeviceStop");releaseDevice=dlsym(library,"MTDeviceRelease");
    if(!create || !regFrame || !unregFrame || !startDevice || !stopDevice || !releaseDevice){lastError="Unsupported multitouch API";return false;}
    device=create();if(!device){lastError="No default trackpad found";return false;}
    frameHandler=handler;regFrame(device,receive);
    if(startDevice(device,0)!=0){lastError="Trackpad did not start";TPStop();return false;}
    lastError="Ready";return true;
}
void TPStop(void) {
    atomic_store(&contactCount,0);atomic_store(&contactUpdated,0);
    TPSetCapture(false);
    if(device){unregFrame(device,receive);stopDevice(device);releaseDevice(device);device=NULL;}
    // Framework remains loaded: a driver callback may still be unwinding.
}
static CGEventRef intercept(CGEventTapProxy proxy,CGEventType type,CGEventRef event,void *context) {
    (void)proxy;(void)context;
    if(type==kCGEventTapDisabledByTimeout || type==kCGEventTapDisabledByUserInput) {
        TPSetCapture(false);if(releaseHandler)releaseHandler(2);
        if(eventTap)CGEventTapEnable(eventTap,true);return event;
    }
    // Keep click pairs consumed even when click-off also closes the overlay.
    if(type==kCGEventLeftMouseUp && consumeLeftUp) {
        consumeLeftUp=false;atomic_fetch_add(&dropped,1);return NULL;
    }
    // Activation must work while the keyboard is hidden. Consume both halves
    // of a recognized three-finger click so it never clicks the app underneath.
    if(type==kCGEventLeftMouseDown && TPActiveContactCount()==3 && activationHandler) {
        if(activationHandler()) {
            consumeLeftUp=true;atomic_fetch_add(&dropped,1);return NULL;
        }
    }
    if(!atomic_load(&overlayActive))return event;
    if(atomic_load(&capturing) && now()-atomic_load(&heartbeat)>1.5) {
        TPSetCapture(false);if(releaseHandler)releaseHandler(3);return event;
    }
    if(type==kCGEventKeyDown) {
        if(CGEventGetIntegerValueField(event,kCGKeyboardEventKeycode)==53) {
            TPSetCapture(false);if(releaseHandler)releaseHandler(1);return NULL;
        }
        return event;
    }
    bool wasCapturing=atomic_load(&capturing);
    CGPoint p=CGEventGetLocation(event);
    bool consumed=pointerHandler && pointerHandler((int)type,p.x,p.y,
        (double)CGEventGetIntegerValueField(event,kCGMouseEventDeltaX),
        (double)CGEventGetIntegerValueField(event,kCGMouseEventDeltaY),
        CGEventGetTimestamp(event)/1e9);
    if(wasCapturing || atomic_load(&capturing) || consumed) {
        if(type==kCGEventLeftMouseDown)consumeLeftUp=true;
        atomic_fetch_add(&dropped,1);return NULL;
    }
    return event;
}
bool TPInstallEventTap(TPReleaseHandler handler,TPPointerHandler pointer,TPActivationHandler activation) {
    if(eventTap)return true;
    releaseHandler=handler;
    pointerHandler=pointer;
    activationHandler=activation;
    CGEventMask mask=CGEventMaskBit(kCGEventKeyDown)|CGEventMaskBit(kCGEventMouseMoved)|CGEventMaskBit(kCGEventScrollWheel)
        |CGEventMaskBit(kCGEventLeftMouseDown)|CGEventMaskBit(kCGEventLeftMouseUp)|CGEventMaskBit(kCGEventLeftMouseDragged)
        |CGEventMaskBit(kCGEventRightMouseDown)|CGEventMaskBit(kCGEventRightMouseUp)|CGEventMaskBit(kCGEventRightMouseDragged)
        |CGEventMaskBit(kCGEventOtherMouseDown)|CGEventMaskBit(kCGEventOtherMouseUp)|CGEventMaskBit(kCGEventOtherMouseDragged);
    eventTap=CGEventTapCreate(kCGSessionEventTap,kCGHeadInsertEventTap,kCGEventTapOptionDefault,mask,intercept,NULL);
    if(!eventTap){lastError="Accessibility access is needed for pointer capture";return false;}
    tapSource=CFMachPortCreateRunLoopSource(kCFAllocatorDefault,eventTap,0);
    CFRunLoopAddSource(CFRunLoopGetMain(),tapSource,kCFRunLoopCommonModes);CGEventTapEnable(eventTap,true);return true;
}
void TPRemoveEventTap(void) {
    TPSetCapture(false);
    if(tapSource){CFRunLoopRemoveSource(CFRunLoopGetMain(),tapSource,kCFRunLoopCommonModes);CFRelease(tapSource);tapSource=NULL;}
    if(eventTap){CFMachPortInvalidate(eventTap);CFRelease(eventTap);eventTap=NULL;}
}
void TPSetCapture(bool enabled){if(enabled)TPHeartbeat();atomic_store(&capturing,enabled);}
void TPSetOverlayActive(bool enabled){atomic_store(&overlayActive,enabled);if(!enabled)TPSetCapture(false);}
bool TPIsCapturing(void){return atomic_load(&capturing);}
void TPHeartbeat(void){atomic_store(&heartbeat,now());}
uint64_t TPFrameCount(void){return atomic_load(&frames);}
uint64_t TPDroppedEventCount(void){return atomic_load(&dropped);}
const char *TPError(void){return lastError;}
int TPActiveContactCount(void){return now()-atomic_load(&contactUpdated)<=0.15 ? atomic_load(&contactCount) : 0;}
