// Appended to production declarations by render-demo.sh. No desktop input is posted.
import ImageIO
import UniformTypeIdentifiers

let demoOutput=URL(fileURLWithPath:CommandLine.arguments[1])
let demoDecoder=PathDecoder(dictionary:try String(contentsOfFile:CommandLine.arguments[2],encoding:.utf8))
let demoOwner=AppController(),demoCanvas=KeyboardCanvas()
let demoScale:CGFloat=0.72
let demoLayout=SuggestionLayout(words:[],scale:demoScale,fontName:"System",fontSize:12,maxWidth:750)
demoCanvas.owner=demoOwner
let demoWidth=960,demoHeight=720
let demoWords=["hello","world","known"]
let demoPaths=demoWords.map{PathDecoder.resample(KeyboardGeometry.wordPath($0),count:40)}
let demoResults=demoPaths.map{demoDecoder.predict($0)}
for index in demoWords.indices {precondition(demoResults[index].first?.word==demoWords[index])}
let demoPartial=demoPaths.map {path in
    (1...10).map{demoDecoder.predict(Array(path.prefix(max(2,$0*path.count/10))),partial:true)}
}
// Exercise production spacing with an in-memory editor, including a typed hyphen.
var demoDocument="",demoSelection=CFRange(location:0,length:0)
let demoReader=EditorTextReader(parameterized:{_ in nil},value:{demoDocument})
let demoEditor=EditorTransaction(matches:{true},caret:{demoSelection},read:demoReader.read,select:{range in
    demoSelection=range;return true
},insert:{text in
    demoDocument=(demoDocument as NSString).replacingCharacters(in:NSRange(location:demoSelection.location,length:demoSelection.length),with:text)
    return true
},verify:{text,range in demoReader.read(range)==text})
func demoCommit(_ word:String)->String {
    precondition(demoEditor.edit(text:word,ticket:EditorTicket(),word:true));return demoDocument
}
let demoHello=demoCommit("hello"),demoWorld=demoCommit("world")
demoDocument+=" well-";demoSelection=CFRange(location:demoDocument.utf16.count,length:0)
let demoHyphen=demoDocument,demoKnown=demoCommit("known")
precondition(demoHello=="hello" && demoWorld=="hello world" && demoKnown=="hello world well-known")

func demoText(_ text:String,_ rect:NSRect,_ size:CGFloat,_ color:NSColor = .white) {
    (text as NSString).draw(in:rect,withAttributes:[.font:NSFont.systemFont(ofSize:size,weight:.medium),.foregroundColor:color])
}
func demoRounded(_ rect:NSRect,_ color:NSColor,_ radius:CGFloat=12) {
    color.setFill();NSBezierPath(roundedRect:rect,xRadius:radius,yRadius:radius).fill()
}
func demoArrow(_ point:NSPoint,click:Bool) {
    let cursor=NSBezierPath();cursor.move(to:point)
    for offset in [NSPoint(x:0,y:22),NSPoint(x:6,y:16),NSPoint(x:11,y:27),NSPoint(x:16,y:25),NSPoint(x:11,y:14),NSPoint(x:20,y:14)] {
        cursor.line(to:NSPoint(x:point.x+offset.x,y:point.y+offset.y))
    }
    cursor.close();NSColor.white.setFill();cursor.fill();NSColor.black.setStroke();cursor.lineWidth=1;cursor.stroke()
    if click {NSColor.systemBlue.setStroke();let ring=NSBezierPath(ovalIn:NSRect(x:point.x-14,y:point.y-14,width:28,height:28));ring.lineWidth=2;ring.stroke()}
}
// Click into the editor, open beside the pointer, then show three complete strokes.
let demoStarts=[2.8,6.4,11.0]
let demoEnds=demoStarts.map{$0+40.0/18}
var demoTimeline:[(Double,Double)]=[(0,0.5),(0.5,0.4),(0.9,0.5),(1.4,0.6),(2.0,0.5),(2.5,0.3)]
for index in demoWords.indices {
    if index==1 {demoTimeline += [(6.0,0.4)]}
    if index==2 {demoTimeline += [(10.0,0.7),(10.7,0.3)]}
    demoTimeline += (0..<40).map{(demoStarts[index]+Double($0)/18,1.0/18)}
    demoTimeline += [(demoEnds[index],0.25),(demoEnds[index]+0.25,index==2 ? 2.0 : 0.65)]
}
let destination=CGImageDestinationCreateWithURL(demoOutput as CFURL,UTType.gif.identifier as CFString,0,nil)!
CGImageDestinationSetProperties(destination,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
var savedTrace=false
for (frameIndex,frame) in demoTimeline.enumerated() {
    let time=frame.0,stroke=time>=10 ? 2 : time>=6 ? 1 : 0
    let start=demoStarts[stroke],end=demoEnds[stroke],recording=time>=start && time<end,committed=time>=end+0.25
    let path=demoPaths[stroke],progress=min(path.count-1,max(0,Int((time-start)*18)))
    let shownText=stroke==2 ? (committed ? demoKnown : demoHyphen) : stroke==1 ? (committed ? demoWorld : demoHello) : committed ? demoHello : ""
    demoOwner.path=recording ? Array(path.prefix(progress+1)) : []
    demoOwner.finger=time>=2.5 ? path[progress] : nil
    demoOwner.guesses=committed ? demoResults[stroke] : recording ? demoPartial[stroke][min(9,progress*10/path.count)] : []
    let layout=SuggestionLayout(words:demoOwner.guesses.map(\.word),scale:demoScale,fontName:"System",fontSize:12,maxWidth:750)
    demoCanvas.layout=layout;demoCanvas.frame=NSRect(origin:.zero,size:NSSize(width:layout.size.width*demoScale,height:layout.size.height*demoScale))
    let origin=NSPoint(x:160,y:220-(layout.size.height-demoLayout.size.height)*demoScale)
    demoOwner.banner=recording ? "Recording · click again to enter the word · Esc cancels" : committed ? "\(demoWords[stroke]) · click another prediction to correct" : "Move onto a starting key · click, trace, click again"
    let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:demoWidth,pixelsHigh:demoHeight,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
    let context=NSGraphicsContext(bitmapImageRep:bitmap)!
    NSGraphicsContext.saveGraphicsState()
    context.cgContext.translateBy(x:0,y:CGFloat(demoHeight));context.cgContext.scaleBy(x:1,y:-1)
    NSGraphicsContext.current=NSGraphicsContext(cgContext:context.cgContext,flipped:true)
    NSColor(calibratedWhite:0.045,alpha:1).setFill();NSRect(x:0,y:0,width:demoWidth,height:demoHeight).fill()
    demoText("TrackpadSwipe",NSRect(x:30,y:20,width:900,height:36),25)
    let step=time<1.4 ? "Click into a text field" : time<2 ? "Rest three fingers and physically click to open" : stroke==2 ? "After a typed hyphen: swipe known → well-known" : stroke==1 ? "Swipe world · a space goes before the next word" : "Swipe hello · no space before the first word"
    demoText(step,NSRect(x:30,y:60,width:900,height:28),16,.systemCyan)
    demoRounded(NSRect(x:30,y:104,width:900,height:570),NSColor(calibratedWhite:0.11,alpha:1),16)
    demoText("Write a message",NSRect(x:52,y:120,width:800,height:24),14,.lightGray)
    demoRounded(NSRect(x:52,y:154,width:856,height:58),NSColor(calibratedWhite:0.17,alpha:1),8)
    demoText(time<0.5 ? "Your message…" : shownText,NSRect(x:68,y:167,width:800,height:34),23,time<0.5 ? .gray : .white)
    if time>=0.5 {
        let width=(shownText as NSString).size(withAttributes:[.font:NSFont.systemFont(ofSize:23,weight:.medium)]).width
        NSColor.systemBlue.setFill();NSRect(x:68+ceil(width)+2,y:166,width:2,height:29).fill()
    }
    if time>=2 {
        context.cgContext.saveGState();context.cgContext.translateBy(x:origin.x,y:origin.y)
        demoCanvas.draw(demoCanvas.bounds);context.cgContext.restoreGState()
    }
    if !recording && !committed && time<end {
        let key=demoLayout.viewport.screenPoint(path[0])
        let cursor=time>=2.5 ? NSPoint(x:origin.x+CGFloat(key.x)*demoScale,y:origin.y+CGFloat(key.y)*demoScale) : NSPoint(x:144,y:183)
        demoArrow(cursor,click:time==0.5 || time==1.4 || time==2.5 || time==6 || time==10.7)
    }
    if time>=end && !committed {
        let point=demoLayout.viewport.screenPoint(path.last!)
        NSColor.systemBlue.setStroke();let ring=NSBezierPath(ovalIn:NSRect(x:origin.x+CGFloat(point.x)*demoScale-14,y:origin.y+CGFloat(point.y)*demoScale-14,width:28,height:28));ring.lineWidth=2;ring.stroke()
    }
    demoText("Illustrated walkthrough · production keyboard, decoder, and conditional spacing",NSRect(x:30,y:688,width:900,height:20),11,.gray)
    NSGraphicsContext.restoreGraphicsState()
    CGImageDestinationAddImage(destination,bitmap.cgImage!,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:frame.1]] as CFDictionary)
    if (!savedTrace && stroke==1 && progress==25) || frameIndex==demoTimeline.count-1 {
        let suffix=frameIndex==demoTimeline.count-1 ? "result" : "trace"
        try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:demoOutput.deletingPathExtension().path+"-\(suffix).png"))
        if suffix=="trace" {savedTrace=true}
    }
}
precondition(CGImageDestinationFinalize(destination))
print("Created \(demoOutput.path): \(demoTimeline.count) frames; \(demoTimeline.reduce(0){$0+$1.1}) seconds")
