import Foundation

// Resolve CLI tools by running a login shell, so we pick up the user's real PATH
// (TeX Live, nvm node, Homebrew) even when the app is launched from Finder.
enum Tools {
    private static var cache: [String: String] = [:]

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
