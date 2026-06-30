import AppKit

// File management for the library: create, rename, duplicate, delete, reveal.
enum FileOps {
    static let starterTemplate = """
    \\documentclass[11pt]{article}
    \\usepackage[margin=0.6in]{geometry}
    \\usepackage{enumitem}
    \\usepackage[hidelinks]{hyperref}
    \\pagestyle{empty}
    \\setlist[itemize]{leftmargin=*, noitemsep, topsep=2pt}

    \\begin{document}

    \\begin{center}
      {\\LARGE \\textbf{Your Name}}\\\\
      \\vspace{2pt}
      email@example.com $\\cdot$ (555) 555-5555 $\\cdot$ City, ST
    \\end{center}

    \\section*{Experience}
    \\textbf{Role} \\hfill Dates\\\\
    \\textit{Company} \\hfill City, ST
    \\begin{itemize}
      \\item Impact-driven bullet with a metric.
    \\end{itemize}

    \\section*{Education}
    \\textbf{School} \\hfill Year

    \\section*{Skills}
    Languages, tools, frameworks.

    \\end{document}
    """

    // Prompt for a name with a simple modal (SwiftUI alerts lack text fields on macOS).
    @MainActor
    static func promptName(_ title: String, defaultValue: String = "", confirm: String = "Create") -> String? {
        let alert = NSAlert()
        alert.messageText = title
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = defaultValue
        alert.accessoryView = field
        alert.addButton(withTitle: confirm)
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        let resp = alert.runModal()
        guard resp == .alertFirstButtonReturn else { return nil }
        let value = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    @discardableResult
    static func newResume(in dir: URL, name: String) -> URL? {
        let base = name.hasSuffix(".tex") ? String(name.dropLast(4)) : name
        let url = uniqueURL(dir.appendingPathComponent(base + ".tex"))
        do { try starterTemplate.write(to: url, atomically: true, encoding: .utf8); return url }
        catch { return nil }
    }

    @discardableResult
    static func newFolder(in dir: URL, name: String) -> URL? {
        let url = uniqueURL(dir.appendingPathComponent(name), isDir: true)
        do { try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true); return url }
        catch { return nil }
    }

    static func rename(_ url: URL, to newName: String) {
        let ext = url.pathExtension
        var target = url.deletingLastPathComponent().appendingPathComponent(newName)
        if !ext.isEmpty && target.pathExtension.lowercased() != ext.lowercased() {
            target.appendPathExtension(ext)
        }
        try? FileManager.default.moveItem(at: url, to: uniqueURL(target, isDir: url.hasDirectoryPath))
    }

    @discardableResult
    static func duplicate(_ url: URL) -> URL? {
        let target = uniqueURL(url)
        do { try FileManager.default.copyItem(at: url, to: target); return target }
        catch { return nil }
    }

    static func delete(_ url: URL) {
        try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }

    static func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    // Avoid clobbering an existing file/folder by appending " 2", " 3", ...
    private static func uniqueURL(_ url: URL, isDir: Bool = false) -> URL {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return url }
        let dir = url.deletingLastPathComponent()
        let ext = url.pathExtension
        let stem = ext.isEmpty ? url.lastPathComponent : url.deletingPathExtension().lastPathComponent
        var n = 2
        while true {
            let candidate = ext.isEmpty
                ? dir.appendingPathComponent("\(stem) \(n)")
                : dir.appendingPathComponent("\(stem) \(n)").appendingPathExtension(ext)
            if !fm.fileExists(atPath: candidate.path) { return candidate }
            n += 1
        }
    }
}
