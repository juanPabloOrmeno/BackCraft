import AppKit
import SwiftUI

/// Owns the library and playback independently of the optional management window.
@MainActor final class MenuBarController: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let library: Library
    let desktop: Desktop
    private(set) var statusItem: NSStatusItem?
    private(set) var mainWindow: NSWindow?

    init(library: Library? = nil, desktop: Desktop? = nil) {
        self.library = library ?? Library()
        self.desktop = desktop ?? Desktop()
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installApplicationMenu()
        installStatusItem()
        // Intentionally don't create or restore a management window at launch.
    }

    func installStatusItem() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.isVisible = true
        if let button = item.button {
            if let image = NSImage(systemSymbolName: "photo.on.rectangle", accessibilityDescription: "BackCraft") {
                image.isTemplate = true
                image.size = NSSize(width: 19, height: 18)
                button.image = image
            } else { button.title = "BC" }
            button.toolTip = "BackCraft · clic para abrir, clic derecho para opciones"
            button.setAccessibilityLabel("BackCraft")
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item
    }

    @objc func statusItemClicked(_ sender: Any?) {
        if let event = NSApp.currentEvent,
           event.type == .rightMouseUp || event.modifierFlags.contains(.control),
           let button = statusItem?.button {
            quickMenu().popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY), in: button)
        } else { showMainWindow() }
    }

    @objc func showMainWindow() {
        if mainWindow == nil {
            let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
            let available = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 850)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0,
                width: min(1280, available.width), height: min(820, available.height - 30)),
                styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "BackCraft"
            window.identifier = NSUserInterfaceItemIdentifier("BackCraft.main")
            window.isReleasedWhenClosed = false
            window.isRestorable = false
            window.delegate = self
            window.contentView = NSHostingView(rootView: RootView().environmentObject(library).environmentObject(desktop))
            window.contentMinSize = NSSize(width: 950, height: 620)
            window.appearance = NSAppearance(named: .darkAqua)
            window.setFrameOrigin(NSPoint(x: available.midX - window.frame.width / 2,
                                          y: available.midY - window.frame.height / 2))
            mainWindow = window
        }
        guard let window = mainWindow else { return }
        // Bring the existing window to the Space where the user clicked.
        if !window.styleMask.contains(.fullScreen) { window.collectionBehavior.insert(.moveToActiveSpace) }
        if window.isMiniaturized { window.deminiaturize(nil) }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        // Closing the library never destroys Desktop, its players or rotation timer.
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Launching the app again still stays in the menu bar; the icon opens the UI.
        installStatusItem()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) { shutdown() }

    func shutdown() {
        desktop.stop()
        mainWindow?.orderOut(nil)
        mainWindow?.delegate = nil
        mainWindow?.contentView = nil
        mainWindow?.close()
        mainWindow = nil
        if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
        statusItem = nil
    }

    func menuItem(_ title: String, _ action: Selector, key: String = "", enabled: Bool = true) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        item.isEnabled = enabled
        return item
    }

    func quickMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(menuItem("Abrir BackCraft", #selector(showMainWindow)))
        menu.addItem(.separator())
        menu.addItem(menuItem(desktop.paused ? "Reanudar vídeo" : "Pausar vídeo", #selector(toggleVideo), enabled: desktop.current?.video == true))
        menu.addItem(menuItem("Siguiente fondo", #selector(nextWallpaper), enabled: !library.catalog.wallpapers.isEmpty))
        menu.addItem(menuItem("Detener reproducción", #selector(stopPlayback), enabled: desktop.current != nil))
        menu.addItem(.separator())
        menu.addItem(menuItem("Salir de BackCraft", #selector(quit), key: "q"))
        return menu
    }

    @objc private func toggleVideo() { desktop.toggle() }
    @objc private func nextWallpaper() { desktop.next(library: library) }
    @objc private func stopPlayback() { desktop.stop() }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func importWallpapers() { showMainWindow(); library.chooseImport() }
    @objc private func closeMainWindow() { mainWindow?.performClose(nil) }

    private func installApplicationMenu() {
        let menu = NSMenu()
        let appMenu = NSMenu(title: "BackCraft")
        appMenu.addItem(menuItem("Abrir BackCraft", #selector(showMainWindow)))
        appMenu.addItem(.separator())
        appMenu.addItem(menuItem("Salir de BackCraft", #selector(quit), key: "q"))
        let appItem = NSMenuItem(); appItem.submenu = appMenu; menu.addItem(appItem)
        let fileMenu = NSMenu(title: "Archivo")
        fileMenu.addItem(menuItem("Importar fondos…", #selector(importWallpapers), key: "o"))
        fileMenu.addItem(menuItem("Cerrar ventana", #selector(closeMainWindow), key: "w"))
        let fileItem = NSMenuItem(title: "Archivo", action: nil, keyEquivalent: "")
        fileItem.submenu = fileMenu; menu.addItem(fileItem)
        let editMenu = NSMenu(title: "Editar")
        for (title, selector, key) in [("Deshacer", "undo:", "z"), ("Cortar", "cut:", "x"),
                                       ("Copiar", "copy:", "c"), ("Pegar", "paste:", "v"),
                                       ("Seleccionar todo", "selectAll:", "a")] {
            editMenu.addItem(NSMenuItem(title: title, action: Selector(selector), keyEquivalent: key))
        }
        let editItem = NSMenuItem(title: "Editar", action: nil, keyEquivalent: "")
        editItem.submenu = editMenu; menu.addItem(editItem)
        NSApp.mainMenu = menu
    }
}
