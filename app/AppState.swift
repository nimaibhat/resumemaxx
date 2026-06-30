import SwiftUI
import PDFKit

enum SortMode: String, CaseIterable, Identifiable {
    case modified, name, opened
    var id: String { rawValue }
    var label: String {
        switch self {
        case .modified: return "Last Modified"
        case .name: return "Name"
        case .opened: return "Recently Opened"
        }
    }
}

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
    @Published var compileError: String?
    @Published var pageCount = 0
    @Published var sortMode: SortMode {
        didSet {
            UserDefaults.standard.set(sortMode.rawValue, forKey: "sortMode")
            sortTree()
        }
    }

    let chat = ChatViewModel()

    private var watcher: FileWatcher?
    private var debounce: DispatchWorkItem?
    private var opened: [String: Double] =
        (UserDefaults.standard.dictionary(forKey: "openedDates") as? [String: Double]) ?? [:]

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let def = home.appendingPathComponent("Documents/resumes")
        folder = FileManager.default.fileExists(atPath: def.path) ? def : home
        sortMode = SortMode(rawValue: UserDefaults.standard.string(forKey: "sortMode") ?? "") ?? .modified
        rescan()
    }

    func setFolder(_ url: URL) {
        folder = url
        rescan()
    }

    func rescan() {
        tree = FileTree.build(folder)
        sortTree()
    }

    // MARK: sorting

    private func mtime(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    private func sortTree() {
        func sort(_ nodes: [FileNode]) -> [FileNode] {
            let folders = nodes.filter { $0.isDir }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                .map { node -> FileNode in
                    var n = node
                    if let kids = n.children { n.children = sort(kids) }
                    return n
                }
            var files = nodes.filter { !$0.isDir }
            switch sortMode {
            case .name:
                files.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            case .modified:
                files.sort { mtime($0.url) > mtime($1.url) }
            case .opened:
                files.sort { (opened[$0.url.path] ?? 0) > (opened[$1.url.path] ?? 0) }
            }
            return folders + files
        }
        tree = sort(tree)
    }

    // MARK: file operations

    func select(url: URL) { select(Resume(url: url)) }

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
        if selected?.url == url { clearSelection() }
        rescan()
    }

    func duplicate(_ url: URL) { FileOps.duplicate(url); rescan() }

    func delete(_ url: URL) {
        FileOps.delete(url)
        if selected?.url == url { clearSelection() }
        rescan()
    }

    private func clearSelection() {
        selected = nil; pdfURL = nil; compileError = nil; pageCount = 0; watcher?.stop()
    }

    // MARK: selection + compile

    func select(_ resume: Resume) {
        selected = resume
        watcher?.stop()
        status = "compiling"
        compileError = nil
        recompile(initial: true)
        chat.configure(resume)
        opened[resume.url.path] = Date().timeIntervalSince1970
        UserDefaults.standard.set(opened, forKey: "openedDates")
        watcher = FileWatcher(url: resume.url) { [weak self] in self?.scheduleRecompile() }
    }

    func askAssistantToFix() {
        guard let err = compileError else { return }
        chat.send("The resume fails to compile with this LaTeX error:\n\n\(err)\n\nPlease fix it in the file.")
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
                self.compileError = nil
                self.status = "up to date"
                if let pdf = result.pdf { self.pageCount = PDFDocument(url: pdf)?.pageCount ?? 0 }
            } else {
                self.compileError = Self.parseError(result.log)
                self.status = "compile error"
            }
        }
    }

    // Pull a concise message out of the latexmk/LaTeX log.
    private static func parseError(_ log: String) -> String {
        let lines = log.components(separatedBy: "\n")
        var picked: [String] = []
        for (i, line) in lines.enumerated() where line.hasPrefix("!") {
            picked.append(line)
            for j in (i + 1)...(min(i + 3, lines.count - 1)) where lines[j].hasPrefix("l.") {
                picked.append(lines[j]); break
            }
            if picked.count >= 4 { break }
        }
        if picked.isEmpty {
            picked = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.suffix(4)
        }
        return picked.joined(separator: "\n")
    }
}
