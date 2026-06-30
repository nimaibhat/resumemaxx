import Foundation

struct Snapshot: Identifiable, Hashable {
    let url: URL
    let date: Date
    let label: String
    var id: URL { url }
}

// Per-resume version history kept in .resumemaxx/snapshots/<name>/.
enum Snapshots {
    static func dir(for tex: URL) -> URL {
        tex.deletingLastPathComponent()
            .appendingPathComponent(".resumemaxx", isDirectory: true)
            .appendingPathComponent("snapshots", isDirectory: true)
            .appendingPathComponent(tex.deletingPathExtension().lastPathComponent, isDirectory: true)
    }

    @discardableResult
    static func take(_ tex: URL, label: String = "", at now: Date = Date()) -> URL? {
        let d = dir(for: tex)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        let ts = Int(now.timeIntervalSince1970)
        let safe = label.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: "~", with: "-")
        let name = safe.isEmpty ? "\(ts).tex" : "\(ts)~\(safe).tex"
        let url = d.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: tex) else { return nil }
        try? data.write(to: url, options: .atomic)
        return url
    }

    static func list(for tex: URL) -> [Snapshot] {
        let d = dir(for: tex)
        let items = (try? FileManager.default.contentsOfDirectory(at: d, includingPropertiesForKeys: nil)) ?? []
        return items.filter { $0.pathExtension == "tex" }.compactMap { url -> Snapshot? in
            let base = url.deletingPathExtension().lastPathComponent
            let parts = base.split(separator: "~", maxSplits: 1).map(String.init)
            guard let ts = Double(parts[0]) else { return nil }
            return Snapshot(url: url, date: Date(timeIntervalSince1970: ts), label: parts.count > 1 ? parts[1] : "")
        }.sorted { $0.date > $1.date }
    }

    static func restore(_ snap: Snapshot, to tex: URL) {
        guard let data = try? Data(contentsOf: snap.url) else { return }
        try? data.write(to: tex, options: .atomic)
    }

    static func delete(_ snap: Snapshot) {
        try? FileManager.default.removeItem(at: snap.url)
    }
}
