import Foundation

// Spawns and talks to the Node Agent SDK sidecar over newline-delimited JSON.
final class Sidecar {
    private var proc: Process?
    private var stdinPipe: Pipe?
    private var buffer = Data()

    var onEvent: (([String: Any]) -> Void)?
    var onReady: (() -> Void)?

    func start() {
        guard proc == nil, let node = Tools.find("node") else { return }
        let script = Sidecar.scriptPath()
        guard FileManager.default.fileExists(atPath: script) else { return }

        let p = Process()
        p.executableURL = URL(fileURLWithPath: node)
        p.arguments = [script]
        p.currentDirectoryURL = URL(fileURLWithPath: script).deletingLastPathComponent()
        var env = ProcessInfo.processInfo.environment
        if let loginPath = Tools.loginPath() { env["PATH"] = loginPath }
        p.environment = env

        let inPipe = Pipe(), outPipe = Pipe()
        p.standardInput = inPipe
        p.standardOutput = outPipe
        p.standardError = Pipe()
        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty { self?.ingest(data) }
        }
        stdinPipe = inPipe
        do { try p.run() } catch { return }
        proc = p
    }

    private func ingest(_ data: Data) {
        buffer.append(data)
        while let nl = buffer.firstIndex(of: 0x0a) {
            let lineData = buffer.subdata(in: buffer.startIndex..<nl)
            buffer.removeSubrange(buffer.startIndex...nl)
            guard let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else { continue }
            DispatchQueue.main.async { [weak self] in
                if (obj["type"] as? String) == "ready" { self?.onReady?() }
                self?.onEvent?(obj)
            }
        }
    }

    private func send(_ obj: [String: Any]) {
        guard let inPipe = stdinPipe,
              var data = try? JSONSerialization.data(withJSONObject: obj) else { return }
        data.append(0x0a)
        inPipe.fileHandleForWriting.write(data)
    }

    func sendConfig(cwd: String, texPath: String?, name: String) {
        var obj: [String: Any] = ["type": "config", "cwd": cwd, "name": name]
        if let texPath { obj["texPath"] = texPath }
        send(obj)
    }

    func sendUser(_ text: String) {
        send(["type": "user", "text": text])
    }

    func stop() {
        proc?.terminate()
        proc = nil
    }

    // Dev: the repo sidecar. Override with RESUMEMAXX_SIDECAR; bundled later.
    static func scriptPath() -> String {
        if let env = ProcessInfo.processInfo.environment["RESUMEMAXX_SIDECAR"] { return env }
        if let res = Bundle.main.url(forResource: "sidecar", withExtension: "mjs") { return res.path }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/resumemaxx/sidecar/sidecar.mjs").path
    }
}
