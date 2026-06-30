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

    // Provider settings (persisted).
    @Published var provider: Provider {
        didSet { UserDefaults.standard.set(provider.rawValue, forKey: "provider") }
    }
    @Published var openaiKey: String {
        didSet { UserDefaults.standard.set(openaiKey, forKey: "openaiKey") }
    }
    @Published var openaiModel: String {
        didSet { UserDefaults.standard.set(openaiModel, forKey: "openaiModel") }
    }

    func providerConfig() -> ProviderConfig {
        ProviderConfig(provider: provider, openaiKey: openaiKey, openaiModel: openaiModel.isEmpty ? "gpt-4o" : openaiModel)
    }

    // Re-send config (and reset the conversation) after a provider change.
    func reconfigureChat() {
        chat.provider = providerConfig()
        if let r = selected { chat.configure(r) }
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
        let d = UserDefaults.standard
        provider = Provider(rawValue: d.string(forKey: "provider") ?? "") ?? .claude
        openaiKey = d.string(forKey: "openaiKey") ?? ""
        openaiModel = d.string(forKey: "openaiModel") ?? "gpt-4o"
        rescan()
        chat.provider = providerConfig()
        chat.onTurnComplete = { [weak self] in self?.rescan() } // agent may have changed files
    }

    func organizeLibrary() {
        guard chat.ready else { return }
        chat.provider = providerConfig()
        chat.configureFolder(folder)
        selected = nil; pdfURL = nil; compileError = nil; pageCount = 0; watcher?.stop()
        chat.send(
            "Organize the LaTeX resumes in this folder into a clean structure: group related " +
            "resumes into subfolders by their target (company, role, scholarship, hackathon, or " +
            "a general base), using clear human-readable folder names. Use mkdir and mv to create " +
            "folders and move the .tex files. Do not change the contents of any resume, and do not " +
            "touch hidden folders or build artifacts.\n\n" +
            "Here are the resumes with their dates (use created/modified dates as a signal, e.g. " +
            "recency or grouping by season):\n\n" + libraryManifest() + "\n\n" +
            "When finished, give a short summary of the new layout."
        )
    }

    // A listing of every resume with its created/modified dates, for the agent.
    private func libraryManifest() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        var lines: [String] = []
        func walk(_ nodes: [FileNode], _ prefix: String) {
            for n in nodes {
                if n.isDir { walk(n.children ?? [], prefix + n.name + "/") }
                else {
                    let v = try? n.url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
                    let made = v?.creationDate.map(fmt.string(from:)) ?? "?"
                    let mod = v?.contentModificationDate.map(fmt.string(from:)) ?? "?"
                    lines.append("- \(prefix)\(n.url.lastPathComponent): created \(made), modified \(mod)")
                }
            }
        }
        walk(tree, "")
        return lines.joined(separator: "\n")
    }

    func setFolder(_ url: URL) {
        folder = url
        rescan()
    }

    func rescan() {
        tree = FileTree.build(folder)
        sortTree()
        buildIndex()
    }

    // MARK: ranked search (fuzzy name + content)

    private var indexNodes: [FileNode] = []
    private var contentCache: [String: (mtime: Double, text: String)] = [:]

    var hasResumes: Bool { !indexNodes.isEmpty }

    private func buildIndex() {
        var nodes: [FileNode] = []
        func walk(_ ns: [FileNode]) {
            for n in ns {
                if n.isDir { if let k = n.children { walk(k) } } else { nodes.append(n) }
            }
        }
        walk(tree)
        indexNodes = nodes
        for n in nodes {
            let key = n.url.path
            let m = mtime(n.url).timeIntervalSince1970
            if let c = contentCache[key], c.mtime == m { continue }
            let text = (try? String(contentsOf: n.url, encoding: .utf8))?.lowercased() ?? ""
            contentCache[key] = (m, text)
        }
    }

    private func isSubsequence(_ q: String, _ s: String) -> Bool {
        guard !q.isEmpty else { return true }
        var qi = q.startIndex
        for ch in s where ch == q[qi] {
            qi = q.index(after: qi)
            if qi == q.endIndex { return true }
        }
        return false
    }

    // Ranks resumes by name match (fuzzy/prefix/substring) plus content hits.
    func search(_ query: String) -> [FileNode] {
        let terms = query.lowercased().split(separator: " ").map(String.init).filter { !$0.isEmpty }
        guard !terms.isEmpty else { return indexNodes }
        let collapsed = terms.joined()
        var scored: [(node: FileNode, score: Int)] = []
        for n in indexNodes {
            let name = n.name.lowercased()
            let content = contentCache[n.url.path]?.text ?? ""
            var score = 0
            if name.hasPrefix(terms[0]) { score += 8 }
            if isSubsequence(collapsed, name) { score += 5 }
            for t in terms {
                if name.contains(t) { score += 6 }
                else if isSubsequence(t, name) { score += 2 }
                if content.contains(t) { score += 2 }
            }
            if score > 0 { scored.append((n, score)) }
        }
        return scored
            .sorted { $0.score != $1.score ? $0.score > $1.score
                      : $0.node.name.localizedCaseInsensitiveCompare($1.node.name) == .orderedAscending }
            .map(\.node)
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
        chat.provider = providerConfig()
        chat.configure(resume)
        opened[resume.url.path] = Date().timeIntervalSince1970
        UserDefaults.standard.set(opened, forKey: "openedDates")
        watcher = FileWatcher(url: resume.url) { [weak self] in self?.scheduleRecompile() }
    }

    func askAssistantToFix() {
        guard let err = compileError else { return }
        chat.send("The resume fails to compile with this LaTeX error:\n\n\(err)\n\nPlease fix it in the file.")
    }

    func tailorToJob(_ jd: String) {
        let text = jd.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, selected != nil else { return }
        chat.send(
            "Tailor my resume to the job description below. Reorder and rewrite bullet points to " +
            "emphasize the most relevant experience and match the role's important keywords and " +
            "priorities. Stay truthful (do not invent experience) and keep it to ONE page — use the " +
            "resume_report tool to verify after editing. Then give a short summary of what you changed.\n\n" +
            "JOB DESCRIPTION:\n\(text)"
        )
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
