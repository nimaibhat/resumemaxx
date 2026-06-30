import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var folder: URL
    @Published var tree: [FileNode] = []
    @Published var selected: Resume?
    @Published var pdfURL: URL?
    @Published var reloadToken = 0
    @Published var status = ""
    @Published var compiling = false
    @Published var showingCode = false

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
        tree = FileTree.build(folder)
    }

    func select(url: URL) {
        select(Resume(url: url))
    }

    // MARK: file operations

    func newResume(in dir: URL?) {
        let target = dir ?? folder
        guard let name = FileOps.promptName("New resume name", defaultValue: "untitled") else { return }
        let created = FileOps.newResume(in: target, name: name)
        rescan()
        if let created { select(url: created) }
    }

    func newFolder(in dir: URL?) {
        let target = dir ?? folder
        guard let name = FileOps.promptName("New folder name", defaultValue: "Folder") else { return }
        FileOps.newFolder(in: target, name: name)
        rescan()
    }

    func rename(_ url: URL) {
        let current = url.deletingPathExtension().lastPathComponent
        guard let name = FileOps.promptName("Rename", defaultValue: current, confirm: "Rename") else { return }
        FileOps.rename(url, to: name)
        if selected?.url == url { selected = nil; pdfURL = nil; watcher?.stop() }
        rescan()
    }

    func duplicate(_ url: URL) {
        FileOps.duplicate(url)
        rescan()
    }

    func delete(_ url: URL) {
        FileOps.delete(url)
        if selected?.url == url { selected = nil; pdfURL = nil; watcher?.stop() }
        rescan()
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
