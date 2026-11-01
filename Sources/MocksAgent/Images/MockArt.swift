//  WHAT: The pictures the fixtures show, drawn here with CoreGraphics: six faces, six dishes, six places, each a soft
//        gradient with a white mark, as PNG. They go into the package as base64 and reach the app as `data:` URLs, so
//        a screen on the mock shows pictures with no server and nothing fetched from anyone's.
//  PIN:  ROWS, NOT A GRADIENT. Each row is filled with one colour: CoreGraphics' gradients dither, and a dithered
//        picture is ten times the size of this one (4–10 KB at 360×240), in a package that carries eighteen.
//  PIN:  NO SYMBOLS, NO TEXT. Marks are drawn paths; nothing from SF Symbols or a font is drawn into a picture.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum MockArt {
    /// Every picture's name: `person-1` … `person-6`, `food-1` … `food-6`, `place-1` … `place-6`.
    static let names: [String] = ["food", "person", "place"].flatMap { kind in (1...6).map { "\(kind)-\($0)" } }

    /// Every picture, drawn: its name and its PNG as base64.
    static func drawAll() -> [(name: String, base64: String)] {
        names.compactMap { name in png(name).map { (name, $0.base64EncodedString()) } }
    }

    /// The picture `name` as PNG.
    static func png(_ name: String) -> Data? {
        let parts = name.split(separator: "-")
        guard parts.count == 2, let number = Int(parts[1]), (1...6).contains(number) else { return nil }
        let kind = String(parts[0])
        let size = kind == "person" ? (128, 128) : (360, 240)
        guard let context = CGContext(data: nil, width: size.0, height: size.1, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        let width = CGFloat(size.0), height = CGFloat(size.1)
        let palette = palettes[kind]![number - 1]
        // The ground: one colour a row, from the bottom colour to the top.
        for row in 0..<size.1 {
            let t = CGFloat(row) / CGFloat(max(1, size.1 - 1))
            let colour = zip(palette.bottom, palette.top).map { $0 + ($1 - $0) * t }
            context.setFillColor(red: colour[0], green: colour[1], blue: colour[2], alpha: 1)
            context.fill(CGRect(x: 0, y: CGFloat(row), width: width, height: 1))
        }
        context.setShouldAntialias(true)
        // Dishes and places are drawn on a 240×160 plan, scaled to the picture.
        let plan = CGSize(width: 240, height: 160)
        if kind != "person" { context.scaleBy(x: width / plan.width, y: height / plan.height) }
        switch kind {
        case "person": face(context, width, height)
        case "food": dish(number, context, plan.width, plan.height)
        default: view(number, context, plan.width, plan.height)
        }
        guard let image = context.makeImage() else { return nil }
        let out = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return out as Data
    }

    /// Bottom and top colours, as sRGB components.
    private struct Palette {
        var bottom: [CGFloat]
        var top: [CGFloat]
    }

    private static func rgb(_ hex: UInt32) -> [CGFloat] {
        [CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255, CGFloat(hex & 0xFF) / 255]
    }

    private static let palettes: [String: [Palette]] = [
        "person": [Palette(bottom: rgb(0x6C8EBF), top: rgb(0xB7CCE8)), Palette(bottom: rgb(0xC0796B), top: rgb(0xEFC3B1)),
                   Palette(bottom: rgb(0x6E9F7F), top: rgb(0xBFDCC5)), Palette(bottom: rgb(0x9A7BB5), top: rgb(0xD8C6E8)),
                   Palette(bottom: rgb(0xC69A4A), top: rgb(0xF0D9A2)), Palette(bottom: rgb(0x5E8C94), top: rgb(0xB3D3D6))],
        "food": [Palette(bottom: rgb(0xD9774F), top: rgb(0xF6C9A4)), Palette(bottom: rgb(0xD9A23E), top: rgb(0xF7E2A8)),
                 Palette(bottom: rgb(0xC9636F), top: rgb(0xF2C2C4)), Palette(bottom: rgb(0x8C9A55), top: rgb(0xD8DFB0)),
                 Palette(bottom: rgb(0xE08A5C), top: rgb(0xF9D5B6)), Palette(bottom: rgb(0xA97B52), top: rgb(0xE9D2B5))],
        "place": [Palette(bottom: rgb(0x4F8FA6), top: rgb(0xBFE0EA)), Palette(bottom: rgb(0x6A6FB3), top: rgb(0xCBCDEE)),
                  Palette(bottom: rgb(0x4D9C8A), top: rgb(0xBDE5DA)), Palette(bottom: rgb(0xB0739B), top: rgb(0xF0C9D9)),
                  Palette(bottom: rgb(0xC1924F), top: rgb(0xF2DDB3)), Palette(bottom: rgb(0x3F5E8C), top: rgb(0xA9BEDD))],
    ]

    private static func white(_ context: CGContext, _ alpha: CGFloat) {
        context.setFillColor(CGColor(gray: 1, alpha: alpha))
        context.setStrokeColor(CGColor(gray: 1, alpha: alpha))
    }

    // MARK: - People

    /// A head and shoulders.
    private static func face(_ context: CGContext, _ width: CGFloat, _ height: CGFloat) {
        white(context, 0.78)
        let head = width * 0.19
        context.fillEllipse(in: CGRect(x: width / 2 - head, y: height * 0.5, width: head * 2, height: head * 2))
        context.fillEllipse(in: CGRect(x: width * 0.16, y: -height * 0.36, width: width * 0.68, height: height * 0.78))
    }

    // MARK: - Food

    private static func dish(_ number: Int, _ context: CGContext, _ width: CGFloat, _ height: CGFloat) {
        let cx = width / 2, cy = height / 2
        switch number {
        case 1:
            // A bowl, and its steam.
            white(context, 0.8)
            context.addArc(center: CGPoint(x: cx, y: cy + 4), radius: 50, startAngle: .pi, endAngle: 2 * .pi, clockwise: false)
            context.fillPath()
            context.fill(CGRect(x: cx - 58, y: cy + 2, width: 116, height: 6))
            white(context, 0.55)
            context.setLineWidth(4)
            context.setLineCap(.round)
            for offset in [-18.0, 0.0, 18.0] {
                let x = cx + CGFloat(offset)
                context.move(to: CGPoint(x: x, y: cy + 18))
                context.addCurve(to: CGPoint(x: x, y: cy + 54), control1: CGPoint(x: x - 10, y: cy + 30), control2: CGPoint(x: x + 10, y: cy + 42))
                context.strokePath()
            }
        case 2:
            // A plate and a sprig.
            white(context, 0.75)
            context.fillEllipse(in: CGRect(x: cx - 56, y: cy - 56, width: 112, height: 112))
            white(context, 0.45)
            context.fillEllipse(in: CGRect(x: cx - 36, y: cy - 36, width: 72, height: 72))
            white(context, 0.85)
            context.move(to: CGPoint(x: cx - 14, y: cy - 12))
            context.addQuadCurve(to: CGPoint(x: cx + 18, y: cy + 16), control: CGPoint(x: cx - 18, y: cy + 18))
            context.addQuadCurve(to: CGPoint(x: cx - 14, y: cy - 12), control: CGPoint(x: cx + 16, y: cy - 14))
            context.fillPath()
        case 3:
            // A loaf, scored.
            white(context, 0.8)
            let loaf = CGRect(x: cx - 66, y: cy - 30, width: 132, height: 64)
            context.addPath(CGPath(roundedRect: loaf, cornerWidth: 32, cornerHeight: 30, transform: nil))
            context.fillPath()
            context.setStrokeColor(CGColor(gray: 0, alpha: 0.12))
            context.setLineWidth(5)
            context.setLineCap(.round)
            for offset in [-34.0, 0.0, 34.0] {
                context.move(to: CGPoint(x: cx + CGFloat(offset) - 12, y: cy - 8))
                context.addLine(to: CGPoint(x: cx + CGFloat(offset) + 12, y: cy + 18))
                context.strokePath()
            }
        case 4:
            // A cup, its handle and steam.
            white(context, 0.8)
            context.addPath(CGPath(roundedRect: CGRect(x: cx - 34, y: cy - 40, width: 60, height: 66), cornerWidth: 12, cornerHeight: 12, transform: nil))
            context.fillPath()
            context.setLineWidth(9)
            context.strokeEllipse(in: CGRect(x: cx + 14, y: cy - 22, width: 30, height: 30))
            white(context, 0.55)
            context.setLineWidth(4)
            context.setLineCap(.round)
            for offset in [-14.0, 4.0] {
                let x = cx + CGFloat(offset)
                context.move(to: CGPoint(x: x, y: cy + 34))
                context.addCurve(to: CGPoint(x: x, y: cy + 66), control1: CGPoint(x: x - 9, y: cy + 44), control2: CGPoint(x: x + 9, y: cy + 56))
                context.strokePath()
            }
        case 5:
            // A slice of citrus.
            white(context, 0.8)
            context.fillEllipse(in: CGRect(x: cx - 50, y: cy - 50, width: 100, height: 100))
            context.setStrokeColor(CGColor(gray: 0, alpha: 0.1))
            context.setLineWidth(3)
            for segment in 0..<8 {
                let angle = CGFloat(segment) * .pi / 4
                context.move(to: CGPoint(x: cx, y: cy))
                context.addLine(to: CGPoint(x: cx + cos(angle) * 44, y: cy + sin(angle) * 44))
                context.strokePath()
            }
            context.strokeEllipse(in: CGRect(x: cx - 44, y: cy - 44, width: 88, height: 88))
        default:
            // A tart and its lattice.
            white(context, 0.78)
            context.fillEllipse(in: CGRect(x: cx - 54, y: cy - 54, width: 108, height: 108))
            // The lattice inside the rim.
            context.saveGState()
            context.addEllipse(in: CGRect(x: cx - 42, y: cy - 42, width: 84, height: 84))
            context.clip()
            context.setStrokeColor(CGColor(gray: 0, alpha: 0.1))
            context.setLineWidth(6)
            for offset in stride(from: -36.0, through: 36.0, by: 18.0) {
                let o = CGFloat(offset)
                context.move(to: CGPoint(x: cx + o, y: cy - 50)); context.addLine(to: CGPoint(x: cx + o, y: cy + 50))
                context.move(to: CGPoint(x: cx - 50, y: cy + o)); context.addLine(to: CGPoint(x: cx + 50, y: cy + o))
            }
            context.strokePath()
            context.restoreGState()
        }
    }

    // MARK: - Places

    private static func view(_ number: Int, _ context: CGContext, _ width: CGFloat, _ height: CGFloat) {
        switch number {
        case 1:
            // Mountains under a sun.
            white(context, 0.7)
            context.fillEllipse(in: CGRect(x: width * 0.66, y: height * 0.62, width: 34, height: 34))
            white(context, 0.5)
            context.move(to: CGPoint(x: -10, y: 0)); context.addLine(to: CGPoint(x: width * 0.32, y: height * 0.66)); context.addLine(to: CGPoint(x: width * 0.66, y: 0))
            context.fillPath()
            white(context, 0.75)
            context.move(to: CGPoint(x: width * 0.3, y: 0)); context.addLine(to: CGPoint(x: width * 0.62, y: height * 0.5)); context.addLine(to: CGPoint(x: width + 10, y: 0))
            context.fillPath()
        case 2:
            // Rolling hills.
            for (index, level) in [0.55, 0.38, 0.2].enumerated() {
                white(context, 0.35 + 0.2 * CGFloat(index))
                context.move(to: CGPoint(x: 0, y: 0))
                context.addLine(to: CGPoint(x: 0, y: height * CGFloat(level)))
                context.addCurve(to: CGPoint(x: width, y: height * CGFloat(level) * 0.8),
                                 control1: CGPoint(x: width * 0.35, y: height * CGFloat(level) * 1.5),
                                 control2: CGPoint(x: width * 0.65, y: height * CGFloat(level) * 0.4))
                context.addLine(to: CGPoint(x: width, y: 0))
                context.fillPath()
            }
        case 3:
            // The sea and a setting sun.
            white(context, 0.75)
            context.addArc(center: CGPoint(x: width / 2, y: height * 0.42), radius: 30, startAngle: 0, endAngle: .pi, clockwise: false)
            context.fillPath()
            white(context, 0.5)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height * 0.42))
            white(context, 0.7)
            context.setLineWidth(3)
            context.setLineCap(.round)
            for (row, inset) in [(0.3, 70.0), (0.2, 50.0), (0.1, 80.0)] {
                context.move(to: CGPoint(x: CGFloat(inset), y: height * CGFloat(row)))
                context.addLine(to: CGPoint(x: width - CGFloat(inset), y: height * CGFloat(row)))
                context.strokePath()
            }
        case 4:
            // A skyline.
            white(context, 0.72)
            let blocks: [(CGFloat, CGFloat, CGFloat)] = [(0.06, 0.12, 0.42), (0.2, 0.1, 0.62), (0.32, 0.14, 0.5), (0.48, 0.08, 0.74),
                                                         (0.58, 0.13, 0.46), (0.73, 0.1, 0.58), (0.85, 0.11, 0.36)]
            for (x, w, h) in blocks { context.fill(CGRect(x: width * x, y: 0, width: width * w, height: height * h)) }
        case 5:
            // A row of trees.
            for index in 0..<6 {
                let x = width * (0.1 + 0.16 * CGFloat(index)), tall = height * (0.42 + 0.12 * CGFloat(index % 3))
                white(context, 0.55 + 0.05 * CGFloat(index % 3))
                context.move(to: CGPoint(x: x - 18, y: height * 0.12)); context.addLine(to: CGPoint(x: x, y: tall)); context.addLine(to: CGPoint(x: x + 18, y: height * 0.12))
                context.fillPath()
                context.fill(CGRect(x: x - 3, y: 0, width: 6, height: height * 0.13))
            }
        default:
            // Dunes under a crescent moon.
            // The moon, less the disc that makes it a crescent.
            context.saveGState()
            context.addRect(CGRect(x: 0, y: 0, width: width, height: height))
            context.addEllipse(in: CGRect(x: width * 0.7 + 9, y: height * 0.64 + 6, width: 30, height: 30))
            context.clip(using: .evenOdd)
            white(context, 0.8)
            context.fillEllipse(in: CGRect(x: width * 0.7, y: height * 0.64, width: 30, height: 30))
            context.restoreGState()
            for (index, level) in [0.42, 0.26].enumerated() {
                white(context, 0.45 + 0.25 * CGFloat(index))
                context.move(to: CGPoint(x: 0, y: 0))
                context.addLine(to: CGPoint(x: 0, y: height * CGFloat(level) * 0.6))
                context.addQuadCurve(to: CGPoint(x: width, y: height * CGFloat(level)), control: CGPoint(x: width * 0.45, y: height * CGFloat(level) * 1.9))
                context.addLine(to: CGPoint(x: width, y: 0))
                context.fillPath()
            }
        }
    }
}
