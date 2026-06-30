import SwiftUI

struct ContentView: View {
    @StateObject private var app = AppState()

    var body: some View {
        NavigationSplitView {
            Sidebar(app: app)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            HSplitView {
                ChatPanel(app: app)
                    .frame(minWidth: 320, idealWidth: 420)
                PreviewColumn(app: app)
                    .frame(minWidth: 440)
            }
        }
        .navigationTitle("resumemaxx")
        .preferredColorScheme(.dark)
    }
}
