#!/usr/bin/swift
import AppKit

let outputPath = CommandLine.arguments.dropFirst().first ?? "Resources/Icons/AdminDocIconSource.png"
let outputURL = URL(fileURLWithPath: outputPath)

try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

let canvas = CGSize(width: 1024, height: 1024)
let image = NSImage(size: canvas)

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        calibratedRed: CGFloat((hex >> 16) & 0xff) / 255,
        green: CGFloat((hex >> 8) & 0xff) / 255,
        blue: CGFloat(hex & 0xff) / 255,
        alpha: alpha
    )
}

func roundedRect(_ rect: CGRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func fillRounded(_ rect: CGRect, radius: CGFloat, color fill: NSColor) {
    fill.setFill()
    roundedRect(rect, radius: radius).fill()
}

func strokeLine(from start: CGPoint, to end: CGPoint, width: CGFloat, color stroke: NSColor) {
    let path = NSBezierPath()
    path.move(to: start)
    path.line(to: end)
    path.lineWidth = width
    path.lineCapStyle = .round
    stroke.setStroke()
    path.stroke()
}

func drawCircle(center: CGPoint, radius: CGFloat, fill: NSColor, stroke: NSColor? = nil, lineWidth: CGFloat = 6) {
    let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    let path = NSBezierPath(ovalIn: rect)
    fill.setFill()
    path.fill()
    if let stroke {
        path.lineWidth = lineWidth
        stroke.setStroke()
        path.stroke()
    }
}

image.lockFocus()
NSGraphicsContext.current?.imageInterpolation = .high

let background = roundedRect(CGRect(x: 58, y: 58, width: 908, height: 908), radius: 210)
NSGradient(colors: [color(0x172554), color(0x0f766e), color(0x16a34a)])?
    .draw(in: background, angle: 34)

fillRounded(CGRect(x: 110, y: 112, width: 804, height: 804), radius: 176, color: color(0xffffff, alpha: 0.08))

NSGraphicsContext.saveGraphicsState()
let documentShadow = NSShadow()
documentShadow.shadowBlurRadius = 42
documentShadow.shadowOffset = NSSize(width: 0, height: -24)
documentShadow.shadowColor = color(0x020617, alpha: 0.28)
documentShadow.set()

let documentRect = CGRect(x: 205, y: 180, width: 430, height: 650)
fillRounded(documentRect, radius: 62, color: color(0xf8fafc))
NSGraphicsContext.restoreGraphicsState()

let fold = NSBezierPath()
fold.move(to: CGPoint(x: 545, y: 830))
fold.line(to: CGPoint(x: 635, y: 740))
fold.line(to: CGPoint(x: 548, y: 740))
fold.close()
color(0xdbeafe).setFill()
fold.fill()

for y in stride(from: 695, through: 460, by: -78) {
    fillRounded(CGRect(x: 285, y: y, width: 245, height: 22), radius: 11, color: color(0x94a3b8, alpha: 0.42))
    fillRounded(CGRect(x: 285, y: y - 36, width: 170, height: 20), radius: 10, color: color(0xcbd5e1, alpha: 0.74))
}

drawCircle(center: CGPoint(x: 305, y: 305), radius: 34, fill: color(0x22c55e), stroke: color(0xffffff, alpha: 0.86), lineWidth: 8)
drawCircle(center: CGPoint(x: 405, y: 305), radius: 34, fill: color(0xf59e0b), stroke: color(0xffffff, alpha: 0.86), lineWidth: 8)
drawCircle(center: CGPoint(x: 505, y: 305), radius: 34, fill: color(0xef4444), stroke: color(0xffffff, alpha: 0.86), lineWidth: 8)

NSGraphicsContext.saveGraphicsState()
let shieldShadow = NSShadow()
shieldShadow.shadowBlurRadius = 38
shieldShadow.shadowOffset = NSSize(width: 0, height: -18)
shieldShadow.shadowColor = color(0x020617, alpha: 0.30)
shieldShadow.set()

let shield = NSBezierPath()
shield.move(to: CGPoint(x: 704, y: 708))
shield.curve(to: CGPoint(x: 842, y: 655), controlPoint1: CGPoint(x: 754, y: 700), controlPoint2: CGPoint(x: 802, y: 682))
shield.curve(to: CGPoint(x: 778, y: 332), controlPoint1: CGPoint(x: 844, y: 515), controlPoint2: CGPoint(x: 825, y: 405))
shield.curve(to: CGPoint(x: 704, y: 270), controlPoint1: CGPoint(x: 750, y: 296), controlPoint2: CGPoint(x: 724, y: 278))
shield.curve(to: CGPoint(x: 630, y: 332), controlPoint1: CGPoint(x: 684, y: 278), controlPoint2: CGPoint(x: 658, y: 296))
shield.curve(to: CGPoint(x: 566, y: 655), controlPoint1: CGPoint(x: 583, y: 405), controlPoint2: CGPoint(x: 564, y: 515))
shield.curve(to: CGPoint(x: 704, y: 708), controlPoint1: CGPoint(x: 606, y: 682), controlPoint2: CGPoint(x: 654, y: 700))
shield.close()
NSGradient(colors: [color(0x38bdf8), color(0x2563eb), color(0x1d4ed8)])?
    .draw(in: shield, angle: -34)
NSGraphicsContext.restoreGraphicsState()

let check = NSBezierPath()
check.move(to: CGPoint(x: 624, y: 505))
check.line(to: CGPoint(x: 682, y: 442))
check.line(to: CGPoint(x: 794, y: 565))
check.lineWidth = 42
check.lineCapStyle = .round
check.lineJoinStyle = .round
color(0xffffff).setStroke()
check.stroke()

let nodeColor = color(0xe0f2fe, alpha: 0.96)
let nodeStroke = color(0x075985, alpha: 0.42)
let hub = CGPoint(x: 760, y: 218)
let nodeA = CGPoint(x: 650, y: 178)
let nodeB = CGPoint(x: 855, y: 230)
let nodeC = CGPoint(x: 780, y: 120)
strokeLine(from: hub, to: nodeA, width: 14, color: color(0xbfdbfe, alpha: 0.80))
strokeLine(from: hub, to: nodeB, width: 14, color: color(0xbfdbfe, alpha: 0.80))
strokeLine(from: hub, to: nodeC, width: 14, color: color(0xbfdbfe, alpha: 0.80))
drawCircle(center: hub, radius: 31, fill: nodeColor, stroke: nodeStroke)
drawCircle(center: nodeA, radius: 25, fill: nodeColor, stroke: nodeStroke)
drawCircle(center: nodeB, radius: 25, fill: nodeColor, stroke: nodeStroke)
drawCircle(center: nodeC, radius: 25, fill: nodeColor, stroke: nodeStroke)

image.unlockFocus()

guard
    let tiffData = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiffData),
    let pngData = bitmap.representation(using: .png, properties: [:])
else {
    FileHandle.standardError.write(Data("failed to render icon png\n".utf8))
    exit(1)
}

try pngData.write(to: outputURL)
print(outputURL.path)
