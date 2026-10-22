import Foundation

struct PadPoint: Equatable {
    var x: Double
    var y: Double
    func distance(_ other: PadPoint) -> Double { hypot(x-other.x,y-other.y) }
}
struct Contact { var id: Int; var point: PadPoint }
enum KeyboardSizing {
    // New 100% is half the original 740 × 470 design size.
    static func scale(zoom:Double,availableWidth:Double,availableHeight:Double)->Double {
        let requested=min(4,max(0.5,zoom.isFinite ? zoom : 1))*0.5
        return min(requested,min((availableWidth-32)/740,(availableHeight-32)/470))
    }
}
struct PointerViewport {
    let minX:Double,minY:Double,width:Double,height:Double
    func normalized(_ point:PadPoint)->PadPoint {PadPoint(x:(point.x-minX)/width,y:(point.y-minY)/height)}
    func screenPoint(_ point:PadPoint)->PadPoint {PadPoint(x:minX+point.x*width,y:minY+point.y*height)}
}
struct ClickStroke {
    private(set) var active=false
    private(set) var point=PadPoint(x:0.5,y:0.5)
    mutating func begin(at point:PadPoint) {self.point=point;active=true}
    mutating func move(dx:Double,dy:Double,width:Double,height:Double,sensitivity:Double) {
        guard active,width>0,height>0,dx.isFinite,dy.isFinite else{return}
        let gain=min(2.5,max(0.5,sensitivity.isFinite ? sensitivity : 1))
        point=PadPoint(x:min(1,max(0,point.x+dx*gain/width)),y:min(1,max(0,point.y+dy*gain/height)))
    }
    mutating func end() {active=false}
}
struct PadKey {
    let label: String
    let x: Double, y: Double, width: Double, height: Double
    var center: PadPoint { PadPoint(x:x+width/2,y:y+height/2) }
    func contains(_ point: PadPoint) -> Bool {
        point.x >= x && point.x < x+width && point.y >= y && point.y < y+height
    }
}
enum KeyboardGeometry {
    static let keys: [PadKey] = ["qwertyuiop","asdfghjkl","zxcvbnm"].enumerated().flatMap { row,text in
        text.enumerated().map { column,char in
            PadKey(label:String(char),x:(Double(column)+[0,0.5,1.5][row])/10,
                   y:0.21+Double(row)*0.20,width:0.10,height:0.18)
        }
    }
    static let symbols: [PadKey] = [Array("1234567890"),Array(".,?!'\":;-_"),Array("()/@#$%&+=")].enumerated().flatMap { row,labels in
        labels.enumerated().map { column,char in
            PadKey(label:String(char),x:Double(column)/10,y:0.21+Double(row)*0.20,width:0.10,height:0.18)
        }
    }
    static func keys(symbols:Bool)->[PadKey] {symbols ? self.symbols : keys}
    static let commands: [PadKey] = ["Fn","Space","⌫","Return","Close"].enumerated().map { i,label in
        PadKey(label:label,x:Double(i)*0.20,y:0.84,width:0.20,height:0.14)
    }
    static let byLetter = Dictionary(uniqueKeysWithValues: keys.map { ($0.label,$0.center) })
    static func key(at point: PadPoint,symbols:Bool=false) -> PadKey? { keys(symbols:symbols).first { $0.contains(point) } }
    static func wordPath(_ word: String) -> [PadPoint] { word.compactMap { byLetter[String($0)] } }
}

enum SessionPhase: String { case idle,arming,ready }
struct SessionMachine {
    private(set) var phase: SessionPhase = .idle
    mutating func show() { if phase == .idle {phase = .arming} }
    mutating func contactsLifted() { if phase == .arming {phase = .ready} }
    mutating func hide() {phase = .idle}
}

struct WordGuess { let word: String; let score: Double }
/// Continuous-coordinate baseline. Geometry and hit testing share KeyboardGeometry.
enum DictionaryRules {
    static let maximumWordLength=22
    static func accepts(_ word:String)->Bool {
        guard (2...maximumWordLength).contains(word.count) else{return false}
        let parts=word.split(separator:"'",omittingEmptySubsequences:false)
        return parts.allSatisfy { !$0.isEmpty && $0.utf8.allSatisfy {$0>=97 && $0<=122} }
    }
}

// Remove the previous whitespace-delimited word, including trailing whitespace.
// Selected text is handled separately by the transaction.
enum WordDeletion {
    static func utf16Length(in prefix:String)->Int {
        var length=0,skippingWhitespace=true
        for char in prefix.reversed() {
            if char.isWhitespace {
                if !skippingWhitespace {break}
            } else {skippingWhitespace=false}
            length+=String(char).utf16.count
        }
        return length
    }
}

final class PathDecoder {
    struct Entry { let word:String; let frequency:Double; let path:[PadPoint] }
    private let entries: [Entry]
    let wordCount: Int
    let maximumWordLength:Int
    init(dictionary: String, limit: Int=60_000) {
        var built: [Entry]=[]
        for line in dictionary.split(separator:"\n") {
            let parts=line.split(separator:"\t")
            guard parts.count>=2 else {continue}
            let word=String(parts[0]).lowercased()
            guard DictionaryRules.accepts(word) else {continue}
            built.append(Entry(word:word,frequency:Double(parts[1]) ?? 1,path:Self.resample(KeyboardGeometry.wordPath(word),count:24)))
            if built.count>=limit {break}
        }
        entries=built;wordCount=built.count;maximumWordLength=built.map{$0.word.count}.max() ?? 0
    }
    static func resample(_ input:[PadPoint],count:Int) -> [PadPoint] {
        guard let first=input.first, count>1 else {return input}
        var distances=[0.0]
        for i in 1..<input.count { distances.append(distances.last!+input[i].distance(input[i-1])) }
        guard let total=distances.last,total>0.00001 else {return Array(repeating:first,count:count)}
        var result:[PadPoint]=[];var segment=1
        for i in 0..<count {
            let target=Double(i)/Double(count-1)*total
            while segment<distances.count-1 && distances[segment]<target {segment+=1}
            let fraction=(target-distances[segment-1])/max(0.000001,distances[segment]-distances[segment-1])
            let a=input[segment-1],b=input[segment]
            result.append(PadPoint(x:a.x+(b.x-a.x)*fraction,y:a.y+(b.y-a.y)*fraction))
        }
        return result
    }
    private static func dtw(_ a:[PadPoint],_ b:[PadPoint]) -> Double {
        var previous=Array(repeating:Double.infinity,count:b.count+1);previous[0]=0
        for p in a {
            var current=Array(repeating:Double.infinity,count:b.count+1)
            for j in 1...b.count {
                // Match keyboard units, rather than the rectangular pad's raw aspect.
                let dx=(p.x-b[j-1].x)*10,dy=(p.y-b[j-1].y)*5
                current[j]=hypot(dx,dy)+min(previous[j],previous[j-1],current[j-1])
            }
            previous=current
        }
        return previous[b.count]/Double(a.count+b.count)
    }
    func predict(_ raw:[PadPoint],limit:Int=5,partial:Bool=false) -> [WordGuess] {
        guard raw.count>=2,let start=raw.first,let end=raw.last else {return []}
        let path=Self.resample(raw,count:24)
        var best:[WordGuess]=[]
        for e in entries {
            let first=e.path.first!
            guard abs(first.x-start.x)<0.16,abs(first.y-start.y)<0.22 else {continue}
            var candidate=e.path
            if partial {
                // Match the drawn path to a word prefix, not its as-yet-undrawn end.
                let index=e.path.indices.min { a,b in
                    let pa=e.path[a],pb=e.path[b]
                    return pow((pa.x-end.x)*10,2)+pow((pa.y-end.y)*5,2) < pow((pb.x-end.x)*10,2)+pow((pb.y-end.y)*5,2)
                }!
                candidate=Self.resample(Array(e.path.prefix(index+1)),count:24)
            }
            let last=candidate.last!
            guard abs(last.x-end.x)<0.18,abs(last.y-end.y)<0.23 else {continue}
            let startPenalty=start.distance(first)*3,endPenalty=end.distance(last)*4
            let score=Self.dtw(path,candidate)+startPenalty+endPenalty-log10(max(1,e.frequency))*0.018
            if best.count<limit || score<best.last!.score {
                best.append(WordGuess(word:e.word,score:score));best.sort {$0.score<$1.score}
                if best.count>limit {best.removeLast()}
            }
        }
        return best
    }
}

func runCoreTests() {
    var session=SessionMachine();session.show();session.show();precondition(session.phase == .arming)
    session.contactsLifted();session.show();precondition(session.phase == .ready)
    session.hide();session.hide();precondition(session.phase == .idle)
    for key in KeyboardGeometry.keys { precondition(KeyboardGeometry.key(at:key.center)?.label == key.label) }
    let dictionary="hello\t1000\nhelp\t500\nhill\t100\nworld\t1000\nword\t500\nswipe\t100\ntype\t100\n"
    for word in ["don't","can't","it's","you're"] {
        precondition(DictionaryRules.accepts(word))
        let contractions=PathDecoder(dictionary:"\(word)\t100\n")
        precondition(contractions.predict(KeyboardGeometry.wordPath(word)).first?.word==word)
    }
    for word in ["'hi","hi'","a''b","a1","éé"] {precondition(!DictionaryRules.accepts(word))}
    for (prefix,count) in [("",0),("hello",5),("hello world  ",7),("don't",5),("well-known",10),("hi 😀 ",3)] {
        precondition(WordDeletion.utf16Length(in:prefix)==count)
    }
    for symbols in [false,true] {
        for key in KeyboardGeometry.keys(symbols:symbols) {precondition(KeyboardGeometry.key(at:key.center,symbols:symbols)?.label==key.label)}
    }
    precondition(KeyboardGeometry.symbols.count==30)
    precondition(KeyboardGeometry.commands.first?.label=="Fn")
    print("PASS: contraction matching, word deletion boundaries, and letter/symbol hit testing")
    let decoder=PathDecoder(dictionary:dictionary)
    for word in ["hello","world","swipe","type"] {
        let guesses=decoder.predict(KeyboardGeometry.wordPath(word))
        precondition(guesses.first?.word == word,"Failed coordinate decoding: \(word)")
    }
    let prefix=Array(PathDecoder.resample(KeyboardGeometry.wordPath("hello"),count:80).prefix(35))
    precondition(decoder.predict(prefix,partial:true).contains(where:{$0.word=="hello"}),"Live prefix lost a valid completion")
    precondition(decoder.predict([],partial:true).isEmpty)
    precondition(PathDecoder.resample([PadPoint(x:0,y:0)],count:24).count==24)
    precondition(decoder.predict([]).isEmpty)
    var stroke=ClickStroke()
    stroke.move(dx:20,dy:20,width:100,height:100,sensitivity:1)
    precondition(stroke.point==PadPoint(x:0.5,y:0.5) && !stroke.active)
    let anchor=PadPoint(x:0.25,y:0.30);stroke.begin(at:anchor)
    precondition(stroke.point==anchor)
    stroke.move(dx:10,dy:5,width:100,height:50,sensitivity:1.5)
    precondition(abs(stroke.point.x-0.4)<0.00001 && abs(stroke.point.y-0.45)<0.00001)
    stroke.move(dx:10000,dy:-10000,width:100,height:50,sensitivity:1)
    precondition(stroke.point==PadPoint(x:1,y:0));stroke.end()
    stroke.move(dx:-50,dy:50,width:100,height:50,sensitivity:1)
    precondition(stroke.point==PadPoint(x:1,y:0) && !stroke.active)
    for gain in [0.5,1,1.5,2.5] {
        var subject=ClickStroke();subject.begin(at:PadPoint(x:0.1,y:0.1))
        subject.move(dx:10,dy:10,width:100,height:100,sensitivity:gain)
        precondition(abs(subject.point.x-(0.1+0.1*gain))<0.00001)
    }
    precondition(KeyboardSizing.scale(zoom:1,availableWidth:3000,availableHeight:2000)==0.5)
    precondition(KeyboardSizing.scale(zoom:0.5,availableWidth:3000,availableHeight:2000)==0.25)
    precondition(KeyboardSizing.scale(zoom:4,availableWidth:3000,availableHeight:2000)==2)
    precondition(KeyboardSizing.scale(zoom:4,availableWidth:800,availableHeight:600)<=768.0/740)
    print("PASS: session lifecycle, geometry, coordinate decoding, sensitivity bounds, click anchoring, click-off and hover isolation")
}
