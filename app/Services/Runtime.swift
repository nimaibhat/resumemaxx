import Foundation

// Resolves and installs the Node assistant runtime so the app can be shipped
// without depending on the source repo. Resolution order:
//   1. RESUMEMAXX_SIDECAR override
//   2. the dev repo (if its node_modules is present) - keeps development working
//   3. the copy installed into Application Support
enum Runtime {
    static var appSupport: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("resumemaxx", isDirectory: true)
            .appendingPathComponent("sidecar", isDirectory: true)
    }
    static var devDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/resumemaxx/sidecar", isDirectory: true)
    }

    static func hasModules(_ dir: URL) -> Bool {
        FileManager.default.fileExists(atPath: dir.appendingPathComponent("node_modules").path)
    }

    static var isInstalled: Bool { scriptPath() != nil }

    static func scriptPath() -> String? {
        if let env = ProcessInfo.processInfo.environment["RESUMEMAXX_SIDECAR"] { return env }
        if hasModules(devDir) { return devDir.appendingPathComponent("sidecar.mjs").path }
        if hasModules(appSupport) { return appSupport.appendingPathComponent("sidecar.mjs").path }
        return nil
    }

    // Copy bundled source into Application Support and run `npm install`.
    static func install(onLine: @escaping (String) -> Void, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            do {
                try fm.createDirectory(at: appSupport, withIntermediateDirectories: true)
                for (name, ext) in [("sidecar", "mjs"), ("package", "json"), ("package-lock", "json")] {
                    guard let from = Bundle.main.url(forResource: name, withExtension: ext) else { continue }
                    let to = appSupport.appendingPathComponent("\(name).\(ext)")
                    if fm.fileExists(atPath: to.path) { try? fm.removeItem(at: to) }
                    try fm.copyItem(at: from, to: to)
                }
            } catch {
                DispatchQueue.main.async { onLine("copy failed: \(error.localizedDescription)"); completion(false) }
                return
            }
            guard let npm = Tools.find("npm") else {
                DispatchQueue.main.async { onLine("npm not found - install Node first"); completion(false) }
                return
            }
            let p = Process()
            p.executableURL = URL(fileURLWithPath: npm)
            p.arguments = ["install", "--omit=dev", "--no-audit", "--no-fund", "--legacy-peer-deps"]
            p.currentDirectoryURL = appSupport
            var env = ProcessInfo.processInfo.environment
            if let path = Tools.loginPath() { env["PATH"] = path }
            p.environment = env
            let pipe = Pipe()
            p.standardOutput = pipe
            p.standardError = pipe
            pipe.fileHandleForReading.readabilityHandler = { h in
                if let s = String(data: h.availableData, encoding: .utf8), !s.isEmpty {
                    DispatchQueue.main.async { onLine(s.trimmingCharacters(in: .newlines)) }
                }
            }
            do { try p.run() } catch {
                DispatchQueue.main.async { completion(false) }; return
            }
            p.waitUntilExit()
            pipe.fileHandleForReading.readabilityHandler = nil
            let ok = p.terminationStatus == 0 && hasModules(appSupport)
            DispatchQueue.main.async { completion(ok) }
        }
    }
}
