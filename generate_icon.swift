import Cocoa

// MARK: - NotchDrop Icon — Cute Cat  🐱

let S: CGFloat = 1024
let CR: CGFloat = 224

// Colour helpers
func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    NSColor(calibratedRed: r/255, green: g/255, blue: b/255, alpha: a).cgColor
}

func nsrgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: r/255, green: g/255, blue: b/255, alpha: a)
}

func makeGrad(_ cs: [CGColor], _ locs: [CGFloat]? = nil) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
               colors: cs as CFArray, locations: locs)!
}

func radGrad(_ ctx: CGContext, _ c1: CGColor, _ c2: CGColor, _ center: CGPoint, _ r1: CGFloat, _ r2: CGFloat) {
    let g = makeGrad([c1, c2], [0, 1])
    ctx.drawRadialGradient(g, startCenter: center, startRadius: r1, endCenter: center, endRadius: r2, options: [])
}

func roundRect(_ r: CGRect, _ cr: CGFloat) -> CGPath {
    CGPath(roundedRect: r, cornerWidth: cr, cornerHeight: cr, transform: nil)
}

func fillOval(_ ctx: CGContext, _ r: CGRect, _ color: CGColor) {
    ctx.addEllipse(in: r)
    ctx.setFillColor(color)
    ctx.fillPath()
}

func fillRound(_ ctx: CGContext, _ r: CGRect, _ cr: CGFloat, _ color: CGColor) {
    ctx.addPath(roundRect(r, cr))
    ctx.setFillColor(color)
    ctx.fillPath()
}

// MARK: - Main

func createIcon() -> NSImage {
    let img = NSImage(size: NSSize(width: S, height: S))
    img.lockFocusFlipped(false)
    guard let ctx = NSGraphicsContext.current?.cgContext else { img.unlockFocus(); return img }

    let R = CGRect(x: 0, y: 0, width: S, height: S)

    // Clip
    ctx.addPath(roundRect(R, CR))
    ctx.clip()

    // ── Background: warm cream → peach gradient ──
    let bg = makeGrad([rgb(255, 248, 240), rgb(255, 235, 215), rgb(255, 225, 200)])
    ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: S), end: CGPoint(x: S, y: 0), options: [])

    // ── Subtle background glow ──
    radGrad(ctx, rgb(255, 200, 150, 0.15), .clear, CGPoint(x: S/2, y: S/2), 0, S*0.45)

    // ── Helper to draw a cute paw ──
    func drawPaw(_ cx: CGFloat, _ cy: CGFloat, _ w: CGFloat, _ h: CGFloat) {
        let pr = CGRect(x: cx - w/2, y: cy - h/2, width: w, height: h)
        fillOval(ctx, pr, rgb(210, 180, 155))
        // Paw pads (small dots)
        let padSize = w * 0.22
        let padY = cy - h * 0.25
        let padX = cx
        fillOval(ctx, CGRect(x: padX - padSize/2, y: padY - padSize/2, width: padSize, height: padSize), rgb(190, 160, 140))
        fillOval(ctx, CGRect(x: padX - padSize/2 - padSize*1.1, y: padY - padSize/2 + padSize*0.3, width: padSize*0.8, height: padSize*0.8), rgb(190, 160, 140))
        fillOval(ctx, CGRect(x: padX - padSize/2 + padSize*1.1, y: padY - padSize/2 + padSize*0.3, width: padSize*0.8, height: padSize*0.8), rgb(190, 160, 140))
    }

    // ── Cat Head ──
    let headDia = S * 0.60
    let headCX = S/2
    let headCY = S * 0.52
    let headRect = CGRect(x: headCX - headDia/2, y: headCY - headDia/2,
                          width: headDia, height: headDia)

    // Ears (behind head)
    func drawEar(_ cx: CGFloat, _ cy: CGFloat, _ scale: CGFloat) {
        let ew = S * 0.16 * scale
        let eh = S * 0.18 * scale
        // Ear triangle using rounded path
        let ear = NSBezierPath()
        ear.move(to: NSPoint(x: cx, y: cy + eh))
        ear.line(to: NSPoint(x: cx - ew/2, y: cy - eh/2))
        ear.line(to: NSPoint(x: cx + ew/2, y: cy - eh/2))
        ear.close()
        ear.lineJoinStyle = .round
        ear.lineCapStyle = .round
        ctx.addPath(ear.cgPath)
        ctx.setFillColor(rgb(200, 170, 145))
        ctx.fillPath()
        // Inner ear (pink)
        let innerEar = NSBezierPath()
        innerEar.move(to: NSPoint(x: cx, y: cy + eh * 0.5))
        innerEar.line(to: NSPoint(x: cx - ew/4, y: cy - eh/6))
        innerEar.line(to: NSPoint(x: cx + ew/4, y: cy - eh/6))
        innerEar.close()
        innerEar.lineJoinStyle = .round
        ctx.addPath(innerEar.cgPath)
        ctx.setFillColor(rgb(255, 190, 200))
        ctx.fillPath()
    }

    // Left ear (with a small notch cutout on the outer edge to hint at "notch")
    let earScale: CGFloat = 1.0
    let earY = headCY + headDia/2 - S * 0.04
    drawEar(headCX - headDia/2.7, earY, earScale)
    drawEar(headCX + headDia/2.7, earY, earScale)

    // Head circle
    fillOval(ctx, headRect, rgb(215, 185, 160))

    // ── Cat Face ──

    // Eyes
    let eyeY = headCY + S * 0.04
    let eyeSpacing = S * 0.12
    // Eye white (larger for cute look)
    let eyeWR = S * 0.095
    fillOval(ctx, CGRect(x: headCX - eyeSpacing - eyeWR/2, y: eyeY - eyeWR/2, width: eyeWR, height: eyeWR), rgb(255, 255, 255))
    fillOval(ctx, CGRect(x: headCX + eyeSpacing - eyeWR/2, y: eyeY - eyeWR/2, width: eyeWR, height: eyeWR), rgb(255, 255, 255))
    // Pupils (large dark)
    let pupilDia = S * 0.065
    fillOval(ctx, CGRect(x: headCX - eyeSpacing - pupilDia/2, y: eyeY - pupilDia/2, width: pupilDia, height: pupilDia), rgb(50, 50, 50))
    fillOval(ctx, CGRect(x: headCX + eyeSpacing - pupilDia/2, y: eyeY - pupilDia/2, width: pupilDia, height: pupilDia), rgb(50, 50, 50))
    // Eye highlights
    let hlDia = S * 0.025
    fillOval(ctx, CGRect(x: headCX - eyeSpacing + pupilDia*0.15, y: eyeY + pupilDia*0.15, width: hlDia, height: hlDia), rgb(255, 255, 255))
    fillOval(ctx, CGRect(x: headCX + eyeSpacing + pupilDia*0.15, y: eyeY + pupilDia*0.15, width: hlDia, height: hlDia), rgb(255, 255, 255))
    // Small secondary highlight
    let hl2 = S * 0.012
    fillOval(ctx, CGRect(x: headCX - eyeSpacing - pupilDia*0.2, y: eyeY - pupilDia*0.2, width: hl2, height: hl2), rgb(255, 255, 255, 0.7))
    fillOval(ctx, CGRect(x: headCX + eyeSpacing - pupilDia*0.2, y: eyeY - pupilDia*0.2, width: hl2, height: hl2), rgb(255, 255, 255, 0.7))

    // Eyebrows (tiny dots above eyes, cute)
    let browDia = S * 0.018
    fillOval(ctx, CGRect(x: headCX - eyeSpacing - browDia/2, y: eyeY + eyeWR*0.8 - browDia/2, width: browDia, height: browDia), rgb(170, 140, 120))
    fillOval(ctx, CGRect(x: headCX + eyeSpacing - browDia/2, y: eyeY + eyeWR*0.8 - browDia/2, width: browDia, height: browDia), rgb(170, 140, 120))

    // Nose (small pink triangle/oval)
    let noseY = headCY - S * 0.055
    fillOval(ctx, CGRect(x: headCX - S*0.025, y: noseY - S*0.015, width: S*0.050, height: S*0.030), rgb(255, 140, 155))

    // Mouth
    ctx.setStrokeColor(rgb(170, 130, 130))
    ctx.setLineWidth(2.5)
    ctx.setLineCap(.round)
    let mouthPath = NSBezierPath()
    mouthPath.move(to: NSPoint(x: headCX - S*0.04, y: noseY - S*0.01))
    mouthPath.curve(to: NSPoint(x: headCX, y: noseY - S*0.04),
                    controlPoint1: NSPoint(x: headCX - S*0.02, y: noseY - S*0.035),
                    controlPoint2: NSPoint(x: headCX, y: noseY - S*0.02))
    mouthPath.move(to: NSPoint(x: headCX + S*0.04, y: noseY - S*0.01))
    mouthPath.curve(to: NSPoint(x: headCX, y: noseY - S*0.04),
                    controlPoint1: NSPoint(x: headCX + S*0.02, y: noseY - S*0.035),
                    controlPoint2: NSPoint(x: headCX, y: noseY - S*0.02))
    ctx.addPath(mouthPath.cgPath)
    ctx.strokePath()

    // Blush
    let blushDia = S * 0.065
    fillOval(ctx, CGRect(x: headCX - S*0.18 - blushDia/2, y: noseY - S*0.04 - blushDia/2, width: blushDia, height: blushDia), rgb(255, 180, 180, 0.25))
    fillOval(ctx, CGRect(x: headCX + S*0.18 - blushDia/2, y: noseY - S*0.04 - blushDia/2, width: blushDia, height: blushDia), rgb(255, 180, 180, 0.25))

    // Whiskers
    ctx.setStrokeColor(rgb(190, 160, 145))
    ctx.setLineWidth(2)
    func whisker(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) {
        ctx.beginPath()
        ctx.move(to: CGPoint(x: x1, y: y1))
        ctx.addLine(to: CGPoint(x: x2, y: y2))
        ctx.strokePath()
    }
    let wY = noseY - S*0.01
    let wXoffset: CGFloat = S*0.09
    let wLen: CGFloat = S*0.12
    whisker(headCX - wXoffset, wY, headCX - wXoffset - wLen, wY + S*0.02)
    whisker(headCX - wXoffset, wY - S*0.01, headCX - wXoffset - wLen*0.9, wY - S*0.03)
    whisker(headCX - wXoffset, wY + S*0.02, headCX - wXoffset - wLen*0.85, wY + S*0.07)
    whisker(headCX + wXoffset, wY, headCX + wXoffset + wLen, wY + S*0.02)
    whisker(headCX + wXoffset, wY - S*0.01, headCX + wXoffset + wLen*0.9, wY - S*0.03)
    whisker(headCX + wXoffset, wY + S*0.02, headCX + wXoffset + wLen*0.85, wY + S*0.07)

    // ── Paws holding a folder ──
    let pawY = headCY - headDia/2 + S*0.08
    drawPaw(headCX - S*0.12, pawY, S*0.10, S*0.13)
    drawPaw(headCX + S*0.12, pawY, S*0.10, S*0.13)

    // Extra paw marks at bottom
    let bottomPawY = S*0.08
    drawPaw(S*0.18, bottomPawY, S*0.07, S*0.09)
    drawPaw(S*0.32, bottomPawY - S*0.015, S*0.065, S*0.085)

    // ── Folder Icon (held between paws, slightly below) ──
    let fw = S * 0.22
    let fh = S * 0.15
    let fx = (S - fw) / 2
    let fy = pawY - S*0.04  // held by paws

    // Folder body
    let fCol1 = rgb(70, 140, 255)
    let fCol2 = rgb(130, 80, 230)
    let fGrad = makeGrad([fCol1, fCol2])
    let folderRect = CGRect(x: fx, y: fy, width: fw, height: fh)
    fillRound(ctx, folderRect, 16, .white)

    // Gradient fill
    ctx.saveGState()
    ctx.addPath(roundRect(folderRect, 16))
    ctx.clip()
    ctx.drawLinearGradient(fGrad,
                           start: CGPoint(x: 0, y: fy + fh),
                           end: CGPoint(x: S, y: fy), options: [])
    ctx.restoreGState()

    // Folder flap
    let flapH = fh * 0.3
    let flapRect = CGRect(x: fx + fw*0.08, y: fy + fh - flapH*0.3,
                          width: fw*0.84, height: flapH)
    fillRound(ctx, flapRect, 10, rgb(60, 120, 230, 0.3))
    ctx.addPath(roundRect(flapRect, 10))
    ctx.setStrokeColor(rgb(255, 255, 255, 0.15))
    ctx.setLineWidth(1)
    ctx.strokePath()

    // File icon inside folder
    let docW = fw * 0.40
    let docH = fh * 0.35
    let docX = fx + (fw - docW) / 2
    let docY = fy + (fh - docH) / 2 - fh*0.02
    fillRound(ctx, CGRect(x: docX, y: docY, width: docW, height: docH), 4, rgb(255, 255, 255, 0.60))
    // File lines
    let lineW = docW * 0.55
    let lineH: CGFloat = 2.5
    let lineX = docX + docW * 0.12
    let lineY = docY + docH * 0.25
    fillRound(ctx, CGRect(x: lineX, y: lineY, width: lineW, height: lineH), 1, rgb(255, 255, 255, 0.70))
    fillRound(ctx, CGRect(x: lineX, y: lineY + docH*0.28, width: lineW*0.65, height: lineH), 1, rgb(255, 255, 255, 0.50))
    fillRound(ctx, CGRect(x: lineX, y: lineY + docH*0.56, width: lineW*0.8, height: lineH), 1, rgb(255, 255, 255, 0.40))

    // ── Notch pill at top ──
    let pillW = S * 0.10
    let pillH = S * 0.012
    let pillR = CGRect(x: (S - pillW)/2, y: S - S*0.03 - pillH, width: pillW, height: pillH)
    ctx.setShadow(offset: .zero, blur: 20, color: rgb(100, 150, 255, 0.4))
    fillRound(ctx, pillR, pillH/2, rgb(255, 255, 255, 0.70))
    ctx.setShadow(offset: .zero, blur: 0, color: nil)
    fillRound(ctx, pillR, pillH/2, rgb(255, 255, 255, 0.85))

    // ── Top-left shine ──
    ctx.saveGState()
    ctx.addPath(roundRect(R, CR))
    ctx.clip()
    radGrad(ctx, rgb(255, 255, 255, 0.08), .clear,
            CGPoint(x: S*0.15, y: S*0.85), 0, S*0.65)
    ctx.restoreGState()

    img.unlockFocus()
    return img
}

// MARK: - Save PNG

func saveScaledPNG(_ source: NSImage, pixelSize: Int, to url: URL) {
    let w = pixelSize, h = pixelSize
    guard let cgImage = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: w, height: h,
                        bitsPerComponent: 8, bytesPerRow: 0,
                        space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)!
    ctx.translateBy(x: 0, y: CGFloat(h)); ctx.scaleBy(x: 1, y: -1)
    ctx.interpolationQuality = .high
    ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
    guard let result = ctx.makeImage() else { return }
    guard let data = NSBitmapImageRep(cgImage: result).representation(using: .png, properties: [:]) else { return }
    try? data.write(to: url)
    print("✅ \(url.lastPathComponent)  \(w)×\(h)  \(data.count / 1024) KB")
}

// MARK: - Main

let fm = FileManager.default
let outDir = URL(fileURLWithPath: fm.currentDirectoryPath).appendingPathComponent("AppIcon.iconset")
try? fm.createDirectory(at: outDir, withIntermediateDirectories: true)
let icon = createIcon()
for (sz, mul) in [(16,1),(16,2),(32,1),(32,2),(128,1),(128,2),(256,1),(256,2),(512,1),(512,2)] {
    let px = sz * mul
    saveScaledPNG(icon, pixelSize: px, to: outDir.appendingPathComponent("icon_\(sz)x\(sz)\(mul > 1 ? "@\(mul)x" : "").png"))
}
print("\n🎨 Done → \(outDir.path)")
