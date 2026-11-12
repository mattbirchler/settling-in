// Draws the background of Settling In's disk image window: the app on the
// left, Applications on the right, and a curved arrow between them in the
// icon's indigo and orange.
//
//   swift scripts/dmg-background.swift OUT_DIR
//
// Writes background.png (640x400) and background@2x.png. The icon spots
// here must match the positions in scripts/dmg-settings.py.
import AppKit

let size = CGSize(width: 640, height: 400)
let appSpot = CGPoint(x: 160, y: 180)   // from the top left, like Finder
let applicationsSpot = CGPoint(x: 480, y: 180)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

let indigo: UInt32 = 0x2E2A78
let violet: UInt32 = 0x7B5AD6
let orange: UInt32 = 0xF58A3C
let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

func render(scale: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                               pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context
    let cg = context.cgContext
    // Flip so y runs down, matching Finder's icon positions.
    cg.translateBy(x: 0, y: size.height)
    cg.scaleBy(x: 1, y: -1)

    // A light backdrop, so Finder's icon labels stay readable in light and dark mode:
    // pale lavender at the top warming to cream at the bottom, like early morning.
    let sky = CGGradient(colorsSpace: sRGB, colors: [color(0xF1EEFB), color(0xFBF3EA)] as CFArray, locations: [0, 1])!
    cg.drawLinearGradient(sky, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
    func glow(_ hex: UInt32, _ center: CGPoint, _ radius: CGFloat, _ alpha: CGFloat) {
        let g = CGGradient(colorsSpace: sRGB, colors: [color(hex, alpha), color(hex, 0)] as CFArray, locations: [0, 1])!
        cg.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
    }
    glow(violet, CGPoint(x: 70, y: 40), 260, 0.16)
    glow(orange, CGPoint(x: 590, y: 380), 280, 0.18)

    // A few of the icon's stars, faint.
    cg.setFillColor(color(indigo, 0.16))
    for (x, y, r) in [(52.0, 96.0, 2.2), (300.0, 52.0, 1.8), (584.0, 70.0, 2.4), (344.0, 262.0, 1.6), (96.0, 318.0, 1.8), (556.0, 292.0, 1.6), (250.0, 300.0, 1.4)] {
        cg.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
    }

    // The arrow: an arc that rises from the app and comes down toward Applications.
    let start = CGPoint(x: 244, y: 176), end = CGPoint(x: 394, y: 176)
    let control = CGPoint(x: (start.x + end.x) / 2, y: 112)
    let shaft = CGMutablePath()
    shaft.move(to: start)
    shaft.addQuadCurve(to: end, control: control)
    // The head follows the curve's direction where it lands.
    let angle = atan2(end.y - control.y, end.x - control.x)
    let headLength: CGFloat = 20, spread: CGFloat = 0.62
    let head = CGMutablePath()
    head.move(to: CGPoint(x: end.x - headLength * cos(angle - spread), y: end.y - headLength * sin(angle - spread)))
    head.addLine(to: end)
    head.addLine(to: CGPoint(x: end.x - headLength * cos(angle + spread), y: end.y - headLength * sin(angle + spread)))
    let arrow = CGMutablePath()
    arrow.addPath(shaft.copy(strokingWithWidth: 7, lineCap: .round, lineJoin: .round, miterLimit: 10))
    arrow.addPath(head.copy(strokingWithWidth: 7, lineCap: .round, lineJoin: .round, miterLimit: 10))

    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: 3), blur: 8, color: color(indigo, 0.18))
    cg.addPath(arrow)
    cg.setFillColor(color(violet))
    cg.fillPath()
    cg.restoreGState()
    cg.saveGState()
    cg.addPath(arrow)
    cg.clip()
    let stroke = CGGradient(colorsSpace: sRGB, colors: [color(indigo), color(violet), color(orange)] as CFArray, locations: [0, 0.45, 1])!
    cg.drawLinearGradient(stroke, start: CGPoint(x: start.x - 6, y: 0), end: CGPoint(x: end.x + 6, y: 0), options: [])
    cg.restoreGState()

    // The instruction.
    var font = NSFont.systemFont(ofSize: 14, weight: .semibold)
    if let rounded = font.fontDescriptor.withDesign(.rounded), let f = NSFont(descriptor: rounded, size: 14) { font = f }
    let line = NSAttributedString(string: "Drag Settling In to Applications",
                                  attributes: [.font: font, .foregroundColor: NSColor(cgColor: color(indigo, 0.7))!])
    let baselineY: CGFloat = 322
    // NSAttributedString draws in AppKit's unflipped space, so flip back for the text alone.
    cg.saveGState()
    cg.translateBy(x: 0, y: size.height)
    cg.scaleBy(x: 1, y: -1)
    line.draw(at: CGPoint(x: (size.width - line.size().width) / 2, y: size.height - baselineY + font.descender))
    cg.restoreGState()

    NSGraphicsContext.current = nil
    return rep
}

let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
for (scale, name) in [(CGFloat(1), "background.png"), (CGFloat(2), "background@2x.png")] {
    let data = render(scale: scale).representation(using: .png, properties: [:])!
    try! data.write(to: outDir.appendingPathComponent(name))
}
