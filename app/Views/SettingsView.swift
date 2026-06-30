import SwiftUI

struct SettingsView: View {
    @ObservedObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Settings").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.text)
                Spacer()
                Button("Done") { dismiss() }.foregroundStyle(Theme.accent)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("ASSISTANT MODEL")
                    .font(.system(size: 10, weight: .semibold)).kerning(0.5)
                    .foregroundStyle(Theme.textMuted)
                Picker("", selection: $app.provider) {
                    ForEach(Provider.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if app.provider == .claude {
                    Text("Uses your Claude Code login. No API key needed.")
                        .font(.system(size: 11)).foregroundStyle(Theme.textMuted)
                } else {
                    SecureField("OpenAI API key (sk-...)", text: $app.openaiKey)
                        .textFieldStyle(.roundedBorder)
                    TextField("Model", text: $app.openaiModel)
                        .textFieldStyle(.roundedBorder)
                    Text("Uses your OpenAI API key, stored locally on this Mac.")
                        .font(.system(size: 11)).foregroundStyle(Theme.textMuted)
                }
            }

            Divider().overlay(Theme.border)

            VStack(alignment: .leading, spacing: 7) {
                Text("TOOLS")
                    .font(.system(size: 10, weight: .semibold)).kerning(0.5)
                    .foregroundStyle(Theme.textMuted)
                ForEach(deps, id: \.name) { d in
                    HStack(spacing: 8) {
                        Image(systemName: d.ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(d.ok ? Color(hex: 0x4FB06A) : Theme.danger)
                        Text(d.name).font(.system(size: 12)).foregroundStyle(Theme.text)
                        Spacer()
                        if !d.ok {
                            Text(d.hint).font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(Theme.textMuted)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(20)
        .frame(width: 440, height: 380)
        .background(Theme.bg)
        .onDisappear { app.reconfigureChat() }
    }

    private var deps: [(name: String, ok: Bool, hint: String)] {
        [
            ("node", Tools.find("node") != nil, "brew install node"),
            ("latexmk", Tools.find("latexmk") != nil, "install BasicTeX / TeX Live"),
            ("pdfinfo", Tools.find("pdfinfo") != nil, "brew install poppler"),
            ("claude", Tools.find("claude") != nil, "claude.com/claude-code"),
        ]
    }
}
