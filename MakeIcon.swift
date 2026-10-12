// Original, resolution-independent BackCraft artwork. Run with xcrun swift.
import AppKit
import ImageIO
import UniformTypeIdentifiers

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: alpha)
}

func rounded(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func gradient(_ c: CGContext, _ colors: [CGColor], _ from: CGPoint, _ to: CGPoint) {
    let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: nil)!
    c.drawLinearGradient(g, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

func sheet(_ c: CGContext, x: CGFloat, y: CGFloat, angle: CGFloat, colors: [CGColor]) {
    c.saveGState()
    c.translateBy(x: x, y: y)
    c.rotate(by: angle * .pi / 180)
    let path = rounded(CGRect(x: -300, y: -215, width: 600, height: 430), 53)
    c.setShadow(offset: CGSize(width: 0, height: -16), blur: 24, color: color(0x000016, 0.5))
    c.addPath(path); c.setFillColor(colors[0]); c.fillPath()
    c.setShadow(offset: .zero, blur: 0, color: nil)
    c.addPath(path); c.clip()
    gradient(c, colors, CGPoint(x: -240, y: 230), CGPoint(x: 230, y: -200))
    c.resetClip()
    c.addPath(path); c.setLineWidth(3); c.setStrokeColor(color(0xffffff, 0.3)); c.strokePath()
    c.restoreGState()
}

func draw(_ c: CGContext) {
    let base = rounded(CGRect(x: 64, y: 64, width: 896, height: 896), 202)
    c.saveGState()
    c.setShadow(offset: CGSize(width: 0, height: -10), blur: 22, color: color(0x05061c, 0.32))
    c.addPath(base); c.setFillColor(color(0x11132c)); c.fillPath()
    c.restoreGState()
    c.saveGState()
    c.addPath(base); c.clip()
    gradient(c, [color(0x34395d), color(0x14182f), color(0x0b1021)], CGPoint(x: 120, y: 950), CGPoint(x: 850, y: 70))
    let halo = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [color(0x565beb, 0.4), color(0x565beb, 0)] as CFArray, locations: [0, 1])!
    c.drawRadialGradient(halo, startCenter: CGPoint(x: 620, y: 500), startRadius: 0, endCenter: CGPoint(x: 620, y: 500), endRadius: 570, options: [])
    c.restoreGState()
    c.addPath(base); c.setStrokeColor(color(0xffffff, 0.12)); c.setLineWidth(2); c.strokePath()

    // Two offset swatches and one landscape: a library of crafted backdrops.
    sheet(c, x: 470, y: 605, angle: 13, colors: [color(0xdcaaff), color(0x9762f8), color(0x6238c1)])
    sheet(c, x: 525, y: 550, angle: -8, colors: [color(0x9ec6ff), color(0x4e78f6), color(0x3c41ae)])

    let rect = CGRect(x: 198, y: 228, width: 650, height: 454)
    let front = rounded(rect, 56)
    c.saveGState()
    c.setShadow(offset: CGSize(width: 0, height: -24), blur: 36, color: color(0x020814, 0.6))
    c.addPath(front); c.setFillColor(color(0x65f6df)); c.fillPath()
    c.setShadow(offset: .zero, blur: 0, color: nil)
    c.addPath(front); c.clip()
    gradient(c, [color(0x12235d), color(0x246f9d), color(0x60d2c9)], CGPoint(x: 550, y: 690), CGPoint(x: 550, y: 210))

    c.setFillColor(color(0x9affee, 0.12)); c.fillEllipse(in: CGRect(x: 619, y: 459, width: 155, height: 155))
    c.setFillColor(color(0xc7fff1)); c.fillEllipse(in: CGRect(x: 643, y: 483, width: 107, height: 107))

    let distant = CGMutablePath()
    distant.move(to: CGPoint(x: 150, y: 385))
    distant.addCurve(to: CGPoint(x: 900, y: 497), control1: CGPoint(x: 400, y: 765), control2: CGPoint(x: 640, y: 290))
    distant.addLine(to: CGPoint(x: 900, y: 150)); distant.addLine(to: CGPoint(x: 150, y: 150)); distant.closeSubpath()
    c.saveGState(); c.addPath(distant); c.clip()
    gradient(c, [color(0x5cecdb), color(0x187d99)], CGPoint(x: 360, y: 570), CGPoint(x: 480, y: 270))
    c.restoreGState()

    let near = CGMutablePath()
    near.move(to: CGPoint(x: 170, y: 370))
    near.addCurve(to: CGPoint(x: 885, y: 415), control1: CGPoint(x: 430, y: 130), control2: CGPoint(x: 610, y: 630))
    near.addLine(to: CGPoint(x: 885, y: 150)); near.addLine(to: CGPoint(x: 170, y: 150)); near.closeSubpath()
    c.saveGState(); c.addPath(near); c.clip()
    gradient(c, [color(0x50e7c4), color(0x098383), color(0x09465f)], CGPoint(x: 800, y: 510), CGPoint(x: 290, y: 140))
    c.restoreGState()
    c.restoreGState()

    c.saveGState(); c.addPath(front); c.clip()
    c.addPath(front); c.setLineWidth(5); c.setStrokeColor(color(0xd0fffd, 0.65)); c.strokePath()
    c.restoreGState()

    // A small four-point glint evokes the craft/editing aspect, legible at Dock size.
    let sparkle = CGMutablePath()
    sparkle.move(to: CGPoint(x: 797, y: 819))
    sparkle.addQuadCurve(to: CGPoint(x: 849, y: 761), control: CGPoint(x: 802, y: 767))
    sparkle.addQuadCurve(to: CGPoint(x: 797, y: 701), control: CGPoint(x: 803, y: 754))
    sparkle.addQuadCurve(to: CGPoint(x: 745, y: 761), control: CGPoint(x: 790, y: 754))
    sparkle.addQuadCurve(to: CGPoint(x: 797, y: 819), control: CGPoint(x: 790, y: 768))
    sparkle.closeSubpath()
    c.setShadow(offset: .zero, blur: 15, color: color(0xc8c1ff, 0.55))
    c.addPath(sparkle); c.setFillColor(color(0xf4f3ff)); c.fillPath()
}

func render(size: Int, to url: URL) throws {
    guard let c = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw CocoaError(.fileWriteUnknown) }
    c.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    draw(c)
    guard let image = c.makeImage(), let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { throw CocoaError(.fileWriteUnknown) }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
}

guard CommandLine.arguments.count == 2 else { fatalError("Usage: swift MakeIcon.swift <Assets directory>") }
let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let iconset = root.appendingPathComponent("BackCraft.iconset", isDirectory: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    try render(size: points, to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try render(size: points * 2, to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
try render(size: 1024, to: root.appendingPathComponent("BackCraft.png"))
print("BackCraft artwork rendered at all macOS icon sizes.")
