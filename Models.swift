import AppKit
import AVFoundation
import Combine
import UniformTypeIdentifiers

struct Wallpaper: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var file: String
    var category: String
    var video: Bool
    var favorite = false
    var created = Date()
}
struct Playlist: Codable, Identifiable {
    var id = UUID()
    var name: String
    var items: [UUID] = []
}
struct Catalog: Codable {
    var wallpapers: [Wallpaper] = []
    var playlists: [Playlist] = []
}

enum Failure: LocalizedError {
    case message(String)
    var errorDescription: String? { if case let .message(s) = self { return s }; return nil }
}

@MainActor final class Library: ObservableObject {
    @Published var catalog = Catalog()
    @Published var error: String?
    @Published var importing = false
    let root: URL
    private let cache = NSCache<NSString, NSImage>()
    var media: URL { root.appendingPathComponent("Media", isDirectory: true) }
    var database: URL { root.appendingPathComponent("library.json") }
    init(root: URL? = nil, seed: Bool = true) {
        self.root = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Backdrop Studio")
        do {
            try FileManager.default.createDirectory(at: media, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: database.path) {
                catalog = try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: database))
            } else if seed {
                let names = ["Seda nocturna", "Aurora", "Horizonte", "Dunas", "Órbita", "Océano"]
                for (i, name) in names.enumerated() {
                    let url = media.appendingPathComponent("studio-\(i).png")
                    try Artwork.write(to: url, theme: i)
                    catalog.wallpapers.append(Wallpaper(name: name, file: url.lastPathComponent, category: i == 2 || i == 3 ? "Paisajes" : "Abstracto", video: false))
                }
                try save()
            }
        } catch { self.error = error.localizedDescription }
        cache.countLimit = 100
    }
    func url(_ item: Wallpaper) -> URL { media.appendingPathComponent(item.file) }
    func save() throws {
        try JSONEncoder().encode(catalog).write(to: database, options: .atomic)
    }
    func commit(_ edit: (inout Catalog) -> Void) {
        let previous = catalog
        edit(&catalog)
        do { try save() } catch { catalog = previous; self.error = error.localizedDescription }
    }
    func favorite(_ id: UUID) {
        commit { if let i = $0.wallpapers.firstIndex(where: { $0.id == id }) { $0.wallpapers[i].favorite.toggle() } }
    }
    func remove(_ item: Wallpaper) {
        commit { data in
            data.wallpapers.removeAll { $0.id == item.id }
            for i in data.playlists.indices { data.playlists[i].items.removeAll { $0 == item.id } }
        }
        // Retain the managed media: a currently applied desktop may still reference it.
    }
    func thumbnail(_ item: Wallpaper) async -> NSImage? {
        if let hit = cache.object(forKey: item.file as NSString) { return hit }
        let path = url(item)
        let image: NSImage?
        if item.video {
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: path))
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 960, height: 540)
            if let result = try? await generator.image(at: .zero) {
                image = NSImage(cgImage: result.image, size: .zero)
            } else { image = nil }
        } else {
            image = await Task.detached(priority: .utility) {
                guard let source = CGImageSourceCreateWithURL(path as CFURL, nil),
                      let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 1400, kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary) else { return nil as NSImage? }
                return NSImage(cgImage: cg, size: .zero)
            }.value
        }
        if let image { cache.setObject(image, forKey: item.file as NSString) }
        return image
    }
    func importFile(_ source: URL) async throws -> Wallpaper {
        guard FileManager.default.isReadableFile(atPath: source.path) else { throw Failure.message("No se puede leer \(source.lastPathComponent).") }
        let type = UTType(filenameExtension: source.pathExtension)
        let video = type?.conforms(to: .movie) == true
        if video {
            guard try await AVURLAsset(url: source).load(.isPlayable) else { throw Failure.message("Vídeo no compatible: \(source.lastPathComponent)") }
        } else {
            guard type?.conforms(to: .image) == true, let s = CGImageSourceCreateWithURL(source as CFURL, nil), CGImageSourceCreateImageAtIndex(s, 0, nil) != nil else {
                throw Failure.message("Imagen no compatible: \(source.lastPathComponent)")
            }
        }
        let filename = UUID().uuidString + "." + source.pathExtension.lowercased()
        let destination = media.appendingPathComponent(filename)
        try await Task.detached { try FileManager.default.copyItem(at: source, to: destination) }.value
        let item = Wallpaper(name: source.deletingPathExtension().lastPathComponent, file: filename, category: video ? "Vídeos" : "Mis imágenes", video: video)
        catalog.wallpapers.append(item)
        do { try save() } catch {
            catalog.wallpapers.removeAll { $0.id == item.id }
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
        return item
    }
    func chooseImport() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .movie]
        panel.allowsMultipleSelection = true
        panel.message = "Importar imágenes o vídeos a tu biblioteca"
        guard panel.runModal() == .OK else { return }
        let urls = panel.urls
        importing = true
        Task {
            var errors: [String] = []
            for url in urls {
                do { _ = try await importFile(url) } catch { errors.append(error.localizedDescription) }
            }
            importing = false
            if !errors.isEmpty { error = errors.joined(separator: "\n") }
        }
    }
}

enum Artwork {
    static func write(to url: URL, theme: Int) throws {
        let w = 2560, h = 1440
        guard let c = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw Failure.message("No se pudo crear el fondo.") }
        let palettes: [[NSColor]] = [
            [.black, NSColor(white: 0.22, alpha: 1)],
            [NSColor(red: 0.02, green: 0.04, blue: 0.17, alpha: 1), .systemTeal],
            [NSColor(red: 0.13, green: 0.11, blue: 0.3, alpha: 1), .systemOrange],
            [NSColor(red: 0.23, green: 0.08, blue: 0.13, alpha: 1), .systemPink],
            [.black, .systemIndigo], [.black, .systemBlue]
        ]
        let colors = palettes[theme % palettes.count].map { $0.cgColor } as CFArray
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
        c.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: w, y: h), options: [])
        for i in 0..<14 {
            let y = CGFloat(i) * 155 - 700
            c.saveGState()
            c.move(to: CGPoint(x: -200, y: y))
            c.addCurve(to: CGPoint(x: 2800, y: y + 1000), control1: CGPoint(x: 650, y: y - 900), control2: CGPoint(x: 1750, y: y + 1900))
            c.addLine(to: CGPoint(x: 2800, y: 0)); c.addLine(to: .zero); c.closePath()
            c.clip()
            c.drawLinearGradient(gradient, start: CGPoint(x: 250, y: y), end: CGPoint(x: 1900, y: y + 1100), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            c.restoreGState()
            c.setStrokeColor(NSColor.white.withAlphaComponent(0.13).cgColor)
            c.setLineWidth(2)
            c.move(to: CGPoint(x: -200, y: y))
            c.addCurve(to: CGPoint(x: 2800, y: y + 1000), control1: CGPoint(x: 650, y: y - 900), control2: CGPoint(x: 1750, y: y + 1900))
            c.strokePath()
        }
        guard let image = c.makeImage(), let output = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { throw Failure.message("No se pudo guardar el fondo.") }
        CGImageDestinationAddImage(output, image, nil)
        guard CGImageDestinationFinalize(output) else { throw Failure.message("Error al escribir PNG.") }
    }
}
