import Foundation

// A node in the resume library tree: a folder (with children) or a .tex file.
struct FileNode: Identifiable, Hashable {
    let url: URL
    let isDir: Bool
    var children: [FileNode]?
    var id: URL { url }
    var name: String { isDir ? url.lastPathComponent : url.deletingPathExtension().lastPathComponent }
    var isBuilt: Bool {
        !isDir && FileManager.default.fileExists(atPath: LatexCompiler.pdfURL(for: url).path)
    }
}

enum FileTree {
    // Builds a tree of folders + .tex files, pruning folders with no resumes.
    static func build(_ root: URL) -> [FileNode] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
        ) else { return [] }

        var folders: [FileNode] = []
        var files: [FileNode] = []
        for item in items {
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            if isDir {
                let kids = build(item)
                if !kids.isEmpty {
                    folders.append(FileNode(url: item, isDir: true, children: kids))
                } else {
                    // keep empty folders so the user can see/organize into them
                    folders.append(FileNode(url: item, isDir: true, children: []))
                }
            } else if item.pathExtension.lowercased() == "tex" {
                files.append(FileNode(url: item, isDir: false, children: nil))
            }
        }
        folders.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        files.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return folders + files
    }
}
