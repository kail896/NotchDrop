import Cocoa

// Generate a recognizable 18x18 menu bar icon
let size: CGFloat = 18
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocusFlipped(false)
guard let ctx = NSGraphicsContext.current?.cgContext else { exit(1) }

ctx.setFillColor(NSColor.black.cgColor)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)

// Simple tray/folder shape - recognizable at small size
let path = CGMutablePath()

// Folder/tray body - a rounded rectangle
let bw: CGFloat = 14
let bh: CGFloat = 10
let bx = (size - bw) / 2
let by = (size - bh) / 2

path.addRoundedRect(in: CGRect(x: bx, y: by, width: bw, height: bh),
                     cornerWidth: 2, cornerHeight: 2)

// Top tab of folder
let tw: CGFloat = 8
let th: CGFloat = 3
let tx = (size - tw) / 2
let ty = by + bh - 1
path.addRoundedRect(in: CGRect(x: tx, y: ty, width: tw, height: th),
                     cornerWidth: 1, cornerHeight: 1)

// Downward arrow inside
let ax = size/2
let aTop = by + bh * 0.3
let aBot = by + bh * 0.7
path.move(to: CGPoint(x: ax, y: aTop))
path.addLine(to: CGPoint(x: ax, y: aBot))
path.move(to: CGPoint(x: ax - 2.5, y: aBot - 2.5))
path.addLine(to: CGPoint(x: ax, y: aBot))
path.addLine(to: CGPoint(x: ax + 2.5, y: aBot - 2.5))

ctx.addPath(path)
ctx.setLineWidth(1.8)
ctx.strokePath()

img.unlockFocus()

// Save as template PNG
let rep = NSBitmapImageRep(cgImage: img.cgImage(forProposedRect: nil, context: nil, hints: nil)!)
let data = rep.representation(using: .png, properties: [:])!
let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("MenuBarIcon.png")
try? data.write(to: url)
print("✅ MenuBarIcon.png generated")
