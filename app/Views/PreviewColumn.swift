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
            if app.pageCount > 1 && app.compileError == nil {
                Label("\(app.pageCount) pages", systemImage: "exclamationmark.triangle.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(hex: 0xE0A33A))
                    .help("Resumes are usually one page")
            }

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
        .frame(height: 34)
        .background(Theme.panel)
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 0) {
            if let err = app.compileError {
                errorBanner(err)
                Divider().overlay(Theme.border)
            }
            if app.showingCode, let url = app.selected?.url {
                CodeView(url: url)
            } else {
                ZStack {
                    Theme.bg
                    PDFPreview(url: app.pdfURL, reloadToken: $app.reloadToken, controller: pdf)
                    if app.pdfURL == nil && app.compileError == nil {
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
    }

    private func errorBanner(_ err: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12)).foregroundStyle(Theme.danger).padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text("Compile failed").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.text)
                Text(err).font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary).lineLimit(4).textSelection(.enabled)
            }
            Spacer(minLength: 8)
            VStack(spacing: 6) {
                Button("Fix with assistant") { app.askAssistantToFix() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                    .disabled(!app.chat.ready)
                Button("View source") { app.showingCode = true }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: 0x1E1414))
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
