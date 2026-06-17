#!/usr/bin/env swift
import AppKit
import Foundation

struct IconRenderer {
    let size: CGFloat
    let menuBar: Bool

    func render() -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        defer { image.unlockFocus() }

        guard let context = NSGraphicsContext.current?.cgContext else {
            return image
        }

        context.clear(CGRect(x: 0, y: 0, width: size, height: size))

        if menuBar {
            drawMenuBarSliders(context: context)
        } else {
            let corner = size * 0.2237
            let bounds = CGRect(x: 0, y: 0, width: size, height: size)
            let path = CGPath(
                roundedRect: bounds,
                cornerWidth: corner,
                cornerHeight: corner,
                transform: nil
            )
            context.setFillColor(NSColor.white.cgColor)
            context.addPath(path)
            context.fillPath()

            context.setStrokeColor(NSColor.black.withAlphaComponent(0.08).cgColor)
            context.setLineWidth(max(1, size / 512))
            context.addPath(path)
            context.strokePath()

            drawSliders(context: context, inset: size * 0.18)
        }

        return image
    }

    private func drawMenuBarSliders(context: CGContext) {
        let inset = size * 0.14
        let trackWidth = size - inset * 2
        let trackHeight = max(2.5, size * 0.14)
        let knobRadius = size * 0.16
        let startX = inset
        let knobPositions: [CGFloat] = [0.2, 0.55, 0.82]
        let rowCenters: [CGFloat] = [size * 0.74, size * 0.50, size * 0.26]

        for (index, centerY) in rowCenters.enumerated() {
            let trackRect = CGRect(
                x: startX,
                y: centerY - trackHeight / 2,
                width: trackWidth,
                height: trackHeight
            )
            context.setFillColor(NSColor.black.withAlphaComponent(0.35).cgColor)
            context.fill(trackRect)

            let knobX = startX + trackWidth * knobPositions[index]
            let knobRect = CGRect(
                x: knobX - knobRadius,
                y: centerY - knobRadius,
                width: knobRadius * 2,
                height: knobRadius * 2
            )
            context.setFillColor(NSColor.black.cgColor)
            context.fillEllipse(in: knobRect)
        }
    }

    private func drawSliders(context: CGContext, inset: CGFloat) {
        let trackWidth = size - inset * 2
        let trackHeight = max(2, size * 0.042)
        let knobRadius = size * 0.058
        let startX = inset
        let knobPositions: [CGFloat] = [0.22, 0.58, 0.84]
        let rowCenters: [CGFloat] = [size * 0.68, size * 0.50, size * 0.32]

        for (index, centerY) in rowCenters.enumerated() {
            let trackRect = CGRect(
                x: startX,
                y: centerY - trackHeight / 2,
                width: trackWidth,
                height: trackHeight
            )
            context.setFillColor(NSColor.black.withAlphaComponent(0.12).cgColor)
            context.fill(trackRect)

            let knobX = startX + trackWidth * knobPositions[index]
            let knobRect = CGRect(
                x: knobX - knobRadius,
                y: centerY - knobRadius,
                width: knobRadius * 2,
                height: knobRadius * 2
            )
            context.setFillColor(NSColor.black.cgColor)
            context.fillEllipse(in: knobRect)

            context.setStrokeColor(NSColor.black.withAlphaComponent(0.85).cgColor)
            context.setLineWidth(max(1, size / 340))
            context.strokeEllipse(in: knobRect.insetBy(dx: 0.5, dy: 0.5))
        }
    }
}

enum IconExporter {
    static func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff)
        else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    static func writePNG(_ image: NSImage, to url: URL, pixelSize: Int? = nil) throws {
        if let pixelSize {
            guard let data = pngData(from: image, pixelSize: pixelSize) else {
                throw NSError(domain: "RenderIcons", code: 1)
            }
            try data.write(to: url)
            return
        }
        guard let data = pngData(from: image) else {
            throw NSError(domain: "RenderIcons", code: 1)
        }
        try data.write(to: url)
    }

    static func pngData(from image: NSImage, pixelSize: Int) -> Data? {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelSize,
            pixelsHigh: pixelSize,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }

        rep.size = NSSize(width: pixelSize, height: pixelSize)
        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        NSGraphicsContext.current = context
        NSColor.clear.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize)).fill()
        image.draw(
            in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize),
            from: .zero,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])
    }

    static func resize(_ image: NSImage, to side: Int) -> NSImage {
        let target = NSSize(width: side, height: side)
        let resized = NSImage(size: target)
        resized.lockFocus()
        NSColor.clear.set()
        NSBezierPath(rect: NSRect(origin: .zero, size: target)).fill()
        image.draw(
            in: NSRect(origin: .zero, size: target),
            from: .zero,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: [
                .interpolation: NSImageInterpolation.high,
            ]
        )
        resized.unlockFocus()
        return resized
    }
}

let root = URL(fileURLWithPath: CommandLine.arguments[0])
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let assets = root.appendingPathComponent("Assets", isDirectory: true)
let source = assets.appendingPathComponent("AppIcon.source", isDirectory: true)
let iconset = assets.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let resources = root.appendingPathComponent("Sources/LoadoutApp/Resources", isDirectory: true)

try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)

let master = IconRenderer(size: 1024, menuBar: false).render()
try IconExporter.writePNG(master, to: source.appendingPathComponent("icon-1024.png"))

let entries: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (name, side) in entries {
    let image = side == 1024 ? master : IconExporter.resize(master, to: side)
    try IconExporter.writePNG(image, to: iconset.appendingPathComponent(name))
}

let menuBar18 = IconRenderer(size: 18, menuBar: true).render()
let menuBar36 = IconRenderer(size: 36, menuBar: true).render()
try IconExporter.writePNG(menuBar18, to: resources.appendingPathComponent("MenuBarIcon.png"), pixelSize: 18)
try IconExporter.writePNG(menuBar36, to: resources.appendingPathComponent("MenuBarIcon@2x.png"), pixelSize: 36)

print("wrote \(source.path)")
print("wrote \(iconset.path)")
print("wrote menu bar icons → \(resources.path)")