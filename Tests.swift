import AppKit

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
}
