#!/usr/bin/env swift
// Regenerates Twilight/Assets.xcassets app-icon assets.
//
// macOS AppIcon.appiconset doesn't honor asset-catalog appearance variants for the
// `mac` idiom (that's an Icon Composer / .icon-bundle feature, Xcode 16+). So we
// use the light variant as the canonical AppIcon (what Finder, Spotlight, and
// Settings show), and ship the dark variant as a separate imageset so it can be
// referenced from code (e.g., NSImage(named: "AppIconDark")).
//
// Run from repo root:  swift scripts/generate_app_icons.swift

import AppKit
import CoreGraphics
import Foundation

let assetsDir = URL(fileURLWithPath: "Twilight/Assets.xcassets")
let appIconDir = assetsDir.appendingPathComponent("AppIcon.appiconset")
let darkImagesetDir = assetsDir.appendingPathComponent("AppIconDark.imageset")
for dir in [appIconDir, darkImagesetDir] {
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
}

let pixelSizes = [16, 32, 64, 128, 256, 512, 1024]

enum Variant { case light, dark }

func squirclePath(in rect: CGRect) -> CGPath {
    // macOS Big Sur app-icon corner radius ratio.
    let r = rect.width * 0.2237
    return CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil)
}

func drawIcon(size: Int, variant: Variant) -> Data {
    let s = CGFloat(size)
    let cs = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8,
        bytesPerRow: 0, space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!

    let rect = CGRect(x: 0, y: 0, width: s, height: s)
    ctx.addPath(squirclePath(in: rect))
    ctx.clip()

    // Background gradient (vertical).
    let topColor: CGColor
    let bottomColor: CGColor
    switch variant {
    case .light:
        topColor    = CGColor(red: 0.99, green: 0.78, blue: 0.55, alpha: 1) // warm peach
        bottomColor = CGColor(red: 0.97, green: 0.55, blue: 0.36, alpha: 1) // sunset orange
    case .dark:
        topColor    = CGColor(red: 0.06, green: 0.08, blue: 0.22, alpha: 1) // deep night
        bottomColor = CGColor(red: 0.16, green: 0.20, blue: 0.46, alpha: 1) // indigo
    }
    let gradient = CGGradient(
        colorsSpace: cs,
        colors: [topColor, bottomColor] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: s),
        end: CGPoint(x: 0, y: 0),
        options: []
    )

    // Celestial body.
    let center = CGPoint(x: s * 0.5, y: s * 0.55)
    let radius = s * 0.28

    switch variant {
    case .light:
        // Soft glow halo.
        let halo = CGGradient(
            colorsSpace: cs,
            colors: [
                CGColor(red: 1, green: 0.95, blue: 0.75, alpha: 0.7),
                CGColor(red: 1, green: 0.95, blue: 0.75, alpha: 0),
            ] as CFArray,
            locations: [0, 1]
        )!
        ctx.drawRadialGradient(
            halo,
            startCenter: center, startRadius: radius * 0.6,
            endCenter: center, endRadius: radius * 1.7,
            options: []
        )
        // Sun disc.
        ctx.setFillColor(CGColor(red: 1.0, green: 0.93, blue: 0.62, alpha: 1))
        ctx.fillEllipse(in: CGRect(
            x: center.x - radius, y: center.y - radius,
            width: radius * 2, height: radius * 2
        ))

    case .dark:
        // Stars (deterministic positions).
        let stars: [(CGFloat, CGFloat, CGFloat)] = [
            (0.18, 0.82, 0.012), (0.30, 0.70, 0.008),
            (0.78, 0.86, 0.014), (0.86, 0.72, 0.009),
            (0.14, 0.50, 0.010), (0.88, 0.42, 0.011),
            (0.22, 0.30, 0.008), (0.74, 0.22, 0.013),
        ]
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 0.95, alpha: 0.9))
        for (fx, fy, fr) in stars {
            let r = fr * s
            ctx.fillEllipse(in: CGRect(
                x: fx * s - r, y: fy * s - r, width: r * 2, height: r * 2
            ))
        }
        // Moon crescent: clip to "outside the carve disc", then fill the moon disc.
        let offset = radius * 0.45
        let moonRect = CGRect(
            x: center.x - radius, y: center.y - radius,
            width: radius * 2, height: radius * 2
        )
        let carveRect = CGRect(
            x: moonRect.minX + offset,
            y: moonRect.minY,
            width: radius * 2, height: radius * 2
        )
        ctx.saveGState()
        let clipPath = CGMutablePath()
        clipPath.addRect(rect)
        clipPath.addEllipse(in: carveRect)
        ctx.addPath(clipPath)
        ctx.clip(using: .evenOdd)
        ctx.setFillColor(CGColor(red: 0.96, green: 0.96, blue: 0.92, alpha: 1))
        ctx.fillEllipse(in: moonRect)
        ctx.restoreGState()
    }

    let cgImage = ctx.makeImage()!
    let bitmap = NSBitmapImageRep(cgImage: cgImage)
    return bitmap.representation(using: .png, properties: [:])!
}

// 1) AppIcon.appiconset: light variant at every Mac AppIcon size.
for px in pixelSizes {
    let url = appIconDir.appendingPathComponent("icon_\(px).png")
    try drawIcon(size: px, variant: .light).write(to: url)
    print("wrote AppIcon.appiconset/\(url.lastPathComponent)")
}

struct Slot { let size: Int; let scale: Int }
let slots: [Slot] = [
    Slot(size: 16, scale: 1), Slot(size: 16, scale: 2),
    Slot(size: 32, scale: 1), Slot(size: 32, scale: 2),
    Slot(size: 128, scale: 1), Slot(size: 128, scale: 2),
    Slot(size: 256, scale: 1), Slot(size: 256, scale: 2),
    Slot(size: 512, scale: 1), Slot(size: 512, scale: 2),
]

let appIconImages: [[String: Any]] = slots.map { slot in
    [
        "idiom": "mac",
        "size": "\(slot.size)x\(slot.size)",
        "scale": "\(slot.scale)x",
        "filename": "icon_\(slot.size * slot.scale).png",
    ]
}
let appIconContents: [String: Any] = [
    "images": appIconImages,
    "info": ["version": 1, "author": "xcode"],
]
try JSONSerialization
    .data(withJSONObject: appIconContents, options: [.prettyPrinted, .sortedKeys])
    .write(to: appIconDir.appendingPathComponent("Contents.json"))
print("wrote AppIcon.appiconset/Contents.json")

// 2) AppIconDark.imageset: dark variant at 1x/2x (512 + 1024).
for (scale, px) in [(1, 512), (2, 1024)] {
    let url = darkImagesetDir.appendingPathComponent("icon_dark@\(scale)x.png")
    try drawIcon(size: px, variant: .dark).write(to: url)
    print("wrote AppIconDark.imageset/\(url.lastPathComponent)")
}
let darkImagesetContents: [String: Any] = [
    "images": [
        ["idiom": "mac", "scale": "1x", "filename": "icon_dark@1x.png"],
        ["idiom": "mac", "scale": "2x", "filename": "icon_dark@2x.png"],
    ],
    "info": ["version": 1, "author": "xcode"],
]
try JSONSerialization
    .data(withJSONObject: darkImagesetContents, options: [.prettyPrinted, .sortedKeys])
    .write(to: darkImagesetDir.appendingPathComponent("Contents.json"))
print("wrote AppIconDark.imageset/Contents.json")
