import Foundation

struct ToolUse: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let summary: String

    // Friendly verb + SF Symbol for the chat activity chip.
    var display: (icon: String, text: String) {
        let n = name.lowercased()
        if n.contains("resume_report") { return ("ruler", "Checked layout") }
        if n.contains("read") || n == "glob" || n == "grep" { return ("doc.text.magnifyingglass", label("Read")) }
        if n.contains("write") || n.contains("edit") { return ("pencil", label("Edited")) }
        if n.contains("bash") || n.contains("run") { return ("terminal", label("Ran")) }
        return ("wrench.and.screwdriver", summary.isEmpty ? name : "\(name) \(summary)")
    }
    private func label(_ verb: String) -> String { summary.isEmpty ? verb : "\(verb) \(summary)" }
}

struct ChatMessage: Identifiable {
    enum Role { case user, assistant }
    let id = UUID()
    var role: Role
    var text: String = ""
    var tools: [ToolUse] = []
    var streaming: Bool = false
}
