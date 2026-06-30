import SwiftUI

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var ready = false
    @Published var thinking = false

    var onTurnComplete: (() -> Void)?
    var provider = ProviderConfig.defaultClaude

    private let sidecar = Sidecar()

    init() {
        sidecar.onReady = { [weak self] in self?.ready = true }
        sidecar.onEvent = { [weak self] obj in self?.handle(obj) }
        sidecar.start()
    }

    func configure(_ resume: Resume) {
        messages.removeAll()
        thinking = false
        sidecar.sendConfig(
            cwd: resume.url.deletingLastPathComponent().path,
            texPath: resume.url.path,
            name: resume.url.lastPathComponent,
            provider: provider
        )
    }

    // Point the assistant at a whole folder (e.g. to organize the library).
    func configureFolder(_ url: URL) {
        messages.removeAll()
        thinking = false
        sidecar.sendConfig(cwd: url.path, texPath: nil, name: url.lastPathComponent, provider: provider)
    }

    func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !thinking else { return }
        messages.append(ChatMessage(role: .user, text: trimmed))
        sidecar.sendUser(trimmed)
        thinking = true
    }

    private func handle(_ obj: [String: Any]) {
        switch obj["type"] as? String {
        case "turn_start":
            messages.append(ChatMessage(role: .assistant, streaming: true))
        case "delta":
            if let t = obj["text"] as? String { appendToAssistant(t) }
        case "tool":
            let name = obj["name"] as? String ?? "tool"
            let summary = obj["summary"] as? String ?? ""
            addTool([name, summary].filter { !$0.isEmpty }.joined(separator: " "))
        case "turn_done":
            thinking = false
            if let i = lastAssistant() { messages[i].streaming = false }
            onTurnComplete?()  // the agent may have changed files; let the app refresh
        case "error":
            appendToAssistant("\n\n[error] " + (obj["message"] as? String ?? "unknown"))
            thinking = false
        default:
            break
        }
    }

    private func lastAssistant() -> Int? {
        messages.lastIndex { $0.role == .assistant }
    }

    private func appendToAssistant(_ t: String) {
        if let i = lastAssistant(), messages[i].streaming {
            messages[i].text += t
        } else {
            messages.append(ChatMessage(role: .assistant, text: t, streaming: true))
        }
    }

    private func addTool(_ label: String) {
        if let i = lastAssistant() {
            messages[i].tools.append(label)
        } else {
            messages.append(ChatMessage(role: .assistant, tools: [label], streaming: true))
        }
    }
}
