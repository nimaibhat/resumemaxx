import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var folder: URL
    @Published var resumes: [Resume] = []
    @Published var selected: Resume?
    @Published var pdfURL: URL?
    @Published var reloadToken = 0
    @Published var status = ""
    @Published var compiling = false

    let chat = ChatViewModel()

    private var watcher: FileWatcher?
    private var debounce: DispatchWorkItem?

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let def = home.appendingPathComponent("Documents/resumes")
        folder = FileManager.default.fileExists(atPath: def.path) ? def : home
        rescan()
    }

    func setFolder(_ url: URL) {
        folder = url
        rescan()
    }

    func rescan() {
        resumes = Library.scan(folder)
    }

    func select(_ resume: Resume) {
        selected = resume
        watcher?.stop()
        status = "compiling"
        recompile(initial: true)
        chat.configure(resume)
        watcher = FileWatcher(url: resume.url) { [weak self] in
            self?.scheduleRecompile()
        }
    }

    private func scheduleRecompile() {
        debounce?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.recompile(initial: false) }
        debounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    private func recompile(initial: Bool) {
        guard let tex = selected?.url else { return }
        compiling = true
        if initial { status = "compiling" }
        LatexCompiler.compile(tex) { [weak self] result in
            guard let self else { return }
            self.compiling = false
            if result.ok {
                self.pdfURL = result.pdf
                self.reloadToken += 1
                self.status = "up to date"
            } else {
                self.status = "compile error"
            }
        }
    }
}
