import AppKit

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

guard let ctx = NSGraphicsContext.current?.cgContext else {
    exit(1)
}

// 1. Deep Obsidian Squircle Background
let rect = CGRect(x: 60, y: 60, width: 904, height: 904)
let path = CGPath(roundedRect: rect, cornerWidth: 200, cornerHeight: 200, transform: nil)

// Subtle drop shadow
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -20), blur: 50, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.5))
ctx.setFillColor(CGColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0))
ctx.addPath(path)
ctx.fillPath()
ctx.restoreGState()

// Inner Dark Gradient
ctx.saveGState()
ctx.addPath(path)
ctx.clip()

let colors = [
    CGColor(red: 0.14, green: 0.14, blue: 0.17, alpha: 1.0),
    CGColor(red: 0.06, green: 0.06, blue: 0.08, alpha: 1.0)
] as CFArray
let colorSpace = CGColorSpaceCreateDeviceRGB()
if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) {
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 964), end: CGPoint(x: 512, y: 60), options: [])
}

// Subtle border highlight
ctx.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.12))
ctx.setLineWidth(6)
ctx.addPath(path)
ctx.strokePath()
ctx.restoreGState()

// 2. Neon Volt Outer Stopwatch Ring
let center = CGPoint(x: 512, y: 490)
let radius: CGFloat = 260

// Track
ctx.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.08))
ctx.setLineWidth(42)
ctx.setLineCap(.round)
ctx.addArc(center: center, radius: radius, startAngle: 0, endAngle: CGFloat.pi * 2, clockwise: false)
ctx.strokePath()

// Progress Arc in Neon Volt
ctx.setStrokeColor(CGColor(red: 0.82, green: 1.0, blue: 0.20, alpha: 1.0))
ctx.setLineWidth(42)
ctx.setLineCap(.round)
ctx.addArc(center: center, radius: radius, startAngle: -CGFloat.pi / 2, endAngle: CGFloat.pi * 0.85, clockwise: false)
ctx.strokePath()

// 3. Top Button of Stopwatch
let buttonRect = CGRect(x: 472, y: 790, width: 80, height: 44)
let buttonPath = CGPath(roundedRect: buttonRect, cornerWidth: 16, cornerHeight: 16, transform: nil)
ctx.setFillColor(CGColor(red: 0.82, green: 1.0, blue: 0.20, alpha: 1.0))
ctx.addPath(buttonPath)
ctx.fillPath()

// Center clock hands
ctx.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.95))
ctx.setLineWidth(24)
ctx.setLineCap(.round)

// Hour hand
ctx.move(to: center)
ctx.addLine(to: CGPoint(x: 512, y: 630))
ctx.strokePath()

// Minute hand
ctx.setStrokeColor(CGColor(red: 0.82, green: 1.0, blue: 0.20, alpha: 1.0))
ctx.move(to: center)
ctx.addLine(to: CGPoint(x: 640, y: 420))
ctx.strokePath()

// Center Pin
ctx.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
ctx.addArc(center: center, radius: 24, startAngle: 0, endAngle: CGFloat.pi * 2, clockwise: false)
ctx.fillPath()

image.unlockFocus()

guard let tiffData = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiffData),
      let pngData = rep.representation(using: .png, properties: [:]) else {
    exit(1)
}

try! pngData.write(to: URL(fileURLWithPath: "icon_1024.png"))
print("Generated icon_1024.png")
