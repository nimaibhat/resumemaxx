import Foundation

struct CompileResult {
    let ok: Bool
    let pdf: URL?
    let log: String
}

// Compiles a .tex into a contained .resumemaxx/build dir (junk never lands next
// to the source), mirroring the TUI behavior.
enum LatexCompiler {
    static func buildDir(for tex: URL) -> URL {
        tex.deletingLastPathComponent()
            .appendingPathComponent(".resumemaxx", isDirectory: true)
            .appendingPathComponent("build", isDirectory: true)
    }

    static func pdfURL(for tex: URL) -> URL {
        let base = tex.deletingPathExtension().lastPathComponent
        return buildDir(for: tex).appendingPathComponent(base + ".pdf")
    }

    static func compile(_ tex: URL, completion: @escaping (CompileResult) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = compileSync(tex)
            DispatchQueue.main.async { completion(result) }
        }
    }

    static func compileSync(_ tex: URL) -> CompileResult {
        guard let latexmk = Tools.find("latexmk") else {
            return CompileResult(ok: false, pdf: nil, log: "latexmk not found on PATH")
        }
        let out = buildDir(for: tex)
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

        let p = Process()
        p.executableURL = URL(fileURLWithPath: latexmk)
        p.currentDirectoryURL = tex.deletingLastPathComponent()
        p.arguments = [
            "-pdf", "-interaction=nonstopmode", "-halt-on-error", "-silent",
            "-outdir=\(out.path)", "-auxdir=\(out.path)",
            tex.lastPathComponent,
        ]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        do { try p.run() } catch {
            return CompileResult(ok: false, pdf: nil, log: "\(error)")
        }
        // Drain the pipe while running so a large log cannot deadlock the process.
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        let log = String(data: data, encoding: .utf8) ?? ""
        let pdf = pdfURL(for: tex)
        let ok = p.terminationStatus == 0 && FileManager.default.fileExists(atPath: pdf.path)
        return CompileResult(ok: ok, pdf: ok ? pdf : nil, log: log)
    }
}
