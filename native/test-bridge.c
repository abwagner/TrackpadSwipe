// Exercise the production routing functions with unposted CGEvent objects.
// This test never installs an event tap or sends input to the desktop.
#include "TrackpadBridge.c"
#include <assert.h>
#include <stdio.h>
static int toggles;
static bool gestureEnabled=true;
static bool activate(void) {
    if(!gestureEnabled)return false;
    toggles++;TPSetOverlayActive(!atomic_load(&overlayActive));return true;
}
static void contacts(int count) {
    MTTouch values[4]={0};
    for(int i=0;i<count;i++)values[i].state=4;
    receive(NULL,values,count,0,0);
}
int main(void) {
    activationHandler=activate;
    CGEventRef down=CGEventCreateMouseEvent(NULL,kCGEventLeftMouseDown,CGPointZero,kCGMouseButtonLeft);
    CGEventRef up=CGEventCreateMouseEvent(NULL,kCGEventLeftMouseUp,CGPointZero,kCGMouseButtonLeft);
    CGEventRef move=CGEventCreateMouseEvent(NULL,kCGEventMouseMoved,CGPointZero,kCGMouseButtonLeft);
    assert(down && up && move);
    for(int count=0;count<=4;count++) {
        TPSetOverlayActive(false);consumeLeftUp=false;contacts(count);
        assert(intercept(NULL,kCGEventMouseMoved,move,NULL)==move);
        assert(toggles==0);
        if(count==3)continue;
        assert(intercept(NULL,kCGEventLeftMouseDown,down,NULL)==down);
        assert(intercept(NULL,kCGEventLeftMouseUp,up,NULL)==up);
        assert(toggles==0);
    }
    contacts(3);
    assert(intercept(NULL,kCGEventLeftMouseDown,down,NULL)==NULL && toggles==1);
    assert(intercept(NULL,kCGEventLeftMouseUp,up,NULL)==NULL && !consumeLeftUp);
    assert(intercept(NULL,kCGEventLeftMouseDown,down,NULL)==NULL && toggles==2);
    assert(intercept(NULL,kCGEventLeftMouseUp,up,NULL)==NULL && !consumeLeftUp);
    assert(!atomic_load(&overlayActive));
    gestureEnabled=false;
    assert(intercept(NULL,kCGEventLeftMouseDown,down,NULL)==down && toggles==2);
    assert(intercept(NULL,kCGEventLeftMouseUp,up,NULL)==up);
    gestureEnabled=true;atomic_store(&contactUpdated,now()-0.2);
    assert(intercept(NULL,kCGEventLeftMouseDown,down,NULL)==down && toggles==2);
    contacts(0);assert(TPActiveContactCount()==0);
    TPSetOverlayActive(true);TPSetCapture(true);atomic_store(&heartbeat,now()-2);
    assert(intercept(NULL,kCGEventMouseMoved,move,NULL)==move && !TPIsCapturing());
    CGEventRef escape=CGEventCreateKeyboardEvent(NULL,53,true);
    TPSetCapture(true);
    assert(intercept(NULL,kCGEventKeyDown,escape,NULL)==NULL && !TPIsCapturing());
    CFRelease(down);CFRelease(up);CFRelease(move);CFRelease(escape);
    puts("PASS: production three-finger physical-click routing, paired consumption, stale-frame rejection, Esc, and watchdog release");
    return 0;
}
