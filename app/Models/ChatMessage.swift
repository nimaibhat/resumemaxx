import Foundation

struct ChatMessage: Identifiable {
    enum Role { case user, assistant }
    let id = UUID()
    var role: Role
    var text: String = ""
    var tools: [String] = []
    var streaming: Bool = false
}
