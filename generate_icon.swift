import Cocoa

let S: CGFloat = 1024
let CR: CGFloat = 224
let black = NSColor.black.cgColor
let white = NSColor.white.cgColor

func saveSet(_ img: NSImage) {
    let fm = FileManager.default
    let outDir = URL(fileURLWithPath: fm.currentDirectoryPath).appendingPathComponent("AppIcon.iconset")
    try? fm.createDirectory(at: outDir, withIntermediateDirectories: true)
    for (sz, mul) in [(16,1),(16,2),(32,1),(32,2),(128,1),(128,2),(256,1),(256,2),(512,1),(512,2)] {
        let px = sz * mul
        guard let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        let cx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)!
        cx.translateBy(x: 0, y: CGFloat(px)); cx.scaleBy(x: 1, y: -1)
        cx.interpolationQuality = .high
        cx.draw(cg, in: CGRect(x: 0, y: 0, width: px, height: px))
        guard let r = cx.makeImage(), let d = NSBitmapImageRep(cgImage: r).representation(using: .png, properties: [:]) else { continue }
        try? d.write(to: outDir.appendingPathComponent("icon_\(sz)x\(sz)\(mul > 1 ? "@\(mul)x" : "").png"))
    }
    print("🎨 Icon set saved")
}

// ─── Cat silhouette (Japanese style) ───
func makeIcon() -> NSImage {
    let img = NSImage(size: NSSize(width: S, height: S))
    img.lockFocusFlipped(false)
    guard let ctx = NSGraphicsContext.current?.cgContext else { return img }

    // Clip to rounded rect
    let R = CGRect(x: 0, y: 0, width: S, height: S)
    ctx.addPath(CGPath(roundedRect: R, cornerWidth: CR, cornerHeight: CR, transform: nil))
    ctx.clip()
    // White background
    ctx.setFillColor(white)
    ctx.fill(R)

    ctx.setFillColor(black)

    // Draw cat as solid silhouette, built from overlapping shapes

    // Body - large oval, slightly tilted
    ctx.addEllipse(in: CGRect(x: S*0.28, y: S*0.22, width: S*0.44, height: S*0.50))
    ctx.fillPath()

    // Head - circle overlapping body
    ctx.addEllipse(in: CGRect(x: S*0.35, y: S*0.58, width: S*0.30, height: S*0.28))
    ctx.fillPath()

    // Ears - triangles on top of head
    let earPath = CGMutablePath()
    // Left ear
    earPath.move(to: CGPoint(x: S*0.38, y: S*0.58))
    earPath.addLine(to: CGPoint(x: S*0.35, y: S*0.72))
    earPath.addLine(to: CGPoint(x: S*0.44, y: S*0.62))
    earPath.closeSubpath()
    // Right ear
    earPath.move(to: CGPoint(x: S*0.62, y: S*0.58))
    earPath.addLine(to: CGPoint(x: S*0.65, y: S*0.72))
    earPath.addLine(to: CGPoint(x: S*0.56, y: S*0.62))
    earPath.closeSubpath()
    ctx.addPath(earPath)
    ctx.fillPath()

    // Tail - curved shape wrapping to the right
    ctx.setLineWidth(S*0.08)
    ctx.setLineCap(.round)
    ctx.setStrokeColor(black)
    ctx.beginPath()
    ctx.move(to: CGPoint(x: S*0.30, y: S*0.35))
    ctx.addCurve(to: CGPoint(x: S*0.18, y: S*0.22),
                 control1: CGPoint(x: S*0.22, y: S*0.40),
                 control2: CGPoint(x: S*0.12, y: S*0.30))
    ctx.strokePath()

    // Eyes - white dots
    ctx.setFillColor(white)
    ctx.fillEllipse(in: CGRect(x: S*0.42, y: S*0.68, width: S*0.04, height: S*0.055))
    ctx.fillEllipse(in: CGRect(x: S*0.54, y: S*0.68, width: S*0.04, height: S*0.055))

    // Nose - tiny black triangle/dot
    ctx.setFillColor(black)
    ctx.fillEllipse(in: CGRect(x: S*0.49, y: S*0.73, width: S*0.022, height: S*0.018))

    img.unlockFocus()
    return img
}

let icon = makeIcon()
guard let cg = icon.cgImage(forProposedRect: nil, context: nil, hints: nil) else { exit(1) }
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let cx = CGContext(data: nil, width: 512, height: 512, bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)!
cx.translateBy(x: 0, y: 512); cx.scaleBy(x: 1, y: -1)
cx.interpolationQuality = .high
cx.draw(cg, in: CGRect(x: 0, y: 0, width: 512, height: 512))
guard let r = cx.makeImage(), let d = NSBitmapImageRep(cgImage: r).representation(using: .png, properties: [:]) else { exit(1) }
try? d.write(to: URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("preview.png"))
print("✅ preview")

saveSet(icon)
print("Done")
