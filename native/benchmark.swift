import Foundation

let dictionary=try String(contentsOfFile:CommandLine.arguments[1],encoding:.utf8)
let decoder=PathDecoder(dictionary:dictionary)
let words=["hello","world","swipe","keyboard","trackpad","type","quick","brown","fox","jumps","over","lazy","dog","test","good","morning","thank","you","please","yes","no"]
var first=0,five=0;var timings:[Double]=[]
for word in words {
    let ideal=PathDecoder.resample(KeyboardGeometry.wordPath(word),count:80)
    let jittered=ideal.enumerated().map {i,p in PadPoint(x:p.x+sin(Double(i)*0.71)*0.008,y:p.y+cos(Double(i)*0.63)*0.008)}
    let begin=Date();let guesses=decoder.predict(jittered);let ms=Date().timeIntervalSince(begin)*1000
    timings.append(ms)
    if guesses.first?.word==word {first+=1}
    if guesses.contains(where:{$0.word==word}) {five+=1}
    print("\(word): \(guesses.map{$0.word}.joined(separator:", ")) [\(String(format:"%.1f",ms))ms]")
}
timings.sort()
print("SYNTHETIC BASELINE: words=\(decoder.wordCount) cases=\(words.count) top1=\(first) top5=\(five) p95_ms=\(String(format:"%.1f",timings[Int(Double(timings.count-1)*0.95)]))")
print("These are generated paths with small deterministic jitter, not measured human swipe accuracy.")

var liveTimes:[Double]=[]
for word in words {
    let ideal=PathDecoder.resample(KeyboardGeometry.wordPath(word),count:80)
    for count in [20,40,60,80] {
        let start=Date();_ = decoder.predict(Array(ideal.prefix(count)),partial:true)
        liveTimes.append(Date().timeIntervalSince(start)*1000)
    }
}
liveTimes.sort()
print("LIVE PREFIX: calls=\(liveTimes.count) p95_ms=\(String(format:"%.1f",liveTimes[Int(Double(liveTimes.count-1)*0.95)])) max_ms=\(String(format:"%.1f",liveTimes.last!))")
