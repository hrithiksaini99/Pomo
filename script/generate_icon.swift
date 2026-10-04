#!/usr/bin/env swift
import AppKit
import Foundation

// Rebuild the app icon, web marks, and social card without external dependencies.
// Usage: swift script/generate_icon.swift [output-directory]
let outputURL = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1] : "general/pomodoro/Resources", isDirectory: true)
let fileManager = FileManager.default
try fileManager.createDirectory(at: outputURL, withIntermediateDirectories: true)

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: alpha)
}

let orange = color(0xED603A)
let ivory = color(0xFFF6E9)
let ink = color(0x272C26)

func rounded(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func squircle(_ rect: NSRect) -> NSBezierPath {
    let path = NSBezierPath()
    let exponent = 2.0 / 4.6
    for i in 0...240 {
        let angle = Double(i) / 240 * Double.pi * 2
        let cx = cos(angle)
        let sy = sin(angle)
        let x = rect.midX + rect.width / 2 * CGFloat(pow(abs(cx), exponent) * (cx < 0 ? -1 : 1))
        let y = rect.midY + rect.height / 2 * CGFloat(pow(abs(sy), exponent) * (sy < 0 ? -1 : 1))
        if i == 0 { path.move(to: NSPoint(x: x, y: y)) }
        else { path.line(to: NSPoint(x: x, y: y)) }
    }
    path.close()
    return path
}

func drawTimer() {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color(0x8F2C13, alpha: 0.20)
    shadow.shadowOffset = NSSize(width: 0, height: -8)
    shadow.shadowBlurRadius = 16
    shadow.set()
    ivory.setFill()
    rounded(NSRect(x: 437, y: 767, width: 150, height: 49), radius: 24.5).fill()
    rounded(NSRect(x: 489, y: 714, width: 46, height: 83), radius: 17).fill()
    NSBezierPath(ovalIn: NSRect(x: 267, y: 245, width: 490, height: 490)).fill()
    NSGraphicsContext.restoreGraphicsState()

    let dial = NSBezierPath(ovalIn: NSRect(x: 267, y: 245, width: 490, height: 490))
    NSGradient(starting: color(0xFFFCF6), ending: color(0xFCEFD9))!.draw(in: dial, angle: -90)
    color(0xFFFDFC, alpha: 0.74).setStroke()
    dial.lineWidth = 2
    dial.stroke()

    // Two connected hands read as a timer even at menu and favicon sizes.
    let hands = NSBezierPath()
    hands.move(to: NSPoint(x: 512, y: 635))
    hands.line(to: NSPoint(x: 512, y: 492))
    hands.line(to: NSPoint(x: 630, y: 422))
    hands.lineWidth = 49
    hands.lineCapStyle = .round
    hands.lineJoinStyle = .round
    color(0xE75B35).setStroke()
    hands.stroke()
}

func drawIcon() {
    let tile = squircle(NSRect(x: 62, y: 62, width: 900, height: 900))
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color(0x5C2D1D, alpha: 0.16)
    shadow.shadowOffset = NSSize(width: 0, height: -13)
    shadow.shadowBlurRadius = 24
    shadow.set()
    orange.setFill()
    tile.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGradient(starting: color(0xF97648), ending: color(0xE8532E))!.draw(in: tile, angle: -90)
    NSGraphicsContext.saveGraphicsState()
    tile.addClip()
    let glow = NSBezierPath(ovalIn: NSRect(x: 4, y: 420, width: 1030, height: 680))
    NSGradient(starting: color(0xFFBA8A, alpha: 0.18), ending: color(0xFFBA8A, alpha: 0))!
        .draw(in: glow, relativeCenterPosition: NSPoint(x: 0, y: 0.35))
    NSGraphicsContext.restoreGraphicsState()
    color(0xFFFFFF, alpha: 0.26).setStroke()
    tile.lineWidth = 2
    tile.stroke()
    drawTimer()
}

func renderPNG(width: Int, height: Int, scale: CGFloat = 1,
               filename: String, draw: () -> Void) throws {
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width,
        pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
        let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        fatalError("Cannot create image context")
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.clear(CGRect(x: 0, y: 0, width: width, height: height))
    context.cgContext.setAllowsAntialiasing(true)
    context.cgContext.setShouldAntialias(true)
    context.cgContext.scaleBy(x: scale, y: scale)
    draw()
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Cannot encode PNG")
    }
    try data.write(to: outputURL.appendingPathComponent(filename), options: .atomic)
}

for size in [180, 192, 512, 1024] {
    try renderPNG(width: size, height: size, scale: CGFloat(size) / 1024,
                  filename: "icon-\(size).png", draw: drawIcon)
}

let iconsetURL = outputURL.appendingPathComponent("AppIcon.iconset", isDirectory: true)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for multiplier in [1, 2] {
        let pixels = size * multiplier
        let suffix = multiplier == 2 ? "@2x" : ""
        let name = "icon_\(size)x\(size)\(suffix).png"
        try renderPNG(width: pixels, height: pixels, scale: CGFloat(pixels) / 1024,
                      filename: "AppIcon.iconset/\(name)", draw: drawIcon)
    }
}
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.appendingPathComponent("AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
if iconutil.terminationStatus != 0 {
    // If iconutil cannot assemble the file, preserve the native PNG payloads
    // directly in modern ICNS size and Retina variant entries.
    func bigEndian(_ value: Int) -> Data {
        var number = UInt32(value).bigEndian
        return withUnsafeBytes(of: &number) { Data($0) }
    }
    let entries: [(String, String)] = [
        ("icp4", "icon_16x16.png"), ("icp5", "icon_32x32.png"),
        ("icp6", "icon_32x32@2x.png"), ("ic07", "icon_128x128.png"),
        ("ic08", "icon_256x256.png"), ("ic09", "icon_512x512.png"),
        ("ic10", "icon_512x512@2x.png"), ("ic11", "icon_16x16@2x.png"),
        ("ic12", "icon_32x32@2x.png"), ("ic13", "icon_128x128@2x.png"),
        ("ic14", "icon_256x256@2x.png")
    ]
    var payload = Data()
    for (type, filename) in entries {
        let png = try Data(contentsOf: iconsetURL.appendingPathComponent(filename))
        payload.append(Data(type.utf8))
        payload.append(bigEndian(png.count + 8))
        payload.append(png)
    }
    var icns = Data("icns".utf8)
    icns.append(bigEndian(payload.count + 8))
    icns.append(payload)
    try icns.write(to: outputURL.appendingPathComponent("AppIcon.icns"), options: .atomic)
}
try fileManager.removeItem(at: iconsetURL)

let iconSVG = """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" role="img" aria-label="Pomo timer">
  <defs>
    <linearGradient id="tile" x2="0" y2="1"><stop stop-color="#f97648"/><stop offset="1" stop-color="#e8532e"/></linearGradient>
    <linearGradient id="face" x2="0" y2="1"><stop stop-color="#fffcf6"/><stop offset="1" stop-color="#fcefd9"/></linearGradient>
  </defs>
  <rect x="62" y="62" width="900" height="900" rx="214" fill="url(#tile)"/>
  <rect x="437" y="208" width="150" height="49" rx="24.5" fill="#fff6e9"/>
  <rect x="489" y="227" width="46" height="83" rx="17" fill="#fff6e9"/>
  <circle cx="512" cy="534" r="245" fill="url(#face)"/>
  <path d="M512 389v143l118 70" fill="none" stroke="#e75b35" stroke-width="49" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
"""

let markSVG = """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" role="img" aria-label="Pomo">
  <rect x="1" y="1" width="62" height="62" rx="16" fill="#ed603a"/>
  <rect x="27.3" y="12.3" width="9.4" height="3.1" rx="1.55" fill="#fff6e9"/>
  <rect x="30.56" y="14" width="2.88" height="5.2" rx="1.1" fill="#fff6e9"/>
  <circle cx="32" cy="33.4" r="15.3" fill="#fff6e9"/>
  <path d="M32 24.3v9.1l7.4 4.4" fill="none" stroke="#ed603a" stroke-width="3.1" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
"""

for (name, contents) in [("icon.svg", iconSVG), ("logo-mark.svg", markSVG), ("favicon.svg", markSVG)] {
    try contents.write(to: outputURL.appendingPathComponent(name), atomically: true, encoding: .utf8)
}

func text(_ string: String, rect: NSRect, font: NSFont, color: NSColor,
          spacing: CGFloat = 0, lineHeight: CGFloat = 0) {
    let paragraph = NSMutableParagraphStyle()
    if lineHeight > 0 {
        paragraph.minimumLineHeight = lineHeight
        paragraph.maximumLineHeight = lineHeight
    }
    NSAttributedString(string: string, attributes: [
        .font: font, .foregroundColor: color, .kern: spacing, .paragraphStyle: paragraph
    ]).draw(in: rect)
}

try renderPNG(width: 1200, height: 630, filename: "social-card.png") {
    color(0xF5F3ED).setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1200, height: 630)).fill()
    color(0xE3E1D8).setStroke()
    let separator = NSBezierPath()
    separator.move(to: NSPoint(x: 76, y: 102))
    separator.line(to: NSPoint(x: 1124, y: 102))
    separator.lineWidth = 1
    separator.stroke()
    text("Pomo", rect: NSRect(x: 76, y: 491, width: 420, height: 48),
         font: .systemFont(ofSize: 33, weight: .semibold), color: ink, spacing: -1)
    text("Make room\nfor deep work.", rect: NSRect(x: 72, y: 231, width: 720, height: 224),
         font: NSFont(name: "Georgia", size: 76) ?? .systemFont(ofSize: 76, weight: .medium),
         color: ink, spacing: -2.7, lineHeight: 88)
    text("A quiet focus timer for your Mac.", rect: NSRect(x: 76, y: 183, width: 670, height: 36),
         font: .systemFont(ofSize: 24), color: color(0x65695D))
    text("FOCUS. BREAK. REPEAT.", rect: NSRect(x: 76, y: 49, width: 580, height: 28),
         font: .monospacedSystemFont(ofSize: 14, weight: .medium), color: color(0x65695D), spacing: 1.6)
    text("MADE FOR macOS", rect: NSRect(x: 942, y: 49, width: 240, height: 28),
         font: .monospacedSystemFont(ofSize: 14, weight: .medium), color: color(0x65695D), spacing: 1)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current!.cgContext.translateBy(x: 802, y: 229)
    NSGraphicsContext.current!.cgContext.scaleBy(x: 310.0 / 1024, y: 310.0 / 1024)
    drawIcon()
    NSGraphicsContext.restoreGraphicsState()
}

print("Generated AppIcon.icns, four PNG sizes, SVG marks, and social-card.png in \(outputURL.path)")
