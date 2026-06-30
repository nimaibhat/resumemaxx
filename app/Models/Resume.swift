import Foundation

struct Resume: Identifiable, Hashable {
    let url: URL              // the .tex file
    var id: URL { url }
    var name: String { url.deletingPathExtension().lastPathComponent }
    var folder: String { url.deletingLastPathComponent().lastPathComponent }
    var isBuilt: Bool {
        FileManager.default.fileExists(atPath: LatexCompiler.pdfURL(for: url).path)
    }
}

// Scans a folder (and one level of subfolders) for .tex resumes.
enum Library {
    static func scan(_ root: URL) -> [Resume] {
        let fm = FileManager.default
        var out: [Resume] = []
        func texFiles(in dir: URL) -> [URL] {
            (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil))?
                .filter { $0.pathExtension.lowercased() == "tex" } ?? []
        }
        out += texFiles(in: root).map(Resume.init)
        let subdirs = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey]))?
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .filter { !$0.lastPathComponent.hasPrefix(".") } ?? []
        for sub in subdirs { out += texFiles(in: sub).map(Resume.init) }
        return out.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
