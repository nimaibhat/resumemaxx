import Foundation

enum Provider: String, CaseIterable, Identifiable {
    case claude, openai
    var id: String { rawValue }
    var label: String { self == .claude ? "Claude" : "OpenAI" }
}

// What the sidecar needs to route a turn to the right model.
struct ProviderConfig {
    var provider: Provider
    var openaiKey: String?
    var openaiModel: String

    static let defaultClaude = ProviderConfig(provider: .claude, openaiKey: nil, openaiModel: "gpt-4o")
}
