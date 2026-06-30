import SwiftUI

struct PreviewColumn: View {
    @ObservedObject var app: AppState
    @StateObject private var pdf = PDFController()

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().overlay(Theme.border)
            content
        }
        .background(Theme.bg)
    }

    private var toolbar: some View {
        HStack(spacing: Space.sm) {
            Text(app.selected?.name ?? "no resume open")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
            if app.compiling { ProgressView().controlSize(.small).scaleEffect(0.7) }
            Text(app.status)
                .font(.system(size: 11))
                .foregroundStyle(app.status == "compile error" ? Theme.danger : Theme.textMuted)

            Spacer()

            if !app.showingCode && app.pdfURL != nil {
                iconButton("minus.magnifyingglass", "Zoom out") { pdf.zoomOut() }
                iconButton("arrow.up.left.and.arrow.down.right.magnifyingglass", "Fit") { pdf.fit() }
                iconButton("plus.magnifyingglass", "Zoom in") { pdf.zoomIn() }
                Divider().frame(height: 14).overlay(Theme.border)
            }
            // Code view toggle (small icon, top-right).
            iconButton(app.showingCode ? "doc.richtext" : "chevron.left.forwardslash.chevron.right",
                       app.showingCode ? "Show PDF" : "View source",
                       active: app.showingCode) {
                app.showingCode.toggle()
            }
            .disabled(app.selected == nil)
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, 6)
        .background(Theme.panel)
    }

    @ViewBuilder
    private var content: some View {
        if app.showingCode, let url = app.selected?.url {
            CodeView(url: url)
        } else {
            ZStack {
                Theme.bg
                PDFPreview(url: app.pdfURL, reloadToken: $app.reloadToken, controller: pdf)
                if app.pdfURL == nil {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 30))
                            .foregroundStyle(Theme.textMuted)
                        Text("Select a resume to preview")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textMuted)
                    }
                }
            }
        }
    }

    private func iconButton(_ system: String, _ help: String, active: Bool = false,
                            _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 12))
                .foregroundStyle(active ? Theme.accent : Theme.textSecondary)
                .frame(width: 22, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
