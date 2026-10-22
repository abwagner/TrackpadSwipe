import AppKit
import ApplicationServices
import Carbon

private var controller: AppController?
private func receiveFrame(_ raw: UnsafePointer<TPContact>?, _ count: Int32, _ time: Double) {
    let contacts: [Contact] = (0..<Int(count)).compactMap { i in
        guard let c=raw?[i],c.x.isFinite,c.y.isFinite else {return nil}
        return Contact(id:Int(c.id),point:PadPoint(x:Double(c.x),y:1-Double(c.y)))
    }
    DispatchQueue.main.async {controller?.frame(contacts,time:time)}
}
private func activateThreeFingerClick()->Bool {controller?.activationClick() ?? false}
private func receivePointer(_ type:Int32,_ x:Double,_ y:Double,_ dx:Double,_ dy:Double,_ time:Double)->Bool {
    controller?.pointerEvent(type:Int(type),screenPoint:PadPoint(x:x,y:y),dx:dx,dy:dy,time:time) ?? false
}
private func captureReleased(_ reason: Int32) {
    DispatchQueue.main.async {controller?.hide(reason: reason==1 ? "Released with Escape" : "Capture released by watchdog")}
}
private func hotkeyEvent(_ next: EventHandlerCallRef?,_ event: EventRef?,_ data: UnsafeMutableRawPointer?) -> OSStatus {
    controller?.intent("toggle",source:"shortcut");return noErr
}

final class KeyboardPanel: NSPanel {
    override var canBecomeKey: Bool {false}
    override var canBecomeMain: Bool {false}
}
final class FlippedDocumentView:NSView {override var isFlipped:Bool {true}}
// Measurements are in keyboard design coordinates; selected fonts stay in screen points.
struct SuggestionLayout {
    let scale:CGFloat
    let font:NSFont
    let cells:[NSRect]
    let size:NSSize
    let viewport:PointerViewport
    init(words:[String],scale:CGFloat,fontName:String,fontSize:CGFloat,maxWidth:CGFloat) {
        self.scale=scale
        let font:NSFont
        let base=NSFont.systemFont(ofSize:fontSize/scale,weight:.medium)
        switch fontName {
        case "Rounded":font=NSFont(descriptor:base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor,size:fontSize/scale) ?? base
        case "Monospaced":font = .monospacedSystemFont(ofSize:fontSize/scale,weight:.medium)
        default:font=base
        }
        self.font=font
        // Keep slot widths fixed. Add text lines only when a prediction needs them.
        let letterWidth="abcdefghijklmnopqrstuvwxyz".map {ceil((String($0) as NSString).size(withAttributes:[.font:font]).width)}.max() ?? font.pointSize
        let fixedWidth=letterWidth*10+20/scale
        let widths=Array(repeating:fixedWidth,count:5)
        let gap:CGFloat=4
        let available=maxWidth/scale-32
        let rowWidth=min(available,max(708,widths.reduce(0,+)+gap*4))
        let style=NSMutableParagraphStyle();style.lineBreakMode = .byCharWrapping
        let textWidth=min(rowWidth,fixedWidth)-12/scale
        let labels=words.isEmpty ? ["Ag"] : words
        let textHeight=labels.map {word in
            ceil((word as NSString).boundingRect(with:NSSize(width:textWidth,height:.greatestFiniteMagnitude),options:[.usesLineFragmentOrigin,.usesFontLeading],attributes:[.font:font,.paragraphStyle:style]).height)
        }.max() ?? 0
        let cellHeight=max(54.24,textHeight+12/scale)
        var frames:[NSRect]=[];var x:CGFloat=16;var y:CGFloat=65.46
        for width in widths {
            let w=max(60,min(rowWidth,width))
            if x>16 && x+w>16+rowWidth {x=16;y+=cellHeight+gap}
            frames.append(NSRect(x:x,y:y,width:w,height:cellHeight));x+=w+gap
        }
        cells=frames
        let extra=max(0,y+cellHeight-119.70)
        size=NSSize(width:rowWidth+32,height:470+extra)
        viewport=PointerViewport(minX:(size.width-708)/2,minY:58+extra,width:708,height:364)
    }
    func screenViewport(panel:NSRect,desktopTop:CGFloat)->PointerViewport {
        PointerViewport(minX:panel.minX+viewport.minX*scale,minY:desktopTop-panel.maxY+viewport.minY*scale,width:viewport.width*scale,height:viewport.height*scale)
    }

}

final class KeyboardCanvas: NSView {
    weak var owner: AppController?
    var layout=SuggestionLayout(words:[],scale:0.5,fontName:"System",fontSize:12,maxWidth:1200)
    override var isFlipped: Bool {true}
    override func acceptsFirstMouse(for event:NSEvent?)->Bool {true}
    override var mouseDownCanMoveWindow: Bool {true}
    override func mouseDown(with event:NSEvent) {
        owner?.blockedKeyboardClicked()
    }
    override func draw(_ dirtyRect:NSRect) {
        NSGraphicsContext.saveGraphicsState()
        defer {NSGraphicsContext.restoreGraphicsState()}
        let transform=NSAffineTransform();transform.scale(by:layout.scale);transform.concat()
        let bounds=NSRect(origin:.zero,size:layout.size)
        NSColor(calibratedWhite:0.075,alpha:0.98).setFill()
        NSBezierPath(roundedRect:bounds,xRadius:18,yRadius:18).fill()
        let viewport=layout.viewport
        let area=NSRect(x:viewport.minX,y:viewport.minY,width:viewport.width,height:viewport.height)
        func rect(_ k:PadKey) -> NSRect {
            NSRect(x:area.minX+CGFloat(k.x)*area.width+2,y:area.minY+CGFloat(k.y)*area.height+2,
                   width:CGFloat(k.width)*area.width-4,height:CGFloat(k.height)*area.height-4)
        }
        func text(_ string:String,_ frame:NSRect,_ size:CGFloat=16,_ color:NSColor = .white) {
            let style=NSMutableParagraphStyle();style.alignment = .center
            (string as NSString).draw(in:frame,withAttributes:[.font:NSFont.systemFont(ofSize:size,weight:.medium),.foregroundColor:color,.paragraphStyle:style])
        }
        text(owner?.testMode == true ? "CAPTURE TEST · no text will be entered" : "TrackpadSwipe",NSRect(x:12,y:12,width:bounds.width-24,height:22),17)
        text(owner?.banner ?? "",NSRect(x:12,y:35,width:bounds.width-24,height:18),12,.lightGray)
        let guesses=owner?.guesses ?? []
        for (i,r) in layout.cells.enumerated() {
            let label=i<guesses.count ? guesses[i].word : "·"
            (i==0 ? NSColor.systemBlue.withAlphaComponent(0.4) : NSColor.darkGray).setFill()
            NSBezierPath(roundedRect:r,xRadius:7,yRadius:7).fill()
            let style=NSMutableParagraphStyle();style.alignment = .center;style.lineBreakMode = .byCharWrapping
            let value=NSAttributedString(string:label,attributes:[.font:layout.font,.foregroundColor:NSColor.white,.paragraphStyle:style])
            let width=r.width-12/layout.scale
            let measured=value.boundingRect(with:NSSize(width:width,height:.greatestFiniteMagnitude),options:[.usesLineFragmentOrigin,.usesFontLeading])
            value.draw(with:NSRect(x:r.minX+6/layout.scale,y:r.midY-ceil(measured.height)/2,width:width,height:ceil(measured.height)),options:[.usesLineFragmentOrigin,.usesFontLeading])
        }
        for key in KeyboardGeometry.keys(symbols:owner?.keyboardSymbols ?? false)+KeyboardGeometry.commands {
            let r=rect(key)
            let highlighted=owner?.finger.map {key.contains($0)} ?? false
            (highlighted ? NSColor.systemBlue : NSColor(calibratedWhite:0.21,alpha:1)).setFill()
            NSBezierPath(roundedRect:r,xRadius:8,yRadius:8).fill()
            text(key.label=="Fn" && owner?.keyboardSymbols == true ? "ABC" : (key.label.count==1 ? key.label.uppercased() : key.label),NSRect(x:r.minX,y:r.midY-12,width:r.width,height:26),key.label.count==1 ? 23 : 17)
        }
        let points=owner?.path ?? []
        if let first=points.first {
            let line=NSBezierPath();line.lineWidth=3;line.lineCapStyle = .round
            line.move(to:NSPoint(x:area.minX+first.x*area.width,y:area.minY+first.y*area.height))
            for p in points.dropFirst() {line.line(to:NSPoint(x:area.minX+p.x*area.width,y:area.minY+p.y*area.height))}
            NSColor.systemCyan.setStroke();line.stroke()
        }
        if let p=owner?.finger {
            let center=NSPoint(x:area.minX+p.x*area.width,y:area.minY+p.y*area.height)
            let cursor=UserDefaults.standard.string(forKey:"typingCursor") ?? "Dot"
            if cursor=="Crosshair" {
                let cross=NSBezierPath()
                cross.move(to:NSPoint(x:center.x-10,y:center.y));cross.line(to:NSPoint(x:center.x+10,y:center.y))
                cross.move(to:NSPoint(x:center.x,y:center.y-10));cross.line(to:NSPoint(x:center.x,y:center.y+10))
                NSColor.white.setStroke();cross.lineWidth=4;cross.stroke()
                NSColor.systemBlue.setStroke();cross.lineWidth=2;cross.stroke()
            } else if cursor != "Hidden" {
                let dot=NSBezierPath(ovalIn:NSRect(x:center.x-8,y:center.y-8,width:16,height:16))
                if cursor != "Ring" {NSColor.systemBlue.setFill();dot.fill()}
                NSColor.white.withAlphaComponent(0.9).setStroke();dot.lineWidth=cursor=="Ring" ? 4 : 1.5;dot.stroke()
                if cursor=="Ring" {NSColor.systemBlue.setStroke();dot.lineWidth=2;dot.stroke()}
            }
        }
        text(owner?.keyboardSymbols == true ? "Click to enter a symbol · ABC returns to letters · Esc closes" : "Click a starting key · trace · click again to enter · Esc cancels",NSRect(x:8,y:bounds.height-42,width:bounds.width-16,height:18),12,.lightGray)

    }
}

// All remote Accessibility operations run on the dedicated queue below.
// Every created AX proxy has a finite messaging timeout; no editor RPC runs in the tap.
func correctionOwnerMatches(pid:pid_t,field:AXUIElement,committedPID:pid_t?,committedField:AXUIElement?)->Bool {
    committedPID==pid && committedField.map({CFEqual($0,field)}) == true
}

// Cancellation and the decision to start a write share one short critical section.
// Once a write has begun, it may complete; cancellation never waits on an AX RPC.
final class EditorTicket {
    private let lock=NSLock()
    private var cancelled=false
    func cancel() {lock.lock();cancelled=true;lock.unlock()}
    func beginWrite()->Bool {lock.lock();defer{lock.unlock()};return !cancelled}
}

// One bounded UTF-16 reader serves context, correction, and post-write checks.
struct EditorTextReader {
    var parameterized:(CFRange)->String?
    var value:()->String?
    func read(_ range:CFRange)->String? {
        guard range.location>=0,range.length>=0 else{return nil}
        if let text=parameterized(range),text.utf16.count==range.length {return text}
        guard let text=value() else{return nil}
        let string=text as NSString
        guard range.location<=string.length,range.length<=string.length-range.location else{return nil}
        return string.substring(with:NSRange(location:range.location,length:range.length))
    }
}

struct EditorKeyDestination {
    var frontmostPID:()->pid_t?
    var originalFieldFocused:()->Bool
    var selection:()->CFRange?
    func matches(pid:pid_t,expected:CFRange)->Bool {
        guard frontmostPID()==pid,originalFieldFocused(),let actual=selection() else{return false}
        return actual.location==expected.location && actual.length==expected.length
    }
}

enum EditorKeyInput {
    static func required(bundleID:String?)->Bool {
        // These editors need their normal input pipeline rather than AX text setters.
        guard let bundleID=bundleID else{return false}
        return ["com.openai.codex","com.tdesktop.Telegram"].contains(bundleID)
    }
    static func deliver(ticket:EditorTicket,validate:()->Bool,emit:()->Void)->Bool {
        guard validate(),ticket.beginWrite() else{return false}
        emit();return true
    }
}

struct EditorTransaction {
    var matches:()->Bool
    var caret:()->CFRange?
    var read:(CFRange)->String?
    var select:(CFRange)->Bool
    var insert:(String)->Bool
    var advancesCaret=false
    var verify:(String,CFRange)->Bool = {_,_ in true}
    func edit(text:String,backspace:Bool=false,deleteWord:Bool=false,ticket:EditorTicket,old:String?=nil,expected:CFRange?=nil,word:Bool=false)->Bool {
        guard matches(),let actual=caret() else{return false}
        var selection=actual
        if let old=old,let expected=expected {
            guard actual.location==expected.location,actual.length==0 else{return false}
            selection=CFRange(location:actual.location-old.utf16.count,length:old.utf16.count)
            guard selection.location>=0,read(selection)==old else{return false}
        } else if backspace && selection.length==0 {
            guard selection.location>0,let prefix=read(CFRange(location:0,length:selection.location)),let last=prefix.last else{return false}
            selection.length=deleteWord ? WordDeletion.utf16Length(in:prefix) : String(last).utf16.count;selection.location-=selection.length
        }
        var payload=text
        if word {
            if let old=old {
                // A correction owns the separator of the original insertion.
                payload=(old.hasPrefix(" ") ? " " : "")+text
            } else if selection.location>0 {
                guard let preceding=read(CFRange(location:selection.location-1,length:1)) else{return false}
                if preceding != "-" && !preceding.unicodeScalars.allSatisfy({CharacterSet.whitespacesAndNewlines.contains($0)}) {payload=" "+text}
            }
        }
        // The claim is the commit boundary. Cancellation completed before it
        // prevents all setters; an AX call already in flight cannot be revoked.
        guard ticket.beginWrite(),select(selection) else{return false}
        guard ticket.beginWrite() else{return false}
        if insert(payload) {
            if advancesCaret {return true}
            // A successful mutation with an unknown postcondition is not a
            // rejected write. Do not restore a stale pre-mutation selection.
            guard verify(payload,CFRange(location:selection.location,length:payload.utf16.count)) else{return false}
            // AXSelectedText replaces text but need not advance/collapse the
            // editor selection. Explicitly put the caret after the inserted UTF-16.
            guard ticket.beginWrite() else{return true}
            return select(CFRange(location:selection.location+payload.utf16.count,length:0))
        }
        _ = select(actual)
        return false
    }
}

enum EditorAccess {
    static func capture(pid:pid_t)->AXUIElement? {
        dispatchPrecondition(condition:.notOnQueue(.main))
        let app=AXUIElementCreateApplication(pid);AXUIElementSetMessagingTimeout(app,0.05)
        var value:CFTypeRef?
        guard AXUIElementCopyAttributeValue(app,kAXFocusedUIElementAttribute as CFString,&value) == .success,
              let value=value,CFGetTypeID(value)==AXUIElementGetTypeID() else{return nil}
        let field=unsafeBitCast(value,to:AXUIElement.self);AXUIElementSetMessagingTimeout(field,0.05)
        var role:CFTypeRef?,subrole:CFTypeRef?
        guard AXUIElementCopyAttributeValue(field,kAXRoleAttribute as CFString,&role) == .success,
              AXUIElementCopyAttributeValue(field,kAXSubroleAttribute as CFString,&subrole) != .cannotComplete,
              (subrole as? String) != "AXSecureTextField",["AXTextField","AXTextArea","AXComboBox"].contains(role as? String ?? "") else{return nil}
        return field
    }
    static func matches(pid:pid_t,field:AXUIElement)->Bool {
        guard let current=capture(pid:pid) else{return false};return CFEqual(current,field)
    }
    static func caret(_ field:AXUIElement)->CFRange? {
        dispatchPrecondition(condition:.notOnQueue(.main))
        var value:CFTypeRef?
        guard AXUIElementCopyAttributeValue(field,kAXSelectedTextRangeAttribute as CFString,&value) == .success,
              let value=value,CFGetTypeID(value)==AXValueGetTypeID() else{return nil}
        var range=CFRange();guard AXValueGetValue(unsafeBitCast(value,to:AXValue.self),.cfRange,&range) else{return nil};return range
    }
    static func edit(pid:pid_t,field:AXUIElement,text:String,backspace:Bool=false,deleteWord:Bool=false,ticket:EditorTicket,old:String?=nil,expected:CFRange?=nil,keyboardInput:Bool=false,word:Bool=false)->(written:Bool,detail:String,text:String) {
        var detail="Destination, selection, or cancellation validation failed"
        var insertedText=text
        var selected:CFRange?
        func sameRange(_ a:CFRange?,_ b:CFRange)->Bool {a.map{$0.location==b.location && $0.length==b.length} ?? false}
        func sendKeys(_ replacement:String,key:CGKeyCode?=nil,flags:CGEventFlags=[])->Bool {
            let source=CGEventSource(stateID:.hidSystemState)
            guard let down=CGEvent(keyboardEventSource:source,virtualKey:key ?? 0,keyDown:true),
                  let up=CGEvent(keyboardEventSource:source,virtualKey:key ?? 0,keyDown:false) else{return false}
            down.flags=flags;up.flags=flags
            if key==nil {
                let units=Array(replacement.utf16)
                units.withUnsafeBufferPointer {buffer in
                    down.keyboardSetUnicodeString(stringLength:buffer.count,unicodeString:buffer.baseAddress)
                    up.keyboardSetUnicodeString(stringLength:buffer.count,unicodeString:buffer.baseAddress)
                }
            }
            return EditorKeyInput.deliver(ticket:ticket,validate:{
                // Revalidate immediately before posting. Delivery is restricted to
                // this process; there is no global HID posting or main-queue hop.
                guard let selected=selected else{return false}
                return EditorKeyDestination(frontmostPID:{NSWorkspace.shared.frontmostApplication?.processIdentifier},
                    originalFieldFocused:{matches(pid:pid,field:field)},selection:{caret(field)}).matches(pid:pid,expected:selected)
            },emit:{down.postToPid(pid);up.postToPid(pid)})
        }
        if keyboardInput && backspace {
            selected=caret(field)
            let written=sendKeys("",key:51,flags:deleteWord ? .maskAlternate : [])
            return (written,written ? "Typing events sent to editor" : detail,"")
        }
        let reader=EditorTextReader(parameterized:{ requested in
            var requested=requested,value:CFTypeRef?
            guard let range=AXValueCreate(.cfRange,&requested),
                  AXUIElementCopyParameterizedAttributeValue(field,kAXStringForRangeParameterizedAttribute as CFString,range,&value) == .success else{return nil}
            return value as? String
        },value:{
            var value:CFTypeRef?
            guard AXUIElementCopyAttributeValue(field,kAXValueAttribute as CFString,&value) == .success else{return nil}
            return value as? String
        })
        let operation=EditorTransaction(matches:{matches(pid:pid,field:field)},caret:{caret(field)},read:reader.read,
            select:{ requested in
            var requested=requested
            if keyboardInput,sameRange(caret(field),requested) {selected=requested;return true}
            guard let range=AXValueCreate(.cfRange,&requested) else{return false}
            let result=AXUIElementSetAttributeValue(field,kAXSelectedTextRangeAttribute as CFString,range)
            if result != .success {detail="Set text selection failed (AX \(result.rawValue))"}
            if result == .success {selected=requested}
            return result == .success
        },insert:{ replacement in
            insertedText=replacement
            if keyboardInput {return sendKeys(replacement)}
            let result=AXUIElementSetAttributeValue(field,kAXSelectedTextAttribute as CFString,replacement as CFString)
            if result != .success {detail="Insert selected text failed (AX \(result.rawValue))"}
            guard result == .success else{return false}
            return true
        },advancesCaret:keyboardInput,verify:{ replacement,range in
            guard reader.read(range)==replacement else {
                detail="Editor accepted the write but its text could not be verified";return false
            }
            return true
        })
        let written=operation.edit(text:text,backspace:backspace,deleteWord:deleteWord,ticket:ticket,old:old,expected:expected,word:word)
        return (written,written ? (keyboardInput ? "Typing events sent to editor" : "Inserted and verified") : detail,insertedText)
    }

}

final class AppController: NSObject,NSApplicationDelegate {
    var session=SessionMachine()
    var guesses:[WordGuess]=[] {
        didSet {
            if panel != nil,session.phase != .idle {placeKeyboard(on:panel.screen ?? NSScreen.main!,preserveOrigin:true)}
        }
    }
    var path:[PadPoint]=[]
    var finger:PadPoint?
    var banner="Ready"
    var keyboardSymbols=false
    var testMode=false
    private var statusItem:NSStatusItem!
    private var panel:KeyboardPanel!
    private var canvas:KeyboardCanvas!
    private var setup:NSWindow!
    private var permissionNotice:NSView?
    private var settingsFooter:NSTextField!
    private var settingsDocument:NSView!
    private var placementDone:NSButton!
    private var shortcutLabel:NSTextField!
    private var sizeLabel:NSTextField!
    private var suggestionSizeLabel:NSTextField!
    private var sensitivityLabel:NSTextField!
    private var positionChoice:NSPopUpButton!
    private var previewing=false
    private var movingProgrammatically=false
    private let positionNames=["Bottom center","Center","Bottom left","Bottom right","Top center","Next to cursor","Custom"]
    private var rawReady=false
    private var lastContacts=0
    private var clickStroke=ClickStroke()
    private var cursorHidden=false
    private var pointerReady=false
    private var receivedURL=false
    private var generation=0
    private var sessionEpoch=0
    private var expiry=Date.distantPast
    private var target:NSRunningApplication?
    private var lastExternal:NSRunningApplication?
    private var focusedElement:AXUIElement?
    private var lastCommit:String?
    private var commitOwner:AXUIElement?
    private var commitPID:pid_t?
    private let accessibilityQueue=DispatchQueue(label:"TrackpadSwipe.accessibility",qos:.userInitiated)
    private var lastEditorResult="No insertion attempted"
    private var editorMessageUntil=Date.distantPast
    private var targetActionPending=false
    private var targetRequest=0
    private var editorTicket:EditorTicket?
    private var nextTargetCheck=Date.distantPast
    private var targetValidationBusy=false
    private var expectedCaret:CFRange?
    private var decoder:PathDecoder?
    private let decoderQueue=DispatchQueue(label:"TrackpadType.decoder",qos:.userInitiated)
    private var heartbeatTimer:Timer?
    private var hotkey:EventHotKeyRef?
    private var handler:EventHandlerRef?
    private var recording:Any?
    private var observers:[NSObjectProtocol]=[]
    private var testStart=Date.distantPast
    private var testFrames:UInt64=0
    private var testDropped:UInt64=0
    private var lastTest:[String:Any]=[:]
    private var nextStatusWrite=Date.distantPast
    private var nextAccessRefresh=Date.distantPast
    private var nextLivePrediction=Date.distantPast
    private var livePredictionBusy=false
    private var livePredictionPointCount=0
    private var recognizingFinal=false
    private let statusURL=FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/TrackpadType/status.json")

    func applicationDidFinishLaunching(_ notification:Notification) {
        UserDefaults.standard.register(defaults:["threeFingerTap":true,"keyboardZoom":1.0,"trackingSensitivity":1.0,"keyboardPosition":"Next to cursor","suggestionFontSize":12.0,"suggestionFont":"System","typingCursor":"Dot"])
        if UserDefaults.standard.object(forKey:"threeFingerClick") == nil {
            UserDefaults.standard.set(UserDefaults.standard.bool(forKey:"threeFingerTap"),forKey:"threeFingerClick")
        }
        // Apply the new cursor-adjacent default once, including existing installs.
        if !UserDefaults.standard.bool(forKey:"cursorPlacementDefaultApplied") {
            UserDefaults.standard.set("Next to cursor",forKey:"keyboardPosition")
            UserDefaults.standard.set(true,forKey:"cursorPlacementDefaultApplied")
        }
        lastExternal=NSWorkspace.shared.frontmostApplication
        if lastExternal?.processIdentifier==getpid() {lastExternal=nil}
        buildMenu();buildPanel();buildSetup()
        rawReady=TPStart(receiveFrame)
        if !rawReady {banner=String(cString:TPError())}
        loadDecoder();refreshCaptureReadiness()
        var eventSpec=EventTypeSpec(eventClass:OSType(kEventClassKeyboard),eventKind:UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(),hotkeyEvent,1,&eventSpec,nil,&handler)
        registerSavedShortcut()
        let center=NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName:NSWorkspace.didActivateApplicationNotification,object:nil,queue:.main) { [weak self] n in
            guard let self=self,let app=n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,app.processIdentifier != getpid() else{return}
            self.lastExternal=app
            if self.session.phase != .idle,app.processIdentifier != self.target?.processIdentifier {
                if self.clickStroke.active {self.hide(reason:"Destination changed")}
                else {self.cancelEditorAction();self.target=nil;self.focusedElement=nil;self.clearCorrection()}
            }
        })
        observers.append(center.addObserver(forName:NSWorkspace.willSleepNotification,object:nil,queue:.main) { [weak self] _ in
            self?.hide(reason:"Sleeping");TPStop()
        })
        observers.append(center.addObserver(forName:NSWorkspace.didWakeNotification,object:nil,queue:.main) { [weak self] _ in
            self?.rawReady=TPStart(receiveFrame)
        })
        observers.append(center.addObserver(forName:NSWorkspace.sessionDidResignActiveNotification,object:nil,queue:.main) { [weak self] _ in self?.hide(reason:"Session inactive") })
        heartbeatTimer=Timer.scheduledTimer(withTimeInterval:0.1,repeats:true) { [weak self] _ in self?.tick() }
        DispatchQueue.main.asyncAfter(deadline:.now()+0.15) { [weak self] in
            guard let self=self,!self.receivedURL else{return}
            self.intent("show",source:"app launch")
        }
        updateStatus()
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool {false}
    func applicationShouldHandleReopen(_ sender:NSApplication,hasVisibleWindows flag:Bool)->Bool {intent("show",source:"app launch");return false}
    func application(_ application:NSApplication,open urls:[URL]) {
        receivedURL=true
        for url in urls where ["trackpadswipe","trackpadtype"].contains(url.scheme?.lowercased() ?? "") {
            let action=url.host?.lowercased() ?? ""
            if ["show","hide","toggle","test"].contains(action) {intent(action,source:"URL")}
        }
    }
    func applicationWillTerminate(_ notification:Notification) {
        hide(reason:"Quit");TPRemoveEventTap();TPStop()
        if let hotkey=hotkey {UnregisterEventHotKey(hotkey)}
        if let handler=handler {RemoveEventHandler(handler)}
        if let recording=recording {NSEvent.removeMonitor(recording)}
        heartbeatTimer?.invalidate()
    }
    private func buildMenu() {
        statusItem=NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
        statusItem.button?.image=NSImage(systemSymbolName:"keyboard",accessibilityDescription:"TrackpadSwipe")
        let menu=NSMenu()
        for (title,selector) in [("Settings…",#selector(showSetup)),("Quit",#selector(quit))] {
            let item=NSMenuItem(title:title,action:selector,keyEquivalent:title=="Quit" ? "q" : ",");item.target=self;menu.addItem(item)
        }
        statusItem.menu=menu
        let mainMenu=NSMenu()
        let appItem=NSMenuItem(title:"TrackpadSwipe",action:nil,keyEquivalent:"")
        appItem.submenu=menu.copy() as? NSMenu
        mainMenu.addItem(appItem);NSApp.mainMenu=mainMenu
    }
    private func buildPanel() {
        panel=KeyboardPanel(contentRect:NSRect(x:0,y:0,width:740,height:470),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
        panel.level = .floating;panel.isOpaque=false;panel.backgroundColor = .clear
        panel.hasShadow=true;panel.hidesOnDeactivate=false;panel.ignoresMouseEvents=true
        panel.title="TrackpadSwipe Keyboard"
        panel.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary]
        canvas=KeyboardCanvas(frame:NSRect(x:0,y:0,width:740,height:470));canvas.owner=self;panel.contentView=canvas
        canvas.autoresizingMask=[.width,.height]
        placementDone=NSButton(title:"Done",target:self,action:#selector(finishPlacement))
        placementDone.frame=NSRect(x:canvas.bounds.width-76,y:8,width:66,height:24)
        placementDone.autoresizingMask=[.minXMargin];placementDone.isHidden=true
        canvas.addSubview(placementDone)
        panel.isMovableByWindowBackground=true
        observers.append(NotificationCenter.default.addObserver(forName:NSWindow.didMoveNotification,object:panel,queue:.main) { [weak self] _ in self?.rememberCustomPosition() })
    }
    private func buildSetup() {
        let height=min(700,(NSScreen.main?.visibleFrame.height ?? 900)-100)
        setup=NSWindow(contentRect:NSRect(x:0,y:0,width:540,height:height),styleMask:[.titled,.closable,.miniaturizable],backing:.buffered,defer:false)
        setup.title="TrackpadSwipe Settings";setup.isReleasedWhenClosed=false
        let scroll=NSScrollView(frame:setup.contentView!.bounds)
        scroll.autoresizingMask=[.width,.height];scroll.hasVerticalScroller=true;scroll.drawsBackground=false
        setup.contentView=scroll
        let content=FlippedDocumentView(frame:NSRect(x:0,y:0,width:540,height:700))
        scroll.documentView=content;settingsDocument=content
        @discardableResult func label(_ parent:NSView,_ text:String,_ x:CGFloat,_ y:CGFloat,_ width:CGFloat,_ size:CGFloat=13,_ color:NSColor = .labelColor,_ height:CGFloat=20)->NSTextField {
            let field=NSTextField(wrappingLabelWithString:text)
            field.frame=NSRect(x:x,y:y,width:width,height:height)
            field.font = .systemFont(ofSize:size);field.textColor=color;parent.addSubview(field);return field
        }
        func button(_ parent:NSView,_ title:String,_ x:CGFloat,_ y:CGFloat,_ width:CGFloat,_ action:Selector) {
            let button=NSButton(title:title,target:self,action:action)
            button.frame=NSRect(x:x,y:y,width:width,height:28);parent.addSubview(button)
        }
        func card(_ title:String,_ y:CGFloat,_ height:CGFloat)->NSView {
            let view=FlippedDocumentView(frame:NSRect(x:24,y:y,width:492,height:height))
            view.wantsLayer=true;view.layer?.cornerRadius=12;view.layer?.borderWidth=0.5
            view.layer?.backgroundColor=NSColor.controlBackgroundColor.cgColor;view.layer?.borderColor=NSColor.separatorColor.cgColor
            content.addSubview(view)
            label(view,title,16,14,460,14).font = .systemFont(ofSize:14,weight:.semibold)
            return view
        }
        label(content,"TrackpadSwipe",24,24,492,23,.labelColor,30).font = .systemFont(ofSize:23,weight:.semibold)
        label(content,"Click a key, trace a word, then click again to enter it.",24,64,492,13,.secondaryLabelColor)
        let keyboard=card("Keyboard",100,200)
        label(keyboard,"Size",16,48,200)
        sizeLabel=label(keyboard,"",376,48,100);sizeLabel.alignment = .right
        sizeLabel.font = .monospacedDigitSystemFont(ofSize:13,weight:.regular)
        let size=NSSlider(value:UserDefaults.standard.double(forKey:"keyboardZoom"),minValue:0.5,maxValue:4,target:self,action:#selector(sizeChanged(_:)))
        size.frame=NSRect(x:16,y:76,width:460,height:20);size.isContinuous=true
        size.identifier=NSUserInterfaceItemIdentifier("keyboardSize");size.setAccessibilityLabel("Keyboard size");keyboard.addSubview(size)
        label(keyboard,"50%",16,102,100,11,.secondaryLabelColor)
        label(keyboard,"400%",376,102,100,11,.secondaryLabelColor).alignment = .right
        label(keyboard,"Location",16,136,76)
        positionChoice=NSPopUpButton(frame:NSRect(x:96,y:130,width:228,height:28),pullsDown:false)
        positionChoice.addItems(withTitles:positionNames)
        positionChoice.selectItem(withTitle:UserDefaults.standard.string(forKey:"keyboardPosition") ?? "Next to cursor")
        positionChoice.target=self;positionChoice.action=#selector(positionChanged(_:));positionChoice.setAccessibilityLabel("Keyboard location")
        keyboard.addSubview(positionChoice);button(keyboard,"Place…",338,130,138,#selector(previewKeyboard))
        label(keyboard,"Choose a preset, or use Place to set a custom location.",16,170,460,12,.secondaryLabelColor)
        let suggestions=card("Suggestions",316,140)
        label(suggestions,"Font",16,48,100)
        let font=NSPopUpButton(frame:NSRect(x:116,y:42,width:360,height:28),pullsDown:false)
        font.addItems(withTitles:["System","Rounded","Monospaced"])
        font.selectItem(withTitle:UserDefaults.standard.string(forKey:"suggestionFont") ?? "System")
        font.target=self;font.action=#selector(suggestionFontChanged(_:));font.setAccessibilityLabel("Suggestion font");suggestions.addSubview(font)
        label(suggestions,"Text size",16,82,200)
        suggestionSizeLabel=label(suggestions,"",376,82,100);suggestionSizeLabel.alignment = .right
        let fontSize=NSSlider(value:UserDefaults.standard.double(forKey:"suggestionFontSize"),minValue:8,maxValue:24,target:self,action:#selector(suggestionSizeChanged(_:)))
        fontSize.frame=NSRect(x:16,y:108,width:460,height:20);fontSize.isContinuous=true
        fontSize.setAccessibilityLabel("Suggestion text size");suggestions.addSubview(fontSize)
        let pointer=card("Pointer",472,176)
        label(pointer,"Speed",16,48,200)
        sensitivityLabel=label(pointer,"",376,48,100);sensitivityLabel.alignment = .right
        sensitivityLabel.font = .monospacedDigitSystemFont(ofSize:13,weight:.regular)
        let sensitivity=NSSlider(value:UserDefaults.standard.double(forKey:"trackingSensitivity"),minValue:0.5,maxValue:2.5,target:self,action:#selector(sensitivityChanged(_:)))
        sensitivity.frame=NSRect(x:16,y:76,width:460,height:20);sensitivity.isContinuous=true
        sensitivity.identifier=NSUserInterfaceItemIdentifier("trackingSensitivity");sensitivity.setAccessibilityLabel("Pointer speed");pointer.addSubview(sensitivity)
        label(pointer,"Slower",16,102,100,11,.secondaryLabelColor)
        label(pointer,"Faster",376,102,100,11,.secondaryLabelColor).alignment = .right
        label(pointer,"Typing cursor",16,136,120)
        let cursor=NSPopUpButton(frame:NSRect(x:146,y:130,width:330,height:28),pullsDown:false)
        cursor.addItems(withTitles:["Dot","Ring","Crosshair","Hidden"])
        cursor.selectItem(withTitle:UserDefaults.standard.string(forKey:"typingCursor") ?? "Dot")
        cursor.target=self;cursor.action=#selector(cursorChanged(_:));cursor.setAccessibilityLabel("Typing cursor");pointer.addSubview(cursor)
        let activation=card("Open and close the keyboard",664,168)
        let gesture=NSButton(checkboxWithTitle:"Three-finger click",target:self,action:#selector(gestureChanged(_:)))
        gesture.frame=NSRect(x:16,y:43,width:460,height:24)
        gesture.state=UserDefaults.standard.bool(forKey:"threeFingerClick") ? .on : .off;activation.addSubview(gesture)
        label(activation,"Rest three fingers, then click the trackpad to toggle.",16,73,460,12,.secondaryLabelColor)
        label(activation,"Keyboard shortcut",16,102,460,12,.secondaryLabelColor)
        shortcutLabel=label(activation,"",16,132,264)
        button(activation,"Set…",300,126,76,#selector(recordShortcut));button(activation,"Clear",388,126,88,#selector(removeShortcut))
        let permission=FlippedDocumentView(frame:NSRect(x:24,y:848,width:492,height:48))
        label(permission,"Accessibility access is needed to use the keyboard.",0,4,352,12,.secondaryLabelColor,36)
        button(permission,"Allow…",370,0,122,#selector(openAccessibility))
        permissionNotice=permission;permission.isHidden=AXIsProcessTrusted();content.addSubview(permission)
        settingsFooter=label(content,"Changes save automatically. Press Esc to close the keyboard.",24,permission.isHidden ? 848 : 912,492,12,.secondaryLabelColor,36)
        content.setFrameSize(NSSize(width:540,height:max(settingsFooter.frame.maxY+24,height)))
        refreshPreferenceLabels();setup.center();scroll.contentView.scroll(to:.zero)
    }
    private func refreshPreferenceLabels() {
        suggestionSizeLabel?.stringValue="\(Int(UserDefaults.standard.double(forKey:"suggestionFontSize"))) pt"
        sizeLabel?.stringValue="\(Int(UserDefaults.standard.double(forKey:"keyboardZoom")*100))%"
        sensitivityLabel?.stringValue=String(format:"%.2f×",UserDefaults.standard.double(forKey:"trackingSensitivity"))
    }
    @objc private func suggestionSizeChanged(_ sender:NSSlider) {
        UserDefaults.standard.set(sender.doubleValue.rounded(),forKey:"suggestionFontSize");refreshPreferenceLabels();placeKeyboard(on:panel.screen ?? NSScreen.main!,preserveOrigin:true);canvas.needsDisplay=true
    }
    @objc private func suggestionFontChanged(_ sender:NSPopUpButton) {
        UserDefaults.standard.set(sender.titleOfSelectedItem ?? "System",forKey:"suggestionFont");placeKeyboard(on:panel.screen ?? NSScreen.main!,preserveOrigin:true);canvas.needsDisplay=true
    }
    @objc private func cursorChanged(_ sender:NSPopUpButton) {
        UserDefaults.standard.set(sender.titleOfSelectedItem ?? "Dot",forKey:"typingCursor");canvas.needsDisplay=true
    }
    @objc private func sizeChanged(_ sender:NSSlider) {
        UserDefaults.standard.set(sender.doubleValue,forKey:"keyboardZoom");refreshPreferenceLabels()
        if previewing {placeKeyboard(on:panel.screen ?? NSScreen.main!)}
    }
    @objc private func sensitivityChanged(_ sender:NSSlider) {
        UserDefaults.standard.set(sender.doubleValue,forKey:"trackingSensitivity");refreshPreferenceLabels()
    }
    @objc private func positionChanged(_ sender:NSPopUpButton) {
        UserDefaults.standard.set(sender.titleOfSelectedItem ?? "Next to cursor",forKey:"keyboardPosition")
        if previewing {placeKeyboard(on:panel.screen ?? NSScreen.main!)}
    }
    @objc private func previewKeyboard() {
        hide(reason:"Keyboard preview · drag to save a custom position")
        previewing=true;testMode=false
        placementDone.isHidden=false
        banner="Drag to position · your location saves automatically"
        panel.ignoresMouseEvents=false;panel.isMovableByWindowBackground=true;placeKeyboard(on:NSScreen.main!);panel.orderFrontRegardless();canvas.needsDisplay=true
    }
    @objc private func finishPlacement() {hide(reason:"Keyboard location saved")}
    private func placeKeyboard(on screen:NSScreen,preserveOrigin:Bool=false) {
        movingProgrammatically=true;defer {movingProgrammatically=false}
        let visible=screen.visibleFrame
        let oldBottom=panel.frame.minY,oldX=panel.frame.minX
        var scale=KeyboardSizing.scale(zoom:UserDefaults.standard.double(forKey:"keyboardZoom"),availableWidth:visible.width,availableHeight:visible.height)
        func measured(_ scale:CGFloat)->SuggestionLayout {
            SuggestionLayout(words:guesses.map(\.word),scale:scale,fontName:UserDefaults.standard.string(forKey:"suggestionFont") ?? "System",fontSize:min(24,max(8,UserDefaults.standard.double(forKey:"suggestionFontSize"))),maxWidth:visible.width-16)
        }
        var layout=measured(scale)
        func maximumHeight(_ scale:CGFloat)->CGFloat {
            let reserve=SuggestionLayout(words:Array(repeating:String(repeating:"w",count:decoder?.maximumWordLength ?? DictionaryRules.maximumWordLength),count:5),scale:scale,fontName:UserDefaults.standard.string(forKey:"suggestionFont") ?? "System",fontSize:min(24,max(8,UserDefaults.standard.double(forKey:"suggestionFontSize"))),maxWidth:visible.width-16)
            return reserve.size.height*scale
        }
        while maximumHeight(scale)>visible.height-16 && scale>0.05 {scale*=0.9;layout=measured(scale)}
        canvas.layout=layout
        let size=NSSize(width:layout.size.width*scale,height:layout.size.height*scale);panel.setContentSize(size)
        let center=NSPoint(x:visible.midX-size.width/2,y:visible.midY-size.height/2)
        var origin=center
        switch UserDefaults.standard.string(forKey:"keyboardPosition") ?? "Next to cursor" {
        case "Bottom center":origin.y=visible.minY+24
        case "Bottom left":origin=NSPoint(x:visible.minX+24,y:visible.minY+24)
        case "Bottom right":origin=NSPoint(x:visible.maxX-size.width-24,y:visible.minY+24)
        case "Top center":origin.y=visible.maxY-size.height-24
        case "Next to cursor":
            let cursor=NSEvent.mouseLocation
            let gap:CGFloat=16
            // Prefer below/right; switch sides when that would leave the display.
            let x=cursor.x+gap+size.width<=visible.maxX-8 ? cursor.x+gap : cursor.x-gap-size.width
            let y=cursor.y-gap-size.height>=visible.minY+8 ? cursor.y-gap-size.height : cursor.y+gap
            origin=NSPoint(x:x,y:y)
        case "Custom":
            if UserDefaults.standard.object(forKey:"customCenterX") != nil {
                origin=NSPoint(x:visible.minX+UserDefaults.standard.double(forKey:"customCenterX")*visible.width-size.width/2,
                               y:visible.minY+UserDefaults.standard.double(forKey:"customCenterY")*visible.height-size.height/2)
            }
        default:break
        }
        // Extra suggestion lines grow above the keys, preserving the keyboard position.
        if preserveOrigin {origin=NSPoint(x:oldX,y:oldBottom)}
        origin.x=min(max(origin.x,visible.minX+8),visible.maxX-size.width-8)
        origin.y=min(max(origin.y,visible.minY+8),visible.maxY-maximumHeight(scale)-8)
        panel.setFrameOrigin(origin);canvas.needsDisplay=true
    }
    private func rememberCustomPosition() {
        guard previewing,!movingProgrammatically,let visible=panel.screen?.visibleFrame,visible.width>0,visible.height>0 else{return}
        UserDefaults.standard.set((panel.frame.midX-visible.minX)/visible.width,forKey:"customCenterX")
        UserDefaults.standard.set((panel.frame.midY-visible.minY)/visible.height,forKey:"customCenterY")
        UserDefaults.standard.set("Custom",forKey:"keyboardPosition");positionChoice.selectItem(withTitle:"Custom")
    }
    @objc func showSetup() {hide(reason:"Settings opened");setup.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)}
    @objc private func quit(){NSApp.terminate(nil)}
    @objc private func openAccessibility() {
        let options=[kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String:true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(URL(string:"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    @objc private func checkAccess() {updateStatus()}
    @objc private func gestureChanged(_ sender:NSButton) {UserDefaults.standard.set(sender.state == .on,forKey:"threeFingerClick")}
    @objc private func showKeyboard(){intent("show",source:"menu")}
    @objc private func hideKeyboard(){intent("hide",source:"menu")}
    @objc private func testCapture(){intent("test",source:"menu")}
    @objc private func removeShortcut() {
        if let h=hotkey {UnregisterEventHotKey(h)};hotkey=nil
        UserDefaults.standard.removeObject(forKey:"shortcutCode");UserDefaults.standard.removeObject(forKey:"shortcutModifiers");shortcutLabel.stringValue="Not set"
    }
    @objc private func recordShortcut() {
        if recording != nil {return}
        shortcutLabel.stringValue="Press a shortcut… (Esc to cancel)"
        recording=NSEvent.addLocalMonitorForEvents(matching:.keyDown) { [weak self] event in
            guard let self=self else {return event}
            if event.keyCode==53 {self.endRecording();self.registerSavedShortcut();return nil}
            let flags=event.modifierFlags.intersection([.control,.option,.command,.shift])
            guard !flags.intersection([.control,.option,.command]).isEmpty else {return nil}
            var carbon:UInt32=0
            if flags.contains(.control){carbon |= UInt32(controlKey)}
            if flags.contains(.option){carbon |= UInt32(optionKey)}
            if flags.contains(.command){carbon |= UInt32(cmdKey)}
            if flags.contains(.shift){carbon |= UInt32(shiftKey)}
            UserDefaults.standard.set(Int(event.keyCode),forKey:"shortcutCode")
            UserDefaults.standard.set(Int(carbon),forKey:"shortcutModifiers")
            UserDefaults.standard.set([flags.contains(.control) ? "Control" : nil, flags.contains(.option) ? "Option" : nil, flags.contains(.command) ? "Command" : nil, flags.contains(.shift) ? "Shift" : nil, event.charactersIgnoringModifiers?.uppercased() ?? "key \(event.keyCode)"].compactMap{$0}.joined(separator:" + "),forKey:"shortcutDescription")
            self.endRecording();self.registerSavedShortcut();return nil
        }
    }
    private func endRecording(){if let r=recording {NSEvent.removeMonitor(r)};recording=nil}
    private func registerSavedShortcut() {
        if let h=hotkey {UnregisterEventHotKey(h)};hotkey=nil
        guard UserDefaults.standard.object(forKey:"shortcutCode") != nil else {shortcutLabel?.stringValue="Not set";return}
        let result=RegisterEventHotKey(UInt32(UserDefaults.standard.integer(forKey:"shortcutCode")),UInt32(UserDefaults.standard.integer(forKey:"shortcutModifiers")),EventHotKeyID(signature:0x54505459,id:1),GetApplicationEventTarget(),0,&hotkey)
        shortcutLabel?.stringValue=result==noErr ? "\(UserDefaults.standard.string(forKey:"shortcutDescription") ?? "Custom")" : "Already in use. Try another."
    }
    private func loadDecoder() {
        guard let url=Bundle.main.url(forResource:"word_freq",withExtension:"txt") else {banner="Dictionary missing";return}
        decoderQueue.async { [weak self] in
            guard let data=try? String(contentsOf:url,encoding:.utf8) else {return}
            let decoder=PathDecoder(dictionary:data)
            DispatchQueue.main.async {self?.decoder=decoder;self?.updateStatus()}
        }
    }
    func intent(_ action:String,source:String) {
        if action=="hide" {hide(reason:"Hidden via \(source)");return}
        if action=="toggle",session.phase != .idle {hide(reason:"Released via \(source)");return}
        guard session.phase == .idle else {return}
        show(test:action=="test")
    }
    private func show(test:Bool) {
        testMode=test
        target=nil;focusedElement=nil
        if !test {
            let front=NSWorkspace.shared.frontmostApplication
            target=front?.processIdentifier == getpid() ? lastExternal : front
        }
        setup.orderOut(nil)
        if !test {target?.activate(options:[])}
        sessionEpoch+=1
        generation+=1;guesses=[];path=[];finger=nil;lastCommit=nil;expectedCaret=nil
        session.show()
        expiry=Date().addingTimeInterval(test ? 10 : 120)
        if test {testStart=Date();testFrames=TPFrameCount();testDropped=TPDroppedEventCount()}
        banner="Move to the first key · click to start, click again to enter"
        let screen=NSScreen.screens.first {NSMouseInRect(NSEvent.mouseLocation,$0.frame,false)} ?? NSScreen.main!
        previewing=false;placementDone.isHidden=true;panel.isMovableByWindowBackground=false;placeKeyboard(on:screen)
        panel.orderFrontRegardless()
        // Opening the overlay leaves pointing normal until an explicit key click.
        refreshCaptureReadiness();TPSetCapture(false)
        if lastContacts==0 {session.contactsLifted()}
        updateStatus()
    }
    private func refreshCaptureReadiness() {
        pointerReady=AXIsProcessTrusted() && TPInstallEventTap(captureReleased,receivePointer,activateThreeFingerClick)
        TPSetOverlayActive(pointerReady && session.phase != .idle)
        panel.ignoresMouseEvents=pointerReady
        if !AXIsProcessTrusted() {banner="Accessibility needed · click this keyboard to open permission settings"}
        else if !pointerReady {banner="Keyboard is unavailable · open Settings from the menu"}
        else if decoder == nil {banner="Keyboard ready · loading dictionary…"}
        else {banner="Move onto a starting key · click, trace, click again"}
        if !pointerReady {finger=nil;setCursorHidden(false)}
        canvas.needsDisplay=true
    }
    func blockedKeyboardClicked() {
        guard session.phase != .idle,!pointerReady else{return}
        if !AXIsProcessTrusted() {openAccessibility()}
    }
    func hide(reason:String) {
        if testMode,session.phase != .idle {
            lastTest=["durationSeconds":Date().timeIntervalSince(testStart),"contactFrames":TPFrameCount()-testFrames,
                      "suppressedPointerEvents":TPDroppedEventCount()-testDropped,"releaseReason":reason]
        }
        cancelEditorAction()
        sessionEpoch+=1
        stopPointerCapture(restoreCursor:true)
        TPSetOverlayActive(false);session.hide();generation+=1
        previewing=false;placementDone?.isHidden=true;panel?.ignoresMouseEvents=true
        path=[];finger=nil;guesses=[];keyboardSymbols=false;target=nil;focusedElement=nil;recognizingFinal=false
        clearCorrection();banner=reason;panel?.orderOut(nil);updateStatus()
    }
    private func cancelEditorAction() {
        editorTicket?.cancel();editorTicket=nil;targetRequest+=1;targetActionPending=false
    }
    private func clearCorrection() {lastCommit=nil;expectedCaret=nil;commitOwner=nil;commitPID=nil}
    private func targetStillFrontmost(_ pid:pid_t)->Bool {
        NSWorkspace.shared.frontmostApplication?.processIdentifier==pid
    }
    private func withTarget(allowNew:Bool=false,_ completion:@escaping ()->Void) {
        guard !targetActionPending else{return}
        let front=NSWorkspace.shared.frontmostApplication
        let app=allowNew ? (front?.processIdentifier == getpid() ? lastExternal : front) : target
        guard let app=app,app.processIdentifier != getpid(),!app.isTerminated else {banner="Focus a text field first";return}
        let pid=app.processIdentifier,expected=allowNew ? nil : focusedElement
        guard allowNew || expected != nil else {banner="Focus a text field first";return}
        targetRequest+=1;let request=targetRequest,epoch=sessionEpoch
        targetActionPending=true
        accessibilityQueue.async { [weak self] in
            let field=EditorAccess.capture(pid:pid)
            DispatchQueue.main.async {
                guard let self=self,self.targetRequest==request,self.sessionEpoch==epoch else{return}
                self.targetActionPending=false
                guard self.targetStillFrontmost(pid),let field=field,expected.map({CFEqual($0,field)}) ?? true else {
                    self.clearCorrection()
                    if self.clickStroke.active {self.hide(reason:"Text destination changed")}
                    else {self.banner="Focus an accessible text field, then try again"}
                    return
                }
                if self.target?.processIdentifier != pid || self.focusedElement.map({!CFEqual($0,field)}) ?? true {self.clearCorrection()}
                self.target=app;self.focusedElement=field;completion()
            }
        }
    }
    private func sendKey(_ code:CGKeyCode) {
        guard !testMode else{return}
        withTarget { [weak self] in self?.editTarget(code==36 ? "\n" : "",backspace:code==51,deleteWord:code==51,record:false) }
    }
    private func insert(_ text:String) {
        guard !testMode else{return}
        withTarget { [weak self] in self?.editTarget(text,word:true) }
    }
    private func postText(_ text:String) {editTarget(text)}
    private func editTarget(_ text:String,backspace:Bool=false,deleteWord:Bool=false,record:Bool=true,old:String?=nil,expected:CFRange?=nil,word:Bool=false) {
        guard !targetActionPending,let app=target,let field=focusedElement,targetStillFrontmost(app.processIdentifier) else {clearCorrection();return}
        editorTicket?.cancel();let ticket=EditorTicket();editorTicket=ticket
        targetRequest+=1;let request=targetRequest,epoch=sessionEpoch,pid=app.processIdentifier
        targetActionPending=true
        let keyboardInput=EditorKeyInput.required(bundleID:app.bundleIdentifier)
        accessibilityQueue.async { [weak self] in
            let written=EditorAccess.edit(pid:pid,field:field,text:text,backspace:backspace,deleteWord:deleteWord,ticket:ticket,old:old,expected:expected,keyboardInput:keyboardInput,word:word)
            DispatchQueue.main.async {
                guard let self=self,self.targetRequest==request,self.sessionEpoch==epoch else{return}
                self.targetActionPending=false
                self.lastEditorResult=written.detail
                guard written.written,self.targetStillFrontmost(pid) else {
                    self.clearCorrection();self.banner=written.detail;self.editorMessageUntil=Date().addingTimeInterval(5);return
                }
                if record {self.recordCommit(written.text,field:field,pid:pid)} else {self.clearCorrection()}
            }
        }
    }
    private func recordCommit(_ text:String,field:AXUIElement,pid:pid_t) {
        lastCommit=text;expectedCaret=nil;commitOwner=field;commitPID=pid
        let token=generation,epoch=sessionEpoch
        accessibilityQueue.asyncAfter(deadline:.now()+0.10) { [weak self] in
            let range=EditorAccess.matches(pid:pid,field:field) ? EditorAccess.caret(field) : nil
            DispatchQueue.main.async {
                guard let self=self,self.generation==token,self.sessionEpoch==epoch,self.commitPID==pid,
                      self.commitOwner.map({CFEqual($0,field)}) == true,self.lastCommit==text else{return}
                self.expectedCaret=range
            }
        }
    }
    private func replaceLast(with word:String) {
        // Never capture a new field for an old prediction, even if its text matches.
        guard !targetActionPending,let old=lastCommit,let expected=expectedCaret,let field=focusedElement,
              let pid=target?.processIdentifier,correctionOwnerMatches(pid:pid,field:field,committedPID:commitPID,committedField:commitOwner),
              targetStillFrontmost(pid) else {clearCorrection();banner="Correction unavailable: destination or caret changed";return}
        editTarget(word,old:old,expected:expected,word:true)
    }

    func frame(_ contacts:[Contact],time:Double) {
        lastContacts=contacts.count
        // Touch alone never toggles. Activation is handled by the physical click.
        if session.phase == .arming,contacts.isEmpty {session.contactsLifted()}
    }
    private var keyboardScreenRect:PointerViewport {
        canvas.layout.screenViewport(panel:panel.frame,desktopTop:NSScreen.screens.first?.frame.maxY ?? 0)
    }
    private func normalizedPointer(_ screenPoint:PadPoint)->PadPoint {
        keyboardScreenRect.normalized(screenPoint)
    }
    private func setCursorHidden(_ hidden:Bool) {
        guard hidden != cursorHidden else{return}
        if hidden {NSCursor.hide()} else {NSCursor.unhide()}
        cursorHidden=hidden
    }
    private func updateHoverPointer(_ point:PadPoint) {
        let normalized=normalizedPointer(point)
        let inside=normalized.x>=0 && normalized.x<=1 && normalized.y>=0 && normalized.y<=1
        finger=inside ? normalized : nil
        setCursorHidden(inside)
    }
    private func stopPointerCapture(restoreCursor:Bool,keepKeyboardCursor:Bool=false) {
        let endpoint=clickStroke.point,wasActive=clickStroke.active
        clickStroke.end();TPSetCapture(false)
        if wasActive,restoreCursor {
            let area=keyboardScreenRect
            CGWarpMouseCursorPosition(CGPoint(x:area.minX+endpoint.x*area.width,y:area.minY+endpoint.y*area.height))
        }
        setCursorHidden(keepKeyboardCursor && finger != nil)
    }
    func activationClick()->Bool {
        guard UserDefaults.standard.bool(forKey:"threeFingerClick") else{return false}
        if previewing {hide(reason:"Preview closed")}
        else {intent("toggle",source:"three-finger click")}
        return true
    }
    func pointerEvent(type:Int,screenPoint:PadPoint,dx:Double,dy:Double,time:Double)->Bool {
        guard session.phase != .idle,!previewing,pointerReady else{return false}
        if type==1 {
            if clickStroke.active {
                stopPointerCapture(restoreCursor:true,keepKeyboardCursor:true)
                finishStroke(time:time);canvas.needsDisplay=true
                return true
            }
            if recognizingFinal || targetActionPending {return true}
            let top=(NSScreen.screens.first?.frame.maxY ?? 0)-panel.frame.maxY
            let local=NSPoint(x:(screenPoint.x-panel.frame.minX)/canvas.layout.scale,y:(screenPoint.y-top)/canvas.layout.scale)
            if let index=canvas.layout.cells.firstIndex(where:{$0.contains(local)}) {
                if !testMode,index<guesses.count {
                    replaceLast(with:guesses[index].word)
                }
                return true
            }
            let point=normalizedPointer(screenPoint)
            guard point.x>=0,point.x<=1,point.y>=0,point.y<=1 else{setCursorHidden(false);return false}
            if KeyboardGeometry.commands.contains(where:{$0.contains(point)}) {
                if let command=KeyboardGeometry.commands.first(where:{$0.contains(point)}),command.label=="Close" {hide(reason:"Closed from keyboard");return true}
                if !testMode {activateCell(at:point)}
                return true
            }
            guard KeyboardGeometry.key(at:point,symbols:keyboardSymbols) != nil else{return true}
            if keyboardSymbols {
                if !testMode {activateCell(at:point)}
                return true
            }
            let begin = { [weak self] in
                guard let self=self else{return}
                self.generation+=1;self.livePredictionPointCount=0;self.nextLivePrediction=Date.distantPast
                self.session.contactsLifted();self.clickStroke.begin(at:point)
                self.path=[point];self.finger=point;self.guesses=[];self.clearCorrection()
                TPSetCapture(true);self.setCursorHidden(true)
                self.banner="Recording · click again to enter the word · Esc cancels"
                self.canvas.needsDisplay=true
            }
            if testMode {begin()} else {withTarget(allowNew:true,begin)}
            return true
        }
        if type==5 || type==6 {
            if clickStroke.active {
                let area=keyboardScreenRect
                clickStroke.move(dx:dx,dy:dy,width:area.width,height:area.height,sensitivity:UserDefaults.standard.double(forKey:"trackingSensitivity"))
                let point=clickStroke.point;finger=point
                if path.last.map({$0.distance(point)>0.001}) ?? true {path.append(point)}
                if path.count>2000 {path=PathDecoder.resample(path,count:500)}
            } else {
                updateHoverPointer(screenPoint)
                if Date()>=editorMessageUntil {banner=testMode ? "Test: click a starting key, trace, click again" : (keyboardSymbols ? "Click a number or symbol · ABC returns to letters" : "Click a starting key, trace the word, then click again")}
            }
            canvas.needsDisplay=true
        }
        return false
    }
    private func activateCell(at first:PadPoint) {
        if KeyboardGeometry.commands.first(where:{$0.contains(first)})?.label=="Fn" {
            keyboardSymbols.toggle();generation+=1;guesses=[];clearCorrection()
            banner=keyboardSymbols ? "Click a number or symbol · ABC returns to letters" : "Click a starting key, trace the word, then click again"
            canvas.needsDisplay=true;return
        }
        withTarget(allowNew:keyboardSymbols || KeyboardGeometry.commands.contains(where:{$0.contains(first)})) { [weak self] in
            guard let self=self else{return}
            if let command=KeyboardGeometry.commands.first(where:{$0.contains(first)}) {
                switch command.label {
                case "Space":self.postText(" ");self.guesses=[]
                case "⌫":self.sendKey(51);self.guesses=[]
                case "Return":self.sendKey(36);self.guesses=[]
                default:self.hide(reason:"Closed from keyboard")
                }
            } else if let key=KeyboardGeometry.key(at:first,symbols:self.keyboardSymbols) {self.postText(key.label);self.guesses=[]}
        }
    }
    private func finishStroke(time:Double) {
        let stroke=path;path=[]
        guard let first=stroke.first else{return}
        let length=zip(stroke,stroke.dropFirst()).reduce(0.0) {$0+$1.0.distance($1.1)}
        if testMode {banner="Recorded \(stroke.count) points · \(max(0,Int(expiry.timeIntervalSinceNow))) seconds left";return}
        generation+=1;let token=sessionEpoch
        if length<0.035 {
            activateCell(at:first);return
        }
        guard let decoder=decoder else{return}
        let resultGeneration=generation
        recognizingFinal=true;banner="Recognizing…"
        decoderQueue.async { [weak self] in
            let start=Date();let results=decoder.predict(stroke)
            let ms=Int(Date().timeIntervalSince(start)*1000)
            DispatchQueue.main.async {
                guard let self=self,self.sessionEpoch==token,self.generation==resultGeneration,self.session.phase == .ready else{return}
                self.recognizingFinal=false;self.guesses=results
                if let top=results.first {self.insert(top.word);self.banner="\(top.word) · \(ms) ms · tap another prediction to correct"}
                else {self.banner="No match · try a clearer stroke"}
                self.canvas.needsDisplay=true
            }
        }
    }
    private func updateLivePrediction() {
        guard clickStroke.active,!testMode,!livePredictionBusy,path.count>=3,
              path.count != livePredictionPointCount,Date()>=nextLivePrediction,let decoder=decoder else{return}
        livePredictionBusy=true;livePredictionPointCount=path.count
        nextLivePrediction=Date().addingTimeInterval(0.12)
        let snapshot=path,token=generation
        decoderQueue.async { [weak self] in
            let started=Date();let results=decoder.predict(snapshot,partial:true)
            let elapsed=Date().timeIntervalSince(started)
            DispatchQueue.main.async {
                guard let self=self else{return};self.livePredictionBusy=false
                // Wait at least 3× compute time between jobs: aim for <=25% of one core.
                self.nextLivePrediction=Date().addingTimeInterval(max(0.12,elapsed*3))
                guard self.generation==token,self.clickStroke.active else{return}
                self.guesses=results;self.canvas.needsDisplay=true
            }
        }
    }
    private func tick() {
        TPHeartbeat()
        if Date()>=nextAccessRefresh {
            nextAccessRefresh=Date().addingTimeInterval(2)
            if pointerReady != AXIsProcessTrusted() {refreshCaptureReadiness()}
        }
        updateLivePrediction()
        if session.phase != .idle {
            if clickStroke.active && !TPIsCapturing(){hide(reason:"Capture released");return}
            if !AXIsProcessTrusted(),clickStroke.active {stopPointerCapture(restoreCursor:true);path=[]}
            if pointerReady != AXIsProcessTrusted() {refreshCaptureReadiness()}
            if pointerReady,!clickStroke.active {
                let location=NSEvent.mouseLocation
                updateHoverPointer(PadPoint(x:location.x,y:(NSScreen.screens.first?.frame.maxY ?? 0)-location.y))
            }
            if Date()>=expiry {hide(reason:testMode ? "Capture test complete" : "Session time limit reached");return}
            if !testMode,clickStroke.active {
                guard let pid=target?.processIdentifier,targetStillFrontmost(pid) else {hide(reason:"Text destination changed");return}
                if Date()>=nextTargetCheck,!targetActionPending,!targetValidationBusy {
                    nextTargetCheck=Date().addingTimeInterval(0.2)
                    guard let field=focusedElement else {hide(reason:"Text destination changed");return}
                    targetValidationBusy=true
                    let epoch=sessionEpoch,stroke=generation
                    accessibilityQueue.async { [weak self] in
                        let valid=EditorAccess.matches(pid:pid,field:field)
                        DispatchQueue.main.async {
                            guard let self=self else{return};self.targetValidationBusy=false
                            if self.sessionEpoch==epoch,self.generation==stroke,self.clickStroke.active,!valid {self.hide(reason:"Text destination changed")}
                        }
                    }
                }
            }
            if testMode,pointerReady {banner="Click to start/stop a stroke · \(Int(ceil(expiry.timeIntervalSinceNow)))s left · Esc releases"}
            canvas.needsDisplay=true
        }
        updateStatus()
    }
    private func updateStatus() {
        let granted=AXIsProcessTrusted()
        if permissionNotice?.isHidden != granted {
            permissionNotice?.isHidden=granted
            settingsFooter?.setFrameOrigin(NSPoint(x:24,y:granted ? 848 : 912))
            if let footer=settingsFooter,let document=settingsDocument {
                document.setFrameSize(NSSize(width:540,height:max(footer.frame.maxY+24,setup.contentView?.bounds.height ?? 700)))
            }
        }
        statusItem?.button?.toolTip="TrackpadSwipe"
        if Date()<nextStatusWrite {return};nextStatusWrite=Date().addingTimeInterval(0.5)
        let status:[String:Any]=["lastEditorResult":lastEditorResult,"phase":session.phase.rawValue,"capturing":TPIsCapturing(),"testMode":testMode,"accessibility":AXIsProcessTrusted(),"trackpadReady":rawReady,"frames":TPFrameCount(),"suppressedPointerEvents":TPDroppedEventCount(),"lastCaptureTest":lastTest,"dictionaryWords":decoder?.wordCount ?? 0]
        if let data=try? JSONSerialization.data(withJSONObject:status,options:[.sortedKeys,.prettyPrinted]) {
            try? FileManager.default.createDirectory(at:statusURL.deletingLastPathComponent(),withIntermediateDirectories:true)
            try? data.write(to:statusURL,options:.atomic)
        }
    }
}

if CommandLine.arguments.contains("--self-test") {
    runCoreTests()
    var selections=0,writes=0,focused=true,setterSucceeds=true
    var currentCaret=CFRange(location:6,length:0),previous="hello "
    var readHook:(()->Void)?
    let operation=EditorTransaction(matches:{focused},caret:{currentCaret},read:{ _ in readHook?();return previous },select:{ _ in selections+=1;return true },insert:{ _ in writes+=1;return setterSucceeds })
    let cancelled=EditorTicket();cancelled.cancel()
    precondition(!operation.edit(text:"hi ",ticket:cancelled,old:"hello ",expected:currentCaret))
    let duringRead=EditorTicket();readHook={duringRead.cancel()}
    precondition(!operation.edit(text:"hi ",ticket:duringRead,old:"hello ",expected:currentCaret))
    readHook=nil
    focused=false
    precondition(!operation.edit(text:"hi ",ticket:EditorTicket(),old:"hello ",expected:currentCaret))
    focused=true;previous="other "
    precondition(!operation.edit(text:"hi ",ticket:EditorTicket(),old:"hello ",expected:currentCaret))
    previous="hello "
    precondition(!operation.edit(text:"hi ",ticket:EditorTicket(),old:"hello ",expected:CFRange(location:8,length:0)))
    precondition(selections==0 && writes==0,"Invalid or cancelled correction reached a setter")
    // Queue a production transaction, cancel before releasing the worker.
    let queued=EditorTicket(),gate=DispatchSemaphore(value:0),done=DispatchSemaphore(value:0)
    DispatchQueue(label:"test.editor").async {gate.wait();precondition(!operation.edit(text:"hi ",ticket:queued,old:"hello ",expected:CFRange(location:6,length:0)));done.signal()}
    queued.cancel();gate.signal();done.wait()
    precondition(selections==0 && writes==0,"Queued cancellation mutated text")
    setterSucceeds=false
    precondition(!operation.edit(text:"hi ",ticket:EditorTicket(),old:"hello ",expected:currentCaret))
    precondition(selections==2 && writes==1,"Failed setter did not restore selection")
    setterSucceeds=true
    // Focus may move during a read, but the setters remain bound to the original
    // field by EditorAccess. No keyboard event can be redirected to a new field.
    readHook={focused=false}
    precondition(operation.edit(text:"hi ",ticket:EditorTicket(),old:"hello ",expected:currentCaret))
    precondition(writes==2)
    print("PASS: production editor transaction, queued/read cancellation, stale text/caret, setter failure, field-bound writes")
    // Model an editor whose selected-text setter leaves its old selection intact.
    // Consecutive words must append, corrections must collapse their selection,
    // and offsets must use AX's UTF-16 units rather than Swift character counts.
    var editorText="",editorSelection=CFRange(location:0,length:0)
    let stationaryEditor=EditorTransaction(matches:{true},caret:{editorSelection},read:{ range in
        let string=editorText as NSString
        guard range.location>=0,range.location+range.length<=string.length else{return nil}
        return string.substring(with:NSRange(location:range.location,length:range.length))
    },select:{ range in editorSelection=range;return true },insert:{ replacement in
        editorText=(editorText as NSString).replacingCharacters(in:NSRange(location:editorSelection.location,length:editorSelection.length),with:replacement)
        return true
    })
    precondition(stationaryEditor.edit(text:"hello ",ticket:EditorTicket()))
    precondition(editorSelection.location==6 && editorSelection.length==0)
    precondition(stationaryEditor.edit(text:"world ",ticket:EditorTicket()))
    precondition(editorText=="hello world " && editorSelection.location==12 && editorSelection.length==0,"New words did not advance the caret")
    precondition(stationaryEditor.edit(text:"there ",ticket:EditorTicket(),old:"world ",expected:editorSelection))
    precondition(editorText=="hello there " && editorSelection.location==12 && editorSelection.length==0,"Correction left text selected")
    editorText="a😀b";editorSelection=CFRange(location:1,length:2)
    precondition(stationaryEditor.edit(text:"👋🏽 ",ticket:EditorTicket()))
    precondition(editorText=="a👋🏽 b" && editorSelection.location==6 && editorSelection.length==0,"Unicode replacement used incorrect caret units")
    precondition(stationaryEditor.edit(text:"",backspace:true,ticket:EditorTicket()))
    precondition(editorText=="a👋🏽b" && editorSelection.location==5 && editorSelection.length==0)
    precondition(stationaryEditor.edit(text:"",backspace:true,ticket:EditorTicket()))
    precondition(editorText=="ab" && editorSelection.location==1 && editorSelection.length==0)
    for (source,wanted) in [("hello world","hello "),("hello world  ","hello "),("don't",""),("well-known",""),("hi 😀 ","hi ")] {
        editorText=source;editorSelection=CFRange(location:source.utf16.count,length:0)
        precondition(stationaryEditor.edit(text:"",backspace:true,deleteWord:true,ticket:EditorTicket()))
        precondition(editorText==wanted && editorSelection.location==wanted.utf16.count)
    }
    editorText="hello world";editorSelection=CFRange(location:6,length:5)
    precondition(stationaryEditor.edit(text:"",backspace:true,deleteWord:true,ticket:EditorTicket()))
    precondition(editorText=="hello " && editorSelection.location==6)
    editorText="hello world";editorSelection=CFRange(location:5,length:0)
    precondition(stationaryEditor.edit(text:"",backspace:true,deleteWord:true,ticket:EditorTicket()))
    precondition(editorText==" world" && editorSelection.location==0)
    print("PASS: consecutive word caret advancement, correction collapse, Unicode offsets, and whole-word/selection deletion")
    for (prefix,expected) in [("","hello"),("good","good hello"),("good-","good-hello"),("good ","good hello"),("good\n","good\nhello"),("good\t","good\thello"),("😀","😀 hello")] {
        editorText=prefix;editorSelection=CFRange(location:prefix.utf16.count,length:0)
        precondition(stationaryEditor.edit(text:"hello",ticket:EditorTicket(),word:true))
        precondition(editorText==expected && editorSelection.location==expected.utf16.count && editorSelection.length==0,"Conditional leading word space failed")
    }
    editorText="";editorSelection=CFRange(location:0,length:0)
    precondition(stationaryEditor.edit(text:"hello",ticket:EditorTicket(),word:true))
    precondition(stationaryEditor.edit(text:"world",ticket:EditorTicket(),word:true))
    precondition(editorText=="hello world","Consecutive words gained trailing or duplicate spaces")
    precondition(stationaryEditor.edit(text:"there",ticket:EditorTicket(),old:" world",expected:editorSelection,word:true))
    precondition(editorText=="hello there" && editorSelection.location==11,"Correction lost its leading separator")
    editorText="hello";editorSelection=CFRange(location:5,length:0)
    precondition(stationaryEditor.edit(text:"hi",ticket:EditorTicket(),old:"hello",expected:editorSelection,word:true))
    precondition(editorText=="hi","First-word correction gained a space")
    editorText="well-known";editorSelection=CFRange(location:10,length:0)
    precondition(stationaryEditor.edit(text:"made",ticket:EditorTicket(),old:"known",expected:editorSelection,word:true))
    precondition(editorText=="well-made","Hyphenated correction gained a space")
    editorText="hello old";editorSelection=CFRange(location:6,length:3)
    precondition(stationaryEditor.edit(text:"new",ticket:EditorTicket(),word:true))
    precondition(editorText=="hello new","Selected-word replacement gained a duplicate space")
    print("PASS: conditional leading spaces, first words, hyphens, existing whitespace, Unicode context, and separator-preserving corrections")
    // Exercise the same reader and transaction boundary used by the AX adapter.
    // The editor supports AXValue, but rejects parameterized range reads.
    editorText="";editorSelection=CFRange(location:0,length:0)
    let valueOnly=EditorTextReader(parameterized:{_ in nil},value:{editorText})
    var selectionHistory:[CFRange]=[]
    let valueOnlyEditor=EditorTransaction(matches:{true},caret:{editorSelection},read:valueOnly.read,
        select:{range in editorSelection=range;selectionHistory.append(range);return true},insert:{text in
            editorText=(editorText as NSString).replacingCharacters(in:NSRange(location:editorSelection.location,length:editorSelection.length),with:text)
            return true
        },verify:{text,range in valueOnly.read(range)==text})
    precondition(valueOnlyEditor.edit(text:"hello",ticket:EditorTicket(),word:true))
    precondition(valueOnlyEditor.edit(text:"world",ticket:EditorTicket(),word:true))
    precondition(editorText=="hello world" && editorSelection.location==11 && editorSelection.length==0,"Value-only editor did not append verified words")
    precondition(valueOnly.read(CFRange(location:-1,length:1))==nil)
    precondition(valueOnly.read(CFRange(location:Int.max,length:1))==nil)
    precondition(valueOnly.read(CFRange(location:0,length:Int.max))==nil)
    let unavailable=EditorTransaction(matches:{true},caret:{CFRange(location:2,length:3)},read:{_ in nil},select:{range in selectionHistory.append(range);return true},insert:{_ in true},verify:{_,_ in false})
    selectionHistory=[]
    precondition(!unavailable.edit(text:"longer",ticket:EditorTicket()))
    precondition(selectionHistory.count==1,"Unknown postcondition restored the stale original selection")
    print("PASS: shared AXValue reader, verified consecutive writes, bounded ranges, and no stale selection restoration after uncertain mutation")
    var frontPID:pid_t?=42,originalFocused=true,observedSelection:CFRange?=CFRange(location:3,length:0),keyEmissions=0
    let destination=EditorKeyDestination(frontmostPID:{frontPID},originalFieldFocused:{originalFocused},selection:{observedSelection})
    func deliverToOriginal(_ ticket:EditorTicket=EditorTicket())->Bool {
        EditorKeyInput.deliver(ticket:ticket,validate:{destination.matches(pid:42,expected:CFRange(location:3,length:0))},emit:{keyEmissions+=1})
    }
    frontPID=43;precondition(!deliverToOriginal());frontPID=42
    originalFocused=false;precondition(!deliverToOriginal());originalFocused=true
    observedSelection=CFRange(location:4,length:0);precondition(!deliverToOriginal())
    observedSelection=CFRange(location:3,length:1);precondition(!deliverToOriginal())
    observedSelection=nil;precondition(!deliverToOriginal());observedSelection=CFRange(location:3,length:0)
    let cancelledDuringValidation=EditorTicket()
    let cancellingDestination=EditorKeyDestination(frontmostPID:{42},originalFieldFocused:{cancelledDuringValidation.cancel();return true},selection:{observedSelection})
    precondition(!EditorKeyInput.deliver(ticket:cancelledDuringValidation,validate:{cancellingDestination.matches(pid:42,expected:CFRange(location:3,length:0))},emit:{keyEmissions+=1}))
    precondition(keyEmissions==0,"Changed app, field, selection or cancellation emitted typing")
    precondition(deliverToOriginal() && keyEmissions==1)
    print("PASS: production typing eligibility rejects each app/field/selection mismatch and cancellation during validation")
    precondition(EditorKeyInput.required(bundleID:"com.openai.codex"))
    precondition(EditorKeyInput.required(bundleID:"com.tdesktop.Telegram"))
    precondition(!EditorKeyInput.required(bundleID:"com.apple.TextEdit") && !EditorKeyInput.required(bundleID:nil))
    var emitted=0
    let keyTicket=EditorTicket();keyTicket.cancel()
    precondition(!EditorKeyInput.deliver(ticket:keyTicket,validate:{true},emit:{emitted+=1}))
    precondition(!EditorKeyInput.deliver(ticket:EditorTicket(),validate:{false},emit:{emitted+=1}))
    precondition(emitted==0,"Cancelled or changed-target input was posted")
    precondition(EditorKeyInput.deliver(ticket:EditorTicket(),validate:{true},emit:{emitted+=1}))
    precondition(emitted==1)
    var caretSets=0
    let nativeInput=EditorTransaction(matches:{true},caret:{CFRange(location:0,length:0)},read:{_ in nil},select:{_ in caretSets+=1;return true},insert:{_ in true},advancesCaret:true)
    precondition(nativeInput.edit(text:"hello ",ticket:EditorTicket()))
    precondition(caretSets==1,"A stale AX range overrode the typing event's caret")
    // Model Telegram's read-only AX selection with native input moving the caret.
    // An unchanged selection must not need a setter just to append a word.
    var telegramText="",telegramCaret=CFRange(location:0,length:0),telegramSets=0
    let telegramReader=EditorTextReader(parameterized:{_ in nil},value:{telegramText})
    let telegramInput=EditorTransaction(matches:{true},caret:{telegramCaret},read:telegramReader.read,select:{ range in
        telegramSets+=1
        return range.location==telegramCaret.location && range.length==telegramCaret.length
    },insert:{ text in
        telegramText=(telegramText as NSString).replacingCharacters(in:NSRange(location:telegramCaret.location,length:telegramCaret.length),with:text)
        telegramCaret=CFRange(location:telegramCaret.location+text.utf16.count,length:0)
        return true
    },advancesCaret:true)
    precondition(telegramInput.edit(text:"hello",ticket:EditorTicket(),word:true))
    precondition(telegramInput.edit(text:"world",ticket:EditorTicket(),word:true))
    precondition(telegramText=="hello world" && telegramCaret.location==11 && telegramSets==2)
    print("PASS: Codex/Telegram routing, conditional spaces with native caret movement, and focus/cancellation gates (no events posted by tests)")
    let ownerA=AXUIElementCreateApplication(1),ownerB=AXUIElementCreateApplication(2)
    precondition(correctionOwnerMatches(pid:1,field:ownerA,committedPID:1,committedField:ownerA))
    precondition(!correctionOwnerMatches(pid:1,field:ownerB,committedPID:1,committedField:ownerA),"Correction crossed fields")
    precondition(!correctionOwnerMatches(pid:2,field:ownerA,committedPID:1,committedField:ownerA),"Correction crossed apps")
    precondition(!correctionOwnerMatches(pid:1,field:ownerA,committedPID:nil,committedField:nil))
    print("PASS: corrections require the original app and AX element")
    for scale in [0.25,0.5,1.0,2.0] {
        for family in ["System","Rounded","Monospaced"] {
            for size in [8.0,12.0,24.0] {
                let words=["hello","suggestions","accessibility","internationalization","electroencephalography"]
                let layout=SuggestionLayout(words:words,scale:scale,fontName:family,fontSize:size,maxWidth:800)
                for (word,cell) in zip(words,layout.cells) {
                    let style=NSMutableParagraphStyle();style.lineBreakMode = .byCharWrapping
                    let measured=(word as NSString).boundingRect(with:NSSize(width:cell.width-12/scale,height:.greatestFiniteMagnitude),options:[.usesLineFragmentOrigin,.usesFontLeading],attributes:[.font:layout.font,.paragraphStyle:style])
                    precondition(ceil(measured.height)<=cell.height-12/scale,"Suggestion text clipped")
                    precondition(NSRect(origin:.zero,size:layout.size).contains(cell),"Suggestion outside panel")
                }
                let empty=SuggestionLayout(words:[],scale:scale,fontName:family,fontSize:size,maxWidth:800)
                precondition(zip(empty.cells,layout.cells).allSatisfy {$0.width==$1.width && $0.minX==$1.minX},"Predictions changed slot widths")
                precondition(layout.size.height>=empty.size.height,"Long words lost required space")
                let keysFromBottom=layout.size.height-layout.viewport.minY
                precondition(abs(keysFromBottom-(empty.size.height-empty.viewport.minY))<0.01,"Extra lines moved the letter keyboard")
                let frame=NSRect(x:-1200,y:-120,width:layout.size.width*scale,height:layout.size.height*scale)
                let screen=layout.screenViewport(panel:frame,desktopTop:1000)
                let h=screen.normalized(PadPoint(x:frame.midX+70.8*scale,y:1120-230*scale))
                let q=screen.normalized(PadPoint(x:frame.midX-318.6*scale,y:1120-302.8*scale))
                precondition(KeyboardGeometry.key(at:h)?.label=="h" && KeyboardGeometry.key(at:q)?.label=="q","Production screen-to-key transform misaligned")
                precondition(abs(layout.font.pointSize*scale-size)<0.01,"Suggestion font changed size")
                precondition(layout.size.width*scale<=800,"Panel exceeds screen width")
                for i in layout.cells.indices {for j in layout.cells.indices where i<j {precondition(!layout.cells[i].intersects(layout.cells[j]))}}
            }
        }
    }
    let short=SuggestionLayout(words:["hello","world"],scale:0.5,fontName:"Monospaced",fontSize:12,maxWidth:1200)
    let long=SuggestionLayout(words:["internationalization"],scale:0.5,fontName:"Monospaced",fontSize:12,maxWidth:1200)
    precondition(long.cells[0].height>short.cells[0].height,"Second line did not appear")
    print("PASS: fixed suggestion widths, dynamic text lines, stable keyboard position, and unchanged font size")
} else {
    let app=NSApplication.shared
    app.setActivationPolicy(.accessory)
    let delegate=AppController();controller=delegate;app.delegate=delegate
    app.run()
}
