import SwiftUI

struct PreviewColumn: View {
    @ObservedObject var app: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(app.selected?.name ?? "no resume selected")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(Theme.lilac)
                if app.compiling {
                    ProgressView().controlSize(.small)
                }
                Spacer()
                Text(app.status)
                    .font(.caption)
                    .foregroundStyle(app.status == "compile error" ? Color.orange : Theme.dimText)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Theme.bg2)

            ZStack {
                Theme.bg
                PDFPreview(url: app.pdfURL, reloadToken: $app.reloadToken)
                if app.pdfURL == nil {
                    VStack(spacing: 6) {
                        Image(systemName: "doc.text")
                            .font(.largeTitle)
                            .foregroundStyle(Theme.dimText)
                        Text("Select a resume to preview")
                            .foregroundStyle(Theme.dimText)
                    }
                }
            }
        }
    }
}
