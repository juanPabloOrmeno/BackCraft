import AppKit
import ImageIO
import UniformTypeIdentifiers

// Finder's background canvas is 820 × 540 points. Render at 2× with a 144 dpi
// representation so it stays sharp on Retina displays without changing layout.
let width = 820, height = 540
func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: alpha)
}
func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
    NSRect(x: x, y: CGFloat(height) - y - h, width: w, height: h)
}
func label(_ text: String, x: CGFloat, y: CGFloat, w: CGFloat, size: CGFloat,
           weight: NSFont.Weight = .regular, ink: NSColor, align: NSTextAlignment = .left) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = align
    (text as NSString).draw(in: rect(x, y, w, size * 2.4), withAttributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: ink, .paragraphStyle: paragraph
    ])
}

guard CommandLine.arguments.count == 2 else { fatalError("Expected output PNG path") }
let image = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width * 2,
    pixelsHigh: height * 2, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
    isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
image.size = NSSize(width: width, height: height)
let graphics = NSGraphicsContext(bitmapImageRep: image)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphics
let c = graphics.cgContext
// NSGraphicsContext derives the 2× transform from the bitmap's logical size.

let background = NSGradient(starting: color(0x171d35), ending: color(0x090d19))!
background.draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: -65)
let halo = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [color(0x5442bf, alpha: 0.32).cgColor, color(0x5442bf, alpha: 0).cgColor] as CFArray, locations: [0, 1])!
c.drawRadialGradient(halo, startCenter: CGPoint(x: 700, y: 510), startRadius: 0,
                     endCenter: CGPoint(x: 700, y: 510), endRadius: 470, options: [])

// A quiet contour pattern echoes the application's wallpaper cards.
for i in 0..<7 {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: 490 + i * 21, y: 540))
    path.curve(to: NSPoint(x: 870, y: 210 + i * 13),
               controlPoint1: NSPoint(x: 330 + i * 30, y: 240),
               controlPoint2: NSPoint(x: 830, y: 450 + i * 12))
    color(0xc0b6ff, alpha: 0.035).setStroke(); path.lineWidth = 1; path.stroke()
}

let badge = NSBezierPath(roundedRect: rect(46, 30, 136, 25), xRadius: 12, yRadius: 12)
color(0x66e3d0, alpha: 0.1).setFill(); badge.fill()
label("HECHO PARA TU MAC", x: 54, y: 35, w: 120, size: 9, weight: .bold, ink: color(0x85e8d8), align: .center)
label("BackCraft", x: 44, y: 68, w: 670, size: 41, weight: .bold, ink: color(0xf5f7ff))
label("Tu escritorio, con otra mirada.", x: 46, y: 121, w: 710, size: 16, ink: color(0xa8b3cc))

// These wells sit behind the actual, draggable Finder icons.
for x: CGFloat in [205, 615] {
    let well = NSBezierPath(roundedRect: rect(x - 96, 190, 192, 176), xRadius: 26, yRadius: 26)
    color(0xffffff, alpha: 0.025).setFill(); well.fill()
    color(0xc3d1ef, alpha: 0.09).setStroke(); well.lineWidth = 1; well.stroke()
    // Finder uses dark label text in light appearance even on an image background.
    let caption = NSBezierPath(roundedRect: rect(x - 79, 321, 158, 27), xRadius: 13, yRadius: 13)
    color(0xd6dfef).setFill(); caption.fill()
}

let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 341, y: 285))
arrow.line(to: NSPoint(x: 478, y: 285))
arrow.move(to: NSPoint(x: 459, y: 303))
arrow.line(to: NSPoint(x: 478, y: 285))
arrow.line(to: NSPoint(x: 459, y: 267))
color(0x70dfd1).setStroke(); arrow.lineWidth = 2.5; arrow.lineCapStyle = .round; arrow.lineJoinStyle = .round; arrow.stroke()
label("ARRASTRA AQUÍ", x: 335, y: 281, w: 150, size: 10, weight: .semibold, ink: color(0x8b9bb6), align: .center)

label("Instálalo en un gesto", x: 60, y: 395, w: 700, size: 21, weight: .semibold, ink: color(0xe4eafb), align: .center)
label("Arrastra BackCraft a Aplicaciones y ábrelo desde allí.", x: 50, y: 429, w: 720, size: 14, ink: color(0x9daac4), align: .center)
color(0xffffff, alpha: 0.07).setFill(); NSBezierPath(rect: rect(46, 480, 728, 1)).fill()
label("IMÁGENES  /  VÍDEOS  /  TU ESPACIO", x: 46, y: 501, w: 470, size: 9, weight: .medium, ink: color(0x6f809f))
label("macOS 14+  ·  Apple Silicon", x: 505, y: 498, w: 270, size: 11, ink: color(0x8291aa), align: .right)

NSGraphicsContext.restoreGraphicsState()
guard let png = image.representation(using: .png, properties: [:]) else { fatalError("PNG encoding failed") }
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic)
print("Installer artwork rendered (820 × 540 pt, Retina).")
