import AppKit
import AVKit
import Combine

final class MovieSurface: NSView {
    let playerLayer = AVPlayerLayer()
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        playerLayer.videoGravity = .resizeAspectFill
        layer?.addSublayer(playerLayer)
    }
    required init?(coder: NSCoder) { fatalError("Unsupported") }
    override func layout() { super.layout(); playerLayer.frame = bounds }
}

@MainActor final class Desktop: ObservableObject {
    @Published var current: Wallpaper?
    @Published var paused = false
    @Published var target = "all"
    @Published var screens = NSScreen.screens
    @Published var interval: Double = 300
    @Published var activePlaylist: UUID?
    var windows: [NSWindow] = []
    var players: [AVQueuePlayer] = []
    var loopers: [AVPlayerLooper] = []
    private var timer: Timer?
    private var observation: NSObjectProtocol?
    private var currentURL: URL?
    private var currentTarget = "all"
    static func id(_ screen: NSScreen) -> String { String(describing: screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] ?? "unknown") }
    init() {
        observation = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.screens = NSScreen.screens
                if let item = self.current, item.video, let url = self.currentURL {
                    let wasPaused = self.paused
                    try? self.apply(item, url: url, targetOverride: self.currentTarget)
                    if wasPaused { self.toggle() }
                }
            }
        }
    }
    func clearVideo() {
        players.forEach { $0.pause() }
        windows.forEach { $0.orderOut(nil); $0.close() }
        windows.removeAll(); loopers.removeAll(); players.removeAll()
    }
    func apply(_ item: Wallpaper, url: URL, targetOverride: String? = nil) throws {
        guard FileManager.default.isReadableFile(atPath: url.path) else { throw Failure.message("El archivo del fondo ya no está disponible.") }
        let selectedTarget = targetOverride ?? target
        let displays = NSScreen.screens.filter { selectedTarget == "all" || Self.id($0) == selectedTarget }
        guard !displays.isEmpty else { throw Failure.message("La pantalla seleccionada se desconectó.") }
        if item.video {
            clearVideo()
            for screen in displays {
                let player = AVQueuePlayer()
                player.isMuted = true
                let looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
                let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false
                window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
                window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
                window.ignoresMouseEvents = true
                window.backgroundColor = .black
                window.hasShadow = false
                let surface = MovieSurface(frame: CGRect(origin: .zero, size: screen.frame.size))
                surface.playerLayer.player = player
                window.contentView = surface
                window.setFrame(screen.frame, display: true)
                window.orderFrontRegardless()
                windows.append(window); players.append(player); loopers.append(looper)
                player.play()
            }
        } else {
            // Restore earlier displays if a later display rejects the image.
            let previous = displays.map { ($0, NSWorkspace.shared.desktopImageURL(for: $0), NSWorkspace.shared.desktopImageOptions(for: $0) ?? [:]) }
            do {
                for screen in displays { try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [.imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue, .allowClipping: true]) }
            } catch {
                for (screen, old, options) in previous { if let old { try? NSWorkspace.shared.setDesktopImageURL(old, for: screen, options: options) } }
                throw error
            }
            clearVideo()
        }
        current = item; currentURL = url; currentTarget = selectedTarget; paused = false
    }
    func toggle() {
        paused.toggle()
        for player in players { if paused { player.pause() } else { player.play() } }
    }
    func stop() { timer?.invalidate(); timer = nil; activePlaylist = nil; clearVideo(); current = nil; currentURL = nil; paused = false }
    func start(_ playlist: Playlist, library: Library) {
        timer?.invalidate()
        activePlaylist = playlist.id
        next(library: library)
        timer = Timer.scheduledTimer(withTimeInterval: max(10, interval), repeats: true) { [weak self, weak library] _ in
            Task { @MainActor in if let library { self?.next(library: library) } }
        }
    }
    func next(library: Library, offset: Int = 1) {
        let ids = library.catalog.playlists.first { $0.id == activePlaylist }?.items
        let items = ids.map { ids in ids.compactMap { id in library.catalog.wallpapers.first { $0.id == id } } } ?? library.catalog.wallpapers
        guard !items.isEmpty else { stop(); return }
        let index = current.flatMap { c in items.firstIndex(where: { $0.id == c.id }) } ?? (offset > 0 ? -1 : 0)
        let item = items[(index + offset + items.count) % items.count]
        do { try apply(item, url: library.url(item)) } catch { library.error = error.localizedDescription }
    }
}
