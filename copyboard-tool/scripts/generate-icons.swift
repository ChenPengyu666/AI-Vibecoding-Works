#!/usr/bin/env swift

import AppKit
import Foundation

/// 生成 ClipboardHistory 应用图标
/// 首先生成 1024x1024 主图，再用 sips 缩放为所有尺寸

let outputDir = "ClipboardHistory/Resources/Assets.xcassets/AppIcon.appiconset"

let outputURL = URL(fileURLWithPath: outputDir)
try? FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

// ---------- 1. 生成 1024x1024 主图 ----------
func drawIcon() -> NSImage {
    let pixels = 1024
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let size = CGFloat(pixels)
    let cornerRadius = size * 0.225
    let bgPath = NSBezierPath(
        roundedRect: NSRect(x: 0, y: 0, width: size, height: size),
        xRadius: cornerRadius,
        yRadius: cornerRadius
    )

    // 渐变背景
    var locations: [CGFloat] = [0.0, 0.5, 0.8]
    let gradient = NSGradient(colors: [
        NSColor(red: 0.255, green: 0.608, blue: 0.839, alpha: 1.0),
        NSColor(red: 0.380, green: 0.710, blue: 0.910, alpha: 1.0),
        NSColor(red: 0.494, green: 0.784, blue: 0.890, alpha: 1.0),
    ], atLocations: &locations, colorSpace: .sRGB)!
    gradient.draw(in: bgPath, angle: 135)

    // 白色剪贴板
    let margin = size * 0.2
    let w = size - margin * 2
    let h = size - margin * 2
    let boardInsetX = w * 0.15
    let boardInsetY = h * 0.1
    let boardRect = NSRect(
        x: margin + boardInsetX,
        y: margin + boardInsetY,
        width: w - boardInsetX * 2,
        height: h - boardInsetY * 2 - h * 0.08
    )
    NSColor.white.setFill()
    NSBezierPath(roundedRect: boardRect, xRadius: w * 0.06, yRadius: w * 0.06).fill()

    // 顶部夹子
    let clipTop = margin + h - boardInsetY * 2 - h * 0.02
    let clipHeight = h * 0.13
    let clipInset = w * 0.22
    let clipRect = NSRect(
        x: margin + clipInset,
        y: clipTop,
        width: w - clipInset * 2,
        height: clipHeight
    )
    NSColor(white: 0.92, alpha: 1.0).setFill()
    NSBezierPath(roundedRect: clipRect, xRadius: w * 0.03, yRadius: w * 0.03).fill()

    // 夹子横线
    let lineY = clipRect.midY
    let lp = NSBezierPath()
    lp.move(to: NSPoint(x: clipRect.minX + clipRect.width * 0.15, y: lineY))
    lp.line(to: NSPoint(x: clipRect.maxX - clipRect.width * 0.15, y: lineY))
    lp.lineWidth = w * 0.02
    NSColor(white: 0.75, alpha: 1.0).setStroke()
    lp.stroke()

    // 板身横线
    let boardLeft = boardRect.minX + boardRect.width * 0.18
    let boardRight = boardRect.maxX - boardRect.width * 0.18
    let lineSpacing = boardRect.height * 0.08
    let startY = boardRect.minY + boardRect.height * 0.72
    for i in 0..<4 {
        let y = startY - CGFloat(i) * lineSpacing * 2
        let lp = NSBezierPath()
        lp.move(to: NSPoint(x: boardLeft, y: y))
        lp.line(to: NSPoint(x: boardRight, y: y))
        lp.lineWidth = w * 0.025
        lp.lineCapStyle = .round
        NSColor(red: 0.380, green: 0.710, blue: 0.910, alpha: 0.4).setStroke()
        lp.stroke()
    }

    NSGraphicsContext.restoreGraphicsState()

    let image = NSImage(size: NSSize(width: size, height: size))
    image.addRepresentation(rep)
    return image
}

print("🎨 生成 1024x1024 主图...")
let masterIcon = drawIcon()
let masterPath = outputURL.appendingPathComponent("icon_master.png")
guard let tiffData = masterIcon.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let pngData = bitmap.representation(using: .png, properties: [:]) else {
    print("❌ 主图生成失败")
    exit(1)
}
try! pngData.write(to: masterPath)
print("✅ 主图: 1024x1024")

// ---------- 2. 使用 sips 缩放 ----------
let sizes: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

for (size, name) in sizes {
    let outPath = outputURL.appendingPathComponent(name).path
    let task = Process()
    task.launchPath = "/usr/bin/sips"
    task.arguments = ["-z", "\(size)", "\(size)", masterPath.path, "--out", outPath]
    task.launch()
    task.waitUntilExit()
    print("✅ \(name) (\(size)x\(size))")
}

// 删除临时主图
try? FileManager.default.removeItem(at: masterPath)

print("\n🎉 图标生成完成！共 \(sizes.count) 个文件")
print("📁 输出目录: \(outputURL.path)")
