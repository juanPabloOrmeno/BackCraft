import AppKit
import WebKit

@MainActor enum Tests {
    static func expect(_ condition: Bool, _ message: String) throws {
        if !condition { throw Failure.message(message) }
    }
    static func run() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("studio-tests-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = Library(root: root)
        try expect(library.error == nil && library.catalog.wallpapers.count == 6, "Initial library")
        let first = library.catalog.wallpapers[0]
        try expect(await library.thumbnail(first) != nil, "Real PNG thumbnail")
        library.favorite(first.id)
        var playlist = Playlist(name: "Test")
        playlist.items = [first.id]
        library.commit { $0.playlists.append(playlist) }
        let reloaded = Library(root: root)
        try expect(reloaded.catalog.wallpapers[0].favorite, "Favorite persistence")
        try expect(reloaded.catalog.playlists[0].items == [first.id], "Playlist persistence")
        let imported = try await reloaded.importFile(library.url(first))
        try expect(imported.id != first.id && FileManager.default.fileExists(atPath: reloaded.url(imported).path), "Managed media import")
        let bad = root.appendingPathComponent("bad.png")
        try Data("Not an image".utf8).write(to: bad)
        do { _ = try await reloaded.importFile(bad); throw Failure.message("Invalid media accepted") }
        catch let e as Failure { if e.localizedDescription == "Invalid media accepted" { throw e } }
        reloaded.remove(first)
        try expect(reloaded.catalog.playlists[0].items.isEmpty, "Remove cleans playlist")
        try expect(FileManager.default.fileExists(atPath: library.url(first).path), "Remove retains active wallpaper file")
    }

    // Uses a temporary library and doesn't apply wallpapers or touch user data.
    // Requires an interactive macOS session, so it is separate from --self-test.
    static func menuBar() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("backcraft-menu-test-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = NSApplication.shared
        let controller = MenuBarController(library: Library(root: root, seed: false), desktop: Desktop())
        defer { controller.shutdown() }
        controller.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        try expect(app.activationPolicy() == .accessory, "Must not appear in Dock")
        try expect(controller.statusItem?.button != nil && controller.statusItem?.isVisible == true, "Visible menu bar icon")
        try expect(controller.mainWindow == nil, "No window at launch")
        controller.statusItem?.button?.performClick(nil)
        let first = controller.mainWindow
        try expect(first?.isVisible == true, "Click opens management window")
        try expect(app.activationPolicy() == .accessory, "Opening must not add a Dock icon")
        first?.performClose(nil)
        try expect(first?.isVisible == false, "Close hides management window")
        try expect(controller.statusItem?.isVisible == true, "Menu bar survives closing")
        try expect(!controller.applicationShouldTerminateAfterLastWindowClosed(app), "Closing must not terminate playback owner")
        controller.statusItem?.button?.performClick(nil)
        try expect(controller.mainWindow === first && first?.isVisible == true, "Repeated clicks reuse window")
        controller.shutdown()
        try expect(controller.statusItem == nil && controller.mainWindow == nil, "Clean shutdown")
    }

    static func waitFor(_ message: String, timeout: TimeInterval = 20, until condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { throw Failure.message("Timeout: \(message)") }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    static func browser(baseURL: URL) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("backcraft-web-test-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.finishLaunching()
        let library = Library(root: root.appendingPathComponent("Library"), seed: false)
        let target = root.appendingPathComponent("download.png")
        let explorer = WebExplorer(homeURL: baseURL, destinationChooser: { _, completion in completion(target) })
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = explorer.webView
        window.orderFront(nil)
        defer { explorer.cancelDownloads(); explorer.webView.stopLoading(); window.close() }
        explorer.start()
        try await waitFor("WebKit page loaded") { explorer.webView.title == "BackCraft download test" && !explorer.loading }
        try expect(explorer.error == nil, "WebKit navigation")
        explorer.webView.load(URLRequest(url: baseURL.appendingPathComponent("wallpaper.png")))
        try await waitFor("Attachment downloaded") { !explorer.downloads.isEmpty || explorer.error != nil }
        try expect(explorer.error == nil && explorer.downloads.count == 1, explorer.error ?? "One download")
        try expect(explorer.activeDownloads == 0, "Download finished")
        try expect(FileManager.default.fileExists(atPath: target.path), "Saved download")
        explorer.importDownload(explorer.downloads[0], library: library)
        try await waitFor("Import completed") { !library.importing }
        try expect(library.catalog.wallpapers.count == 1 && explorer.downloads.isEmpty, "Downloaded image imports")
        let persisted = Library(root: library.root, seed: false)
        try expect(persisted.catalog.wallpapers.count == 1, "Imported download persists")

        var cancelPrompted = false
        let cancelled = WebExplorer(homeURL: baseURL, destinationChooser: { _, completion in cancelPrompted = true; completion(nil) })
        window.contentView = cancelled.webView
        cancelled.webView.load(URLRequest(url: baseURL.appendingPathComponent("wallpaper.png")))
        try await waitFor("Save cancelled") { cancelPrompted && cancelled.activeDownloads == 0 }
        try expect(cancelled.downloads.isEmpty && cancelled.error == nil, "Cancellation is not failure")
        cancelled.webView.stopLoading()

        try expect(!WebExplorer.permits(URL(string: "file:///etc/passwd")), "No local-file navigation")
        try expect(!WebExplorer.permits(URL(string: "javascript:alert(1)")), "No script navigation")
        try expect(WebExplorer.permits(URL(string: "https://moewalls.com/")), "MoeWalls permitted")
    }

    static func moeWallsSmoke() async throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.finishLaunching()
        let explorer = WebExplorer()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 750), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = explorer.webView
        window.orderFront(nil)
        defer { explorer.webView.stopLoading(); window.close() }
        explorer.start()
        try await waitFor("MoeWalls in embedded WebKit", timeout: 60) {
            (explorer.webView.title?.contains("MoeWalls") == true && !explorer.loading) || explorer.error != nil
        }
        try expect(explorer.error == nil, explorer.error ?? "MoeWalls navigation")
        print("Loaded in WebKit: \(explorer.webView.title ?? "") — \(explorer.address)")
    }
}
