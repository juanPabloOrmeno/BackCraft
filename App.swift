import SwiftUI
import AVKit

struct Thumbnail: View {
    @EnvironmentObject var library: Library
    let item: Wallpaper
    @State private var image: NSImage?
    var body: some View {
        GeometryReader { g in
            ZStack {
                Color(white: 0.10)
                if let image { Image(nsImage: image).resizable().scaledToFill().frame(width: g.size.width, height: g.size.height).clipped() }
                else { ProgressView().controlSize(.small) }
            }
        }.task(id: item.file) { image = await library.thumbnail(item) }
    }
}

struct Card: View {
    @EnvironmentObject var library: Library
    let item: Wallpaper
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Thumbnail(item: item)
                .aspectRatio(1.65, contentMode: .fit)
                .overlay(alignment: .bottomLeading) {
                    LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .center, endPoint: .bottom)
                    HStack {
                        Text(item.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                        Spacer()
                        if item.video { Image(systemName: "play.circle.fill") }
                        if item.favorite { Image(systemName: "heart.fill").foregroundStyle(.pink) }
                    }.padding(14)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.09)))
        }.buttonStyle(.plain).accessibilityLabel(item.name)
    }
}

struct Preview: View {
    let url: URL
    @State private var player: AVPlayer?
    var body: some View {
        VideoPlayer(player: player).onAppear { player = AVPlayer(url: url); player?.isMuted = true; player?.play() }
            .onDisappear { player?.pause(); player = nil }
    }
}

struct RootView: View {
    @EnvironmentObject var library: Library
    @EnvironmentObject var desktop: Desktop
    @State private var section = "Descubrir"
    @State private var query = ""
    @State private var category = "Todo"
    @State private var selected: UUID?
    @State private var playlistName = ""
    @State private var chosenPlaylist: UUID?
    @State private var nameDraft = ""
    @State private var creationTheme = 0
    @State private var sortByName = false
    @State private var confirmRemoval = false
    let navigation = [("Descubrir", "star"), ("Explorar", "square.grid.2x2"), ("Crear", "plus.rectangle"), ("Listas de reproducción", "rectangle.stack"), ("Biblioteca", "rectangle.on.rectangle"), ("Favoritos", "heart")]
    var item: Wallpaper? { library.catalog.wallpapers.first { $0.id == selected } }
    var visible: [Wallpaper] {
        let entries = library.catalog.wallpapers.filter {
            (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)) &&
            (section != "Favoritos" || $0.favorite) && (category == "Todo" || $0.category == category)
        }
        return sortByName ? entries.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending } : entries
    }
    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(spacing: 0) {
                toolbar
                Divider().opacity(0.4)
                HStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 28) {
                            if section == "Descubrir" { discover }
                            else if section == "Crear" { creator }
                            else if section == "Listas de reproducción" { playlists }
                            else if section == "Ajustes" { settings }
                            else { gallery }
                        }.padding(section == "Descubrir" ? 0 : 28)
                    }
                    if let item, section != "Crear", section != "Ajustes", section != "Listas de reproducción" {
                        Divider()
                        inspector(item).frame(width: 280)
                    }
                }
                playback
            }
        }
        .background(Color(red: 0.055, green: 0.06, blue: 0.06))
        .preferredColorScheme(.dark)
        .frame(minWidth: 950, minHeight: 620)
        .alert("No se pudo completar", isPresented: Binding(get: { library.error != nil }, set: { if !$0 { library.error = nil } })) { Button("Aceptar") { library.error = nil } } message: { Text(library.error ?? "") }
        .confirmationDialog("¿Quitar este fondo de la biblioteca?", isPresented: $confirmRemoval) {
            Button("Quitar fondo", role: .destructive) { if let item { library.remove(item); selected = nil } }
        } message: { Text("El archivo original no se elimina. La copia local se conserva si está en uso como fondo.") }
    }
    var sidebar: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack { Image(systemName: "rectangle.lefthalf.inset.filled"); Spacer(); Text("BACKCRAFT").font(.caption2).foregroundStyle(.tertiary) }.padding(.bottom, 24)
            ForEach(navigation, id: \.0) { title, icon in
                Button { section = title; selected = nil; category = "Todo"; query = "" } label: {
                    Label(title, systemImage: icon).font(.system(size: 13, weight: .medium)).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 10).padding(.horizontal, 9)
                        .foregroundStyle(section == title ? Color.accentColor : .white.opacity(0.85))
                        .background(section == title ? .white.opacity(0.07) : .clear, in: RoundedRectangle(cornerRadius: 8))
                }.buttonStyle(.plain)
            }
            Spacer()
            Text("Biblioteca local").font(.caption).foregroundStyle(.secondary).padding(9)
            Button { section = "Ajustes"; selected = nil } label: { Label("Ajustes", systemImage: "gearshape").padding(9) }.buttonStyle(.plain)
        }.padding(12).frame(width: 192).background(.ultraThinMaterial)
    }
    var toolbar: some View {
        HStack {
            Text(section).font(.headline)
            Spacer()
            if library.importing { ProgressView().controlSize(.small); Text("Importando…").font(.caption) }
            TextField("Buscar fondos", text: $query).textFieldStyle(.roundedBorder).frame(width: 190).accessibilityLabel("Buscar fondos")
            Menu { Button("Nombre") { sortByName = true }; Button("Orden de importación") { sortByName = false } } label: { Image(systemName: "arrow.up.arrow.down") }
                .menuStyle(.borderlessButton).frame(width: 24).help("Ordenar")
            Button { library.chooseImport() } label: { Label("Importar", systemImage: "plus") }.disabled(library.importing)
        }.padding(.horizontal, 24).frame(height: 48)
    }
    var discover: some View {
        VStack(alignment: .leading, spacing: 28) {
            if let hero = visible.first {
                Thumbnail(item: hero).frame(height: 405).overlay(alignment: .bottomLeading) {
                    LinearGradient(colors: [.clear, Color(white: 0.055)], startPoint: .top, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("COLECCIÓN BACKCRAFT").font(.system(size: 10, weight: .bold)).tracking(2).padding(.horizontal, 10).padding(.vertical, 5).background(.white.opacity(0.08), in: Capsule())
                        Text(hero.name).font(.system(size: 36, weight: .bold))
                        HStack {
                            Text("Un nuevo ambiente para tu escritorio.").foregroundStyle(.secondary)
                            Spacer()
                            Button { apply(hero) } label: { Label("Aplicar", systemImage: "desktopcomputer") }.buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
                        }
                    }.padding(28)
                }
            }
            VStack(alignment: .leading, spacing: 28) {
                shelf("Destacados", items: visible)
                shelf("Abstracto", items: visible.filter { $0.category == "Abstracto" })
                shelf("Tus vídeos", items: visible.filter(\.video))
                if visible.isEmpty { empty }
            }.padding(.horizontal, 28).padding(.bottom, 28)
        }
    }
    func shelf(_ title: String, items: [Wallpaper]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if !items.isEmpty {
                HStack { Text(title).font(.title2.bold()); Spacer(); Button("Mostrar todo ›") { section = "Biblioteca" } .buttonStyle(.plain).foregroundStyle(.secondary) }
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) { ForEach(items) { entry in Card(item: entry) { select(entry) }.frame(width: 285) } }
                }
            }
        }
    }
    var gallery: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack { Text(section).font(.largeTitle.bold()); Spacer(); Text("\(visible.count) fondos").foregroundStyle(.secondary) }
            Picker("Categoría", selection: $category) {
                Text("Todo").tag("Todo")
                ForEach(Array(Set(library.catalog.wallpapers.map(\.category))).sorted(), id: \.self) { Text($0).tag($0) }
            }.pickerStyle(.segmented)
            if visible.isEmpty { empty }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 215), spacing: 18)], spacing: 20) {
                ForEach(visible) { entry in Card(item: entry) { select(entry) }.contextMenu {
                    Button("Aplicar") { apply(entry) }
                    Button(entry.favorite ? "Quitar favorito" : "Favorito") { library.favorite(entry.id) }
                    Button("Mostrar archivo") { NSWorkspace.shared.activateFileViewerSelecting([library.url(entry)]) }
                } }
            }
        }
    }
    var empty: some View {
        ContentUnavailableView { Label("Sin fondos", systemImage: "photo.on.rectangle.angled") } description: { Text("Importa una imagen o un vídeo para empezar.") } actions: { Button("Importar archivos") { library.chooseImport() } }
    }
    func select(_ entry: Wallpaper) { selected = entry.id; nameDraft = entry.name }
    func apply(_ entry: Wallpaper) { do { try desktop.apply(entry, url: library.url(entry)) } catch { library.error = error.localizedDescription } }
    func inspector(_ entry: Wallpaper) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack { Text("Detalles").font(.headline); Spacer(); Button { selected = nil } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain) }
                if entry.video { Preview(url: library.url(entry)).id(entry.id).frame(height: 145).clipShape(RoundedRectangle(cornerRadius: 12)) }
                else { Thumbnail(item: entry).frame(height: 145).clipShape(RoundedRectangle(cornerRadius: 12)) }
                Text(entry.name).font(.title2.bold())
                Label(entry.video ? "Fondo animado · bucle" : "Imagen", systemImage: entry.video ? "play.rectangle" : "photo").foregroundStyle(.secondary)
                TextField("Nombre", text: $nameDraft).onSubmit {
                    guard !nameDraft.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    library.commit { if let i = $0.wallpapers.firstIndex(where: { $0.id == entry.id }) { $0.wallpapers[i].name = nameDraft } }
                }
                displayPicker
                Button { apply(entry) } label: { Label("Aplicar al escritorio", systemImage: "desktopcomputer").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).controlSize(.large)
                Button { library.favorite(entry.id) } label: { Label(entry.favorite ? "Quitar favorito" : "Añadir a favoritos", systemImage: entry.favorite ? "heart.fill" : "heart") }
                Menu("Añadir a lista") {
                    if library.catalog.playlists.isEmpty { Text("Crea una lista en la barra lateral") }
                    ForEach(library.catalog.playlists) { playlist in Button(playlist.name) {
                        library.commit { data in if let i = data.playlists.firstIndex(where: { $0.id == playlist.id }), !data.playlists[i].items.contains(entry.id) { data.playlists[i].items.append(entry.id) } }
                    } }
                }
                Divider()
                Button("Mostrar en Finder") { NSWorkspace.shared.activateFileViewerSelecting([library.url(entry)]) }
                Button("Quitar de biblioteca", role: .destructive) { confirmRemoval = true }
                Text("Los vídeos se reproducen en el escritorio mientras BackCraft está abierto. No modifican la pantalla de bloqueo.").font(.caption).foregroundStyle(.secondary)
            }.padding(20)
        }
    }
    var displayPicker: some View {
        Picker("Pantalla", selection: $desktop.target) {
            Text("Todas las pantallas").tag("all")
            ForEach(desktop.screens, id: \.self) { screen in Text(screen.localizedName).tag(Desktop.id(screen)) }
        }
    }
    var playback: some View {
        HStack(spacing: 15) {
            Button { desktop.next(library: library, offset: -1) } label: { Image(systemName: "backward.end.fill") }.help("Anterior")
            Button { desktop.toggle() } label: { Image(systemName: desktop.paused ? "play.fill" : "pause.fill") }.disabled(desktop.current?.video != true).help("Pausar o reproducir vídeo")
            Button { desktop.next(library: library) } label: { Image(systemName: "forward.end.fill") }.help("Siguiente")
            if let current = desktop.current {
                Thumbnail(item: current).frame(width: 48, height: 30).clipShape(RoundedRectangle(cornerRadius: 5))
                VStack(alignment: .leading) { Text("Escritorio").font(.caption.bold()); Text(current.name).font(.caption2).foregroundStyle(.secondary) }
                Spacer()
                Button("Detener") { desktop.stop() }
            } else { Text("Elige un fondo para tu escritorio").foregroundStyle(.secondary).font(.caption); Spacer() }
            Image(systemName: "display").foregroundStyle(.secondary)
        }.buttonStyle(.plain).padding(.horizontal, 22).frame(height: 60).background(.ultraThinMaterial)
    }
    var creator: some View {
        VStack(alignment: .leading, spacing: 25) {
            Text("Crear un nuevo fondo").font(.largeTitle.bold())
            Text("Importa una imagen o un vídeo; también puedes generar un fondo abstracto en 2560 × 1440.").foregroundStyle(.secondary)
            Button { library.chooseImport() } label: { Label("Elegir imagen o vídeo…", systemImage: "square.and.arrow.down") }.controlSize(.large).buttonStyle(.borderedProminent)
            Divider()
            Picker("Paleta", selection: $creationTheme) { ForEach(0..<6) { i in Text(["Seda", "Aurora", "Horizonte", "Dunas", "Órbita", "Océano"][i]).tag(i) } }.frame(width: 320)
            Button("Generar y añadir a biblioteca") {
                do {
                    let url = library.media.appendingPathComponent(UUID().uuidString + ".png")
                    try Artwork.write(to: url, theme: creationTheme)
                    let entry = Wallpaper(name: "Fondo BackCraft", file: url.lastPathComponent, category: "Mis imágenes", video: false)
                    library.commit { $0.wallpapers.append(entry) }
                    section = "Biblioteca"; select(entry)
                } catch { library.error = error.localizedDescription }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    var playlists: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Listas de reproducción").font(.largeTitle.bold())
            HStack {
                TextField("Nombre de la nueva lista", text: $playlistName).frame(width: 280)
                Button("Crear lista") { let name = playlistName.trimmingCharacters(in: .whitespaces); if !name.isEmpty { let p = Playlist(name: name); library.commit { $0.playlists.append(p) }; chosenPlaylist = p.id; playlistName = "" } }.disabled(playlistName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Picker("Cambiar cada", selection: $desktop.interval) { Text("10 segundos").tag(10.0); Text("1 minuto").tag(60.0); Text("5 minutos").tag(300.0); Text("30 minutos").tag(1800.0) }.frame(width: 300)
            ForEach(library.catalog.playlists) { playlist in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(playlist.name).font(.title2.bold()); Text("\(playlist.items.count) fondos").foregroundStyle(.secondary); Spacer()
                        Button("Reproducir") { desktop.start(playlist, library: library) }.disabled(playlist.items.isEmpty)
                        Button("Eliminar lista", role: .destructive) { if desktop.activePlaylist == playlist.id { desktop.stop() }; library.commit { $0.playlists.removeAll { $0.id == playlist.id } } }
                    }
                    Text("Selecciona los fondos de esta lista").font(.caption).foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180))]) {
                        ForEach(library.catalog.wallpapers) { entry in
                            Toggle(entry.name, isOn: Binding(get: { playlist.items.contains(entry.id) }, set: { on in
                                library.commit { data in
                                    if let i = data.playlists.firstIndex(where: { $0.id == playlist.id }) {
                                        data.playlists[i].items.removeAll { $0 == entry.id }
                                        if on { data.playlists[i].items.append(entry.id) }
                                    }
                                }
                            }))
                        }
                    }
                }.padding(20).background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }
    var settings: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Ajustes").font(.largeTitle.bold())
            displayPicker.frame(width: 380)
            Text("La biblioteca se guarda en Application Support/Backdrop Studio. Los archivos importados se copian allí para que sigan disponibles aunque muevas el original.").foregroundStyle(.secondary)
            Button("Abrir almacenamiento") { NSWorkspace.shared.open(library.root) }
            Divider()
            Text("BackCraft · reconstrucción nativa").font(.headline)
            Text("Catálogo local y fondos BackCraft. No incluye el servicio de descargas de Cindori, cuenta, sincronización iCloud ni vídeo en la pantalla de bloqueo.").foregroundStyle(.secondary)
            Text("Cerrar la ventana mantiene los fondos animados; ⌘Q detiene los vídeos y las listas. Los fondos estáticos permanecen aplicados.").foregroundStyle(.secondary)
        }.frame(maxWidth: 650, alignment: .leading)
    }
}

struct BackCraftApp: App {
    @StateObject private var library = Library()
    @StateObject private var desktop = Desktop()
    var body: some Scene {
        Window("BackCraft", id: "main") {
            RootView().environmentObject(library).environmentObject(desktop)
        }.defaultSize(width: 1280, height: 820)
        .commands {
            CommandGroup(after: .newItem) { Button("Importar fondos…") { library.chooseImport() }.keyboardShortcut("o") }
        }
    }
}

@main enum Entry {
    @MainActor static func main() async {
        if CommandLine.arguments.contains("--self-test") {
            do { try await Tests.run(); print("PASS: persistence, import, thumbnails, favorites, playlists, invalid media") }
            catch { fputs("FAIL: \(error)\n", stderr); exit(1) }
        } else { BackCraftApp.main() }
    }
}
