// ABI declarations adapted from OpenMultitouchSupport by Takuto Nakamura.
// Copyright (c) 2019 TakutoNakamura. MIT: licenses/OpenMultitouchSupport-MIT.txt.
// Temporary, passive hardware probe. Never drops input or requests permissions.
// Private ABI reference: Kyome22/OpenMultitouchSupport OpenMTInternal.h.
#include <ApplicationServices/ApplicationServices.h>
#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <math.h>
#include <pthread.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

typedef struct { float x, y; } ProbePoint;
typedef struct { ProbePoint position, velocity; } ProbeVector;
typedef struct {
    int frame; double timestamp; int identifier, state, fingerId, handId;
    ProbeVector normalizedPosition;
    float total, pressure, angle, majorAxis, minorAxis;
    ProbeVector absolutePosition; int field14, field15; float density;
} Touch;
typedef void (*Callback)(void *, Touch *, int, double, int);
static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
static unsigned frames, points, threeFrames, tapCandidates;
static int peakCount, episodePeak;
static double episodeStart, episodeMotion;
static bool episode, sawThree;
static int ids[16]; static ProbePoint origins[16]; static int originCount;
static float minX=1, minY=1, maxX=0, maxY=0;

static void frameCallback(void *device, Touch *touches, int count, double ts, int frame) {
    (void)device; (void)frame;
    pthread_mutex_lock(&lock);
    frames++;
    int active=0;
    for (int i=0;i<count;i++) if(touches[i].state==3 || touches[i].state==4) active++;
    if(active && !episode) {
        episode=true; episodeStart=ts; episodePeak=0; episodeMotion=0;
        sawThree=false; originCount=0;
    }
    if(active>peakCount) peakCount=active;
    if(active>episodePeak) episodePeak=active;
    if(active==3) {threeFrames++; sawThree=true;}
    for(int i=0;i<count;i++) {
        Touch t=touches[i]; if(t.state!=3 && t.state!=4) continue;
        ProbePoint p=t.normalizedPosition.position; points++;
        minX=fminf(minX,p.x); maxX=fmaxf(maxX,p.x);
        minY=fminf(minY,p.y); maxY=fmaxf(maxY,p.y);
        int j=0; while(j<originCount && ids[j]!=t.identifier) j++;
        if(j==originCount && originCount<16) {ids[j]=t.identifier; origins[j]=p; originCount++;}
        if(j<originCount) episodeMotion=fmax(episodeMotion,hypot(p.x-origins[j].x,p.y-origins[j].y));
    }
    if(!active && episode) {
        double duration=ts-episodeStart;
        bool candidate=sawThree && episodePeak==3 && duration>=0.025 && duration<=0.35 && episodeMotion<0.035;
        if(candidate) tapCandidates++;
        printf("CONTACT_END fingers=%d duration=%.3f max_motion=%.4f three_finger_tap=%s\n",
            episodePeak,duration,episodeMotion,candidate?"YES":"no"); fflush(stdout);
        episode=false;
    }
    pthread_mutex_unlock(&lock);
}
static CGEventRef passThrough(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *ctx) {
    (void)proxy; (void)type; (void)ctx; return event;
}
static void fixture(int count, double ts, float displacement) {
    Touch t[4]={0};
    for(int i=0;i<count;i++) {
        t[i].identifier=i; t[i].state=4;
        t[i].normalizedPosition.position=(ProbePoint){0.2f+i*0.2f+displacement,0.5f};
    }
    frameCallback(NULL,t,count,ts,0);
}
static int selfTest(void) {
    fixture(3,1,0); fixture(3,1.10,0.001); fixture(0,1.15,0);
    assert(tapCandidates==1);
    fixture(3,2,0); fixture(3,2.1,0.12); fixture(0,2.2,0);
    assert(tapCandidates==1);
    fixture(3,3,0); fixture(0,3.8,0);
    assert(tapCandidates==1);
    fixture(4,4,0); fixture(3,4.1,0); fixture(0,4.2,0);
    assert(tapCandidates==1);
    fixture(1,5,0); fixture(1,5.1,0.2); fixture(0,5.2,0);
    assert(tapCandidates==1);
    fixture(1,6,0); fixture(2,6.02,0); fixture(3,6.04,0); fixture(0,6.15,0);
    assert(tapCandidates==2);
    puts("SELF_TEST PASS: tap, swipe rejection, hold rejection, four-finger rejection, one-finger rejection, staggered arrival");
    return 0;
}
int main(int argc, char **argv) {
    setbuf(stdout,NULL);
    if(argc>1 && !strcmp(argv[1],"--self-test")) return selfTest();
    int seconds=argc>1?atoi(argv[1]):45;
    if(seconds<1 || seconds>120) return 2;
    printf("ABI touch_size=%zu accessibility=%s\n",sizeof(Touch),AXIsProcessTrusted()?"granted":"not_granted_to_probe");
    CGEventMask mask=CGEventMaskBit(kCGEventMouseMoved)|CGEventMaskBit(kCGEventLeftMouseDown)|CGEventMaskBit(kCGEventScrollWheel);
    CFMachPortRef tap=CGEventTapCreate(kCGSessionEventTap,kCGHeadInsertEventTap,kCGEventTapOptionDefault,mask,passThrough,NULL);
    printf("EVENT_TAP_CREATE=%s (not installed; no input suppressed)\n",tap?"PASS":"UNAVAILABLE");
    if(tap) {CFMachPortInvalidate(tap); CFRelease(tap);}
    void *lib=dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport",RTLD_NOW);
    if(!lib) {printf("FRAMEWORK_FAIL %s\n",dlerror()); return 3;}
    void *(*create)(void)=dlsym(lib,"MTDeviceCreateDefault");
    void (*reg)(void*,Callback)=dlsym(lib,"MTRegisterContactFrameCallback");
    void (*unreg)(void*,Callback)=dlsym(lib,"MTUnregisterContactFrameCallback");
    int (*start)(void*,int)=dlsym(lib,"MTDeviceStart");
    int (*stop)(void*)=dlsym(lib,"MTDeviceStop");
    void (*release)(void*)=dlsym(lib,"MTDeviceRelease");
    if(!create || !reg || !unreg || !start || !stop || !release) {puts("SYMBOL_FAIL");return 4;}
    void *device=create(); if(!device){puts("DEVICE_FAIL");return 5;}
    reg(device,frameCallback); int status=start(device,0);
    printf("DEVICE_START=%d READY seconds=%d\n",status,seconds);
    CFRunLoopRunInMode(kCFRunLoopDefaultMode,seconds,false);
    unreg(device,frameCallback); stop(device); release(device);
    pthread_mutex_lock(&lock);
    printf("SUMMARY frames=%u points=%u peak_fingers=%d three_finger_frames=%u tap_candidates=%u x_range=%.3f..%.3f y_range=%.3f..%.3f\n",frames,points,peakCount,threeFrames,tapCandidates,minX,maxX,minY,maxY);
    pthread_mutex_unlock(&lock);
    return 0;
}
