import SwiftUI

// Placeholder for the native chat, which will be backed by the Claude Agent SDK
// (via a Node sidecar). Wired up in the next step.
struct ChatPanel: View {
    @ObservedObject var app: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle().fill(Theme.accentBar).frame(width: 8, height: 8)
                Text("resumemaxx assistant")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Theme.lilac)
            }
            if let r = app.selected {
                Text("editing \(r.name)")
                    .font(.caption)
                    .foregroundStyle(Theme.peri)
            }
            Spacer()
            Text("Native chat connects here next (Claude Agent SDK).")
                .font(.callout)
                .foregroundStyle(Theme.dimText)
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.bg)
    }
}
