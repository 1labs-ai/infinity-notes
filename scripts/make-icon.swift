// Renders the app icon at 1024x1024 following the macOS icon grid (824pt body, 100pt margin).
// Usage: swift scripts/make-icon.swift <output.png>
import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let shape = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

// Body with drop shadow.
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
shadow.shadowBlurRadius = 28
shadow.shadowOffset = NSSize(width: 0, height: -10)
shadow.set()
NSColor(srgbRed: 1.0, green: 0.62, blue: 0.16, alpha: 1).setFill()
shape.fill()
NSGraphicsContext.restoreGraphicsState()

NSGraphicsContext.saveGraphicsState()
shape.addClip()
NSGradient(colors: [
    NSColor(srgbRed: 1.00, green: 0.80, blue: 0.30, alpha: 1),
    NSColor(srgbRed: 0.98, green: 0.52, blue: 0.12, alpha: 1),
])!.draw(in: body, angle: -90)

// Note card, slightly tilted.
ctx.saveGState()
ctx.translateBy(x: 512, y: 500)
ctx.rotate(by: -0.08)
let card = NSRect(x: -250, y: -300, width: 500, height: 600)
let cardPath = NSBezierPath(roundedRect: card, xRadius: 56, yRadius: 56)
NSGraphicsContext.saveGraphicsState()
let cardShadow = NSShadow()
cardShadow.shadowColor = NSColor(srgbRed: 0.55, green: 0.25, blue: 0.0, alpha: 0.35)
cardShadow.shadowBlurRadius = 30
cardShadow.shadowOffset = NSSize(width: 0, height: -14)
cardShadow.set()
NSColor(srgbRed: 1, green: 0.99, blue: 0.96, alpha: 1).setFill()
cardPath.fill()
NSGraphicsContext.restoreGraphicsState()

// Title bar and text lines.
NSColor(srgbRed: 0.24, green: 0.20, blue: 0.17, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: -175, y: 170, width: 260, height: 44), xRadius: 22, yRadius: 22).fill()
NSColor(srgbRed: 0.80, green: 0.76, blue: 0.70, alpha: 1).setFill()
for (i, width) in [350.0, 300, 340, 220].enumerated() {
    let y = 80 - CGFloat(i) * 80
    NSBezierPath(roundedRect: NSRect(x: -175, y: y, width: width, height: 28), xRadius: 14, yRadius: 14).fill()
}
ctx.restoreGState()

// Pen across the lower-right corner.
ctx.saveGState()
ctx.translateBy(x: 690, y: 330)
ctx.rotate(by: 0.75)
NSColor(srgbRed: 0.20, green: 0.24, blue: 0.40, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: -40, y: -20, width: 80, height: 330), xRadius: 40, yRadius: 40).fill()
NSColor(srgbRed: 0.86, green: 0.88, blue: 0.93, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: -40, y: 40, width: 80, height: 22)).fill()
let nib = NSBezierPath()
nib.move(to: NSPoint(x: -34, y: -10))
nib.line(to: NSPoint(x: 34, y: -10))
nib.line(to: NSPoint(x: 0, y: -100))
nib.close()
NSColor(srgbRed: 0.95, green: 0.85, blue: 0.60, alpha: 1).setFill()
nib.fill()
ctx.restoreGState()
NSGraphicsContext.restoreGraphicsState()

image.unlockFocus()
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
    samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = image.size
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
