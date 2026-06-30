import SwiftUI

struct ContentView: View {
    @StateObject private var app = AppState()

    var body: some View {
        HSplitView {
            Sidebar(app: app)
                .frame(minWidth: 200, idealWidth: 240, maxWidth: 360)

            ChatPanel(app: app, chat: app.chat)
                .frame(minWidth: 300, idealWidth: 420)
                .overlay(alignment: .trailing) {
                    Rectangle().fill(Theme.border).frame(width: 1)
                }

            PreviewColumn(app: app)
                .frame(minWidth: 440)
        }
        .background(Theme.bg)
        .preferredColorScheme(.dark)
    }
}
