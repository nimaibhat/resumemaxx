import SwiftUI

// Lightweight source viewer/editor for the .tex. Save (Cmd-S) writes the file,
// which the watcher picks up to recompile.
struct CodeView: View {
    let url: URL
    @State private var text: String = ""
    @State private var dirty = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Space.sm) {
                Text(url.lastPathComponent)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
                if dirty {
                    Circle().fill(Theme.accent).frame(width: 5, height: 5)
                }
                Spacer()
                Button("Save") { save() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(dirty ? Theme.accent : Theme.textMuted)
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(!dirty)
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, 6)
            .background(Theme.panel)
            Divider().overlay(Theme.border)

            TextEditor(text: $text)
                .font(.system(size: 12.5, design: .monospaced))
                .foregroundStyle(Theme.text)
                .scrollContentBackground(.hidden)
                .background(Theme.bg)
                .onChange(of: text) { _ in dirty = true }
        }
        .background(Theme.bg)
        .onAppear(perform: load)
        .onChange(of: url) { _ in load() }
    }

    private func load() {
        text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        dirty = false
    }

    private func save() {
        guard dirty else { return }
        try? text.write(to: url, atomically: true, encoding: .utf8)
        dirty = false
    }
}
