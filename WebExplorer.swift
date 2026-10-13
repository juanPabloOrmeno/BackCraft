import SwiftUI
import WebKit
import UniformTypeIdentifiers

struct DownloadedFile: Identifiable {
    let id = UUID()
    let url: URL
    var importable: Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .movie) || type.conforms(to: .image)
    }
}

@MainActor final class WebExplorer: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
    let homeURL: URL
    @Published var address = "moewalls.com"
    @Published var loading = false
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var error: String?
    @Published var downloads: [DownloadedFile] = []
    @Published var activeDownloads = 0
    @Published var message: String?
    private var started = false
    private var transfers: [ObjectIdentifier: (download: WKDownload, destination: URL?)] = [:]
    private let destinationChooser: ((String, @escaping (URL?) -> Void) -> Void)?
    // Lazy: opening the library or starting in the menu bar makes no web requests.
    lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = self
        view.uiDelegate = self
        view.allowsBackForwardNavigationGestures = true
        return view
    }()

    init(homeURL: URL = URL(string: "https://moewalls.com/")!,
         destinationChooser: ((String, @escaping (URL?) -> Void) -> Void)? = nil) {
        self.homeURL = homeURL
        self.destinationChooser = destinationChooser
        super.init()
    }

    func start() { guard !started else { return }; started = true; home() }
    func home() { error = nil; webView.load(URLRequest(url: homeURL)) }
    func refresh() { error = nil; if webView.url == nil { home() } else { webView.reload() } }
    func updateNavigation() {
        address = webView.url?.absoluteString ?? homeURL.absoluteString
        canGoBack = webView.canGoBack; canGoForward = webView.canGoForward
    }
    static func permits(_ url: URL?) -> Bool {
        guard let scheme = url?.scheme?.lowercased() else { return false }
        return ["https", "http", "about", "blob"].contains(scheme)
    }
    static func isDownload(_ response: URLResponse, canShow: Bool) -> Bool {
        if let http = response as? HTTPURLResponse,
           http.value(forHTTPHeaderField: "Content-Disposition")?.lowercased().hasPrefix("attachment") == true { return true }
        // Direct video links should save the media rather than trap it in an inline player.
        return !canShow || (response.mimeType?.hasPrefix("video/") == true)
    }
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard Self.permits(action.request.url) else { decisionHandler(.cancel); return }
        decisionHandler(action.shouldPerformDownload ? .download : .allow)
    }
    func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(Self.isDownload(response.response, canShow: response.canShowMIMEType) ? .download : .allow)
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if action.targetFrame == nil, Self.permits(action.request.url) { webView.load(action.request) }
        return nil
    }
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { loading = true; error = nil; updateNavigation() }
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) { updateNavigation() }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { loading = false; updateNavigation() }
    private func navigationFailed(_ failure: Error) {
        loading = false
        let ns = failure as NSError
        // Cancelled navigations and navigation-to-download transitions aren't failures.
        if (ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled) || (ns.domain == "WebKitErrorDomain" && ns.code == 102) { return }
        error = failure.localizedDescription
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { navigationFailed(error) }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { navigationFailed(error) }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { loading = false; error = "El navegador se cerró. Pulsa Recargar para volver a abrir el sitio." }
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) { track(download) }
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) { track(download) }
    private func track(_ download: WKDownload) {
        loading = false
        transfers[ObjectIdentifier(download)] = (download, nil)
        activeDownloads = transfers.count
        download.delegate = self
    }
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let name = URL(fileURLWithPath: suggestedFilename).lastPathComponent
        let choose: (URL?) -> Void = { [weak self] url in
            guard let self else { completionHandler(nil); return }
            if let url, FileManager.default.fileExists(atPath: url.path) {
                self.error = "Ya existe un archivo con ese nombre. Vuelve a descargar y elige un nombre nuevo."
                completionHandler(nil); return
            }
            if let url { self.transfers[ObjectIdentifier(download)] = (download, url) }
            completionHandler(url)
        }
        if let destinationChooser { destinationChooser(name, choose); return }
        let panel = NSSavePanel()
        panel.title = "Guardar descarga"
        panel.nameFieldStringValue = name
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        panel.canCreateDirectories = true
        panel.message = "Guarda el archivo. Después podrás importarlo a BackCraft."
        if let window = webView.window { panel.beginSheetModal(for: window) { result in choose(result == .OK ? panel.url : nil) } }
        else { panel.begin { result in choose(result == .OK ? panel.url : nil) } }
    }
    func downloadDidFinish(_ download: WKDownload) {
        if let transfer = transfers.removeValue(forKey: ObjectIdentifier(download)), let url = transfer.destination {
            downloads.insert(DownloadedFile(url: url), at: 0)
            message = "Descarga completada: \(url.lastPathComponent)"
        }
        activeDownloads = transfers.count
    }
    func download(_ download: WKDownload, didFailWithError failure: Error, resumeData: Data?) {
        transfers.removeValue(forKey: ObjectIdentifier(download))
        activeDownloads = transfers.count
        if (failure as NSError).code != NSURLErrorCancelled { error = "No se pudo descargar: \(failure.localizedDescription)" }
    }
    func cancelDownloads() {
        for transfer in transfers.values { transfer.download.cancel { _ in } }
        transfers.removeAll(); activeDownloads = 0
    }
    func importDownload(_ file: DownloadedFile, library: Library) {
        library.importing = true
        Task {
            defer { library.importing = false }
            do {
                let item = try await library.importFile(file.url)
                downloads.removeAll { $0.id == file.id }
                message = "\(item.name) ya está en Biblioteca. Selecciónalo allí para aplicarlo."
            } catch { self.error = error.localizedDescription }
        }
    }
}

struct EmbeddedWebView: NSViewRepresentable {
    let explorer: WebExplorer
    func makeNSView(context: Context) -> WKWebView { explorer.start(); return explorer.webView }
    func updateNSView(_ view: WKWebView, context: Context) {}
}

struct ExploreView: View {
    @ObservedObject var explorer: WebExplorer
    @EnvironmentObject var library: Library
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Button { explorer.webView.goBack() } label: { Image(systemName: "chevron.left") }.disabled(!explorer.canGoBack).help("Atrás")
                Button { explorer.webView.goForward() } label: { Image(systemName: "chevron.right") }.disabled(!explorer.canGoForward).help("Adelante")
                Button { explorer.home() } label: { Image(systemName: "house") }.help("MoeWalls")
                Button { explorer.refresh() } label: { Image(systemName: "arrow.clockwise") }.help("Recargar")
                Text(explorer.address).font(.caption).lineLimit(1).truncationMode(.middle).textSelection(.enabled)
                Spacer()
                if explorer.loading { ProgressView().controlSize(.small) }
                Button("Abrir en navegador") { if let url = explorer.webView.url ?? Optional(explorer.homeURL), ["http", "https"].contains(url.scheme) { NSWorkspace.shared.open(url) } }
            }.padding(12).background(.ultraThinMaterial)
            if let error = explorer.error {
                HStack { Image(systemName: "exclamationmark.triangle"); Text(error).font(.caption); Spacer(); Button("Cerrar") { explorer.error = nil } }.padding(10).background(.orange.opacity(0.14))
            }
            EmbeddedWebView(explorer: explorer).frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("MoeWalls · usa el botón de descarga del sitio.").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if explorer.activeDownloads > 0 {
                        ProgressView().controlSize(.small)
                        Text("\(explorer.activeDownloads) descarga(s)").font(.caption)
                        Button("Cancelar") { explorer.cancelDownloads() }
                    }
                }
                if let message = explorer.message { Text(message).font(.caption).foregroundStyle(.secondary) }
                if !explorer.downloads.isEmpty {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(explorer.downloads) { file in
                                HStack {
                                    Image(systemName: file.importable ? "film" : "doc.zipper")
                                    Text(file.url.lastPathComponent).font(.caption).lineLimit(1)
                                    Spacer()
                                    if file.importable { Button("Importar a Biblioteca") { explorer.importDownload(file, library: library) }.disabled(library.importing) }
                                    Button("Mostrar archivo") { NSWorkspace.shared.activateFileViewerSelecting([file.url]) }
                                    Button { explorer.downloads.removeAll { $0.id == file.id } } label: { Image(systemName: "xmark") }.help("Ocultar descarga")
                                }
                            }
                        }
                    }.frame(maxHeight: 100)
                }
            }.padding(12)
        }
    }
}
