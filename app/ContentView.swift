import SwiftUI

struct ContentView: View {
    @State private var pdfURL: URL? = nil
    @State private var reloadToken = 0

    var body: some View {
        HSplitView {
            // Left: assistant column (chat lands here next).
            VStack(alignment: .leading, spacing: 12) {
                Wordmark(size: 24)
                Text("your resume copilot")
                    .font(.callout)
                    .foregroundStyle(Theme.peri)
                Spacer()
                Text("Native chat coming next.")
                    .foregroundStyle(Theme.dimText)
                Spacer()
            }
            .padding(20)
            .frame(minWidth: 320, idealWidth: 440)
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.bg)

            // Right: live PDF preview.
            VStack(spacing: 0) {
                HStack {
                    Text(pdfURL?.lastPathComponent ?? "no resume open")
                        .font(.system(.callout, design: .rounded))
                        .foregroundStyle(Theme.lilac)
                    Spacer()
                    Button("Open PDF") { openPDF() }
                        .buttonStyle(.borderless)
                        .foregroundStyle(Theme.blue)
                }
                .padding(8)
                .background(Theme.bg2)

                PDFPreview(url: pdfURL, reloadToken: $reloadToken)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(minWidth: 420)
        }
        .background(Theme.bg)
    }

    private func openPDF() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK {
            pdfURL = panel.url
            reloadToken += 1
        }
    }
}
