import Foundation

// Resolve CLI tools by running a login shell, so we pick up the user's real PATH
// (TeX Live, nvm node, Homebrew) even when the app is launched from Finder.
enum Tools {
    private static var cache: [String: String] = [:]
    private static var _loginPath: String?

    // The user's real PATH from a login shell, so the sidecar and its child
    // processes (claude, latexmk, pdfinfo) resolve when launched from Finder.
    static func loginPath() -> String? {
        if let p = _loginPath { return p }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-lc", "echo -n $PATH"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        do { try proc.run() } catch { return nil }
        proc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let path, !path.isEmpty { _loginPath = path; return path }
        return nil
    }

    static func find(_ name: String) -> String? {
        if let hit = cache[name] { return hit }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/zsh")
        p.arguments = ["-lc", "command -v \(name)"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        do { try p.run() } catch { return nil }
        p.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) else { return nil }
        cache[name] = path
        return path
    }
}
