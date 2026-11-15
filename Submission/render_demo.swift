import AppKit
import AVFoundation
import CoreVideo

let args = CommandLine.arguments
let source = URL(fileURLWithPath: args[1])
let output = URL(fileURLWithPath: args[2])
let asset = AVURLAsset(url: source)
let generator = AVAssetImageGenerator(asset: asset)
generator.appliesPreferredTrackTransform = true
generator.maximumSize = CGSize(width: 1080, height: 1560)
generator.requestedTimeToleranceBefore = .zero
generator.requestedTimeToleranceAfter = .zero
struct Scene {
    let start: Double
    let end: Double
    let source: Double
    let heading: String
    let caption: String
    let evidence: String
}
let scenes = [
    Scene(start:0,end:4,source:525.053,heading:"PLAN BEFORE YOU LAUNCH.",caption:"A mission trainer for ages 7–12.\nLearn how power, storage and oxygen connect.",evidence:"Visible base • equipment and operating settings in one mission desk"),
    Scene(start:4,end:9,source:46.302,heading:"PREDICT. THEN EXPLAIN WHY.",caption:"Choose an outcome and a reason.\nYour equipment and settings decide what happens.",evidence:"Hypotheses change feedback; they never change the physics"),
    Scene(start:9,end:14,source:51.406,heading:"COMPARE WITH THE EVIDENCE.",caption:"Stored: 2.4 kWh. Needed: 3.6 kWh.\nThe starter plan stops at hour 10.",evidence:"An empty battery stores energy; it cannot generate electricity"),
    Scene(start:14,end:19.5,source:66.493,heading:"ONE CHANGE. A NEW RESULT.",caption:"Half air in shadow reaches all 12 hours.\nSave 1.5 kWh; spend 0.20 kg of tank oxygen.",evidence:"The original prediction and exact change stay visible"),
    Scene(start:19.5,end:24,source:273.876,heading:"SHELTER. SCIENCE. SURVIVAL.",caption:"Protect the crew and complete a science task\nduring a 98-hour archived storm.",evidence:"CCMC timestamps • explicit training rules • no radiation dose"),
    Scene(start:24,end:29,source:96.245,heading:"TRACEABLE SCIENCE. OFFLINE PLAY.",caption:"NASA references drive the calculation.\nBuild. Predict. Observe. Revise.",evidence:"BVAD reference: 0.895 kg oxygen per adult crew member per day")
]
let width = 1080, height = 1920, fps: Int32 = 30
let writer = try AVAssetWriter(outputURL: output, fileType: .mp4)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: width, AVVideoHeightKey: height,
    AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 2_800_000, AVVideoMaxKeyFrameIntervalKey: 30]
])
input.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
    kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height,
    kCVPixelBufferCGImageCompatibilityKey as String: true,
    kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
])
writer.add(input)
let title = AVMutableMetadataItem(); title.identifier = .commonIdentifierTitle; title.value = "Moonbase Academy — 29-second project demonstration" as NSString
let creator = AVMutableMetadataItem(); creator.identifier = .commonIdentifierCreator; creator.value = "VANGUARD Systems" as NSString
let disclosure = AVMutableMetadataItem(); disclosure.identifier = .commonIdentifierDescription; disclosure.value = "Actual simulator footage with AI-assisted captions and editing. Archived NASA references; simplified training model. No AI-generated imagery or voices." as NSString
writer.metadata = [title, creator, disclosure]
func text(_ string: String, _ rect: CGRect, size: CGFloat, color: NSColor, weight: NSFont.Weight = .regular, centered: Bool = false) {
    let style = NSMutableParagraphStyle(); style.alignment = centered ? .center : .left; style.lineSpacing = 5
    let nsRect = NSRect(x:rect.minX,y:CGFloat(height)-rect.maxY,width:rect.width,height:rect.height)
    NSAttributedString(string:string, attributes:[.font:NSFont.systemFont(ofSize:size,weight:weight),.foregroundColor:color,.paragraphStyle:style]).draw(in:nsRect)
}
writer.startWriting(); writer.startSession(atSourceTime:.zero)
var cachedFrame: CGImage?
var cachedTime = -1.0
for index in 0..<(29*Int(fps)) {
    while !input.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 2_000_000) }
    try autoreleasepool {
        let time = Double(index)/Double(fps)
        let scene = scenes.first { time >= $0.start && time < $0.end }!
        // Slow a short, verified source window for readable captions; never fabricate app states.
        let sourceTime = scene.source + min(0.65, (time-scene.start)*0.12)
        let sampledTime = (sourceTime*15).rounded(.down)/15
        if sampledTime != cachedTime {
            cachedFrame = try generator.copyCGImage(at:CMTime(seconds:sampledTime,preferredTimescale:600),actualTime:nil)
            cachedTime = sampledTime
        }
        var buffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer)
        let pixel = buffer!
        CVPixelBufferLockBaseAddress(pixel, [])
        let ctx = CGContext(data:CVPixelBufferGetBaseAddress(pixel),width:width,height:height,bitsPerComponent:8,bytesPerRow:CVPixelBufferGetBytesPerRow(pixel),space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.noneSkipFirst.rawValue)!
        ctx.setFillColor(NSColor(calibratedRed:0.035,green:0.065,blue:0.12,alpha:1).cgColor); ctx.fill(CGRect(x:0,y:0,width:width,height:height))
        ctx.setFillColor(NSColor(calibratedRed:0.29,green:0.86,blue:0.9,alpha:1).cgColor);ctx.fill(CGRect(x:0,y:1908,width:1080,height:12))
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(cgContext:ctx,flipped:false)
        text("VANGUARD SYSTEMS  /  SPACE APPS 2026",CGRect(x:50,y:35,width:980,height:40),size:24,color:.cyan,weight:.bold)
        text("MOONBASE ACADEMY",CGRect(x:50,y:77,width:980,height:80),size:57,color:.white,weight:.black)
        let frame = cachedFrame!
        let box = CGRect(x:60,y:CGFloat(height)-1575,width:960,height:1382)
        ctx.saveGState();ctx.addPath(CGPath(roundedRect:box,cornerWidth:24,cornerHeight:24,transform:nil));ctx.clip();ctx.draw(frame,in:box);ctx.restoreGState()
        text(scene.heading,CGRect(x:50,y:1600,width:980,height:64),size:39,color:.cyan,weight:.black)
        text(scene.caption,CGRect(x:50,y:1669,width:980,height:112),size:36,color:.white,weight:.semibold)
        text(scene.evidence,CGRect(x:50,y:1798,width:980,height:65),size:23,color:NSColor(white:0.78,alpha:1))
        text("Actual app capture  •  AI-assisted editing",CGRect(x:50,y:1880,width:980,height:30),size:20,color:NSColor(white:0.65,alpha:1))
        NSGraphicsContext.restoreGraphicsState()
        CVPixelBufferUnlockBaseAddress(pixel, [])
        guard adaptor.append(pixel,withPresentationTime:CMTime(value:Int64(index),timescale:fps)) else { throw writer.error! }
    }
    if index % 150 == 0 { print("Rendered \(index / Int(fps)) seconds") }
}
input.markAsFinished()
await writer.finishWriting()
if let error = writer.error { throw error }
print("Wrote \(output.path)")
