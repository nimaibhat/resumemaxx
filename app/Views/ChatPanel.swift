import SwiftUI

struct ChatPanel: View {
    @ObservedObject var app: AppState
    @ObservedObject var chat: ChatViewModel
    @State private var input = ""
    @State private var showSettings = false
    @State private var showTailor = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Theme.border)
            messages
            inputBar
        }
        .background(Theme.bg)
        .sheet(isPresented: $showSettings) { SettingsView(app: app) }
        .sheet(isPresented: $showTailor) { TailorSheet(app: app) }
    }

    private var header: some View {
        HStack(spacing: 7) {
            Image(systemName: "sparkle")
                .font(.system(size: 11))
                .foregroundStyle(Theme.accent)
            Text("Assistant")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.text)
            Text(app.provider.label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 5).padding(.vertical, 1.5)
                .background(Theme.elevated)
                .clipShape(Capsule())
            Spacer()
            Button { showTailor = true } label: {
                Image(systemName: "scope").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                    .frame(width: 20, height: 20).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(app.selected == nil)
            .help("Tailor to a job description")
            Button { showSettings = true } label: {
                Image(systemName: "gearshape").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                    .frame(width: 20, height: 20).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(Theme.panel)
    }

    private var messages: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if chat.messages.isEmpty {
                        Text(app.selected == nil
                             ? "Select a resume to start."
                             : "Ask me to tighten a bullet, fix LaTeX, or tailor this resume.")
                            .font(.callout)
                            .foregroundStyle(Theme.dimText)
                            .padding(.top, 8)
                    }
                    ForEach(chat.messages) { msg in
                        MessageRow(message: msg).id(msg.id)
                    }
                }
                .padding(12)
            }
            .onChange(of: chat.messages.last?.text) { _ in
                if let id = chat.messages.last?.id {
                    withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(id, anchor: .bottom) }
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField(app.selected == nil ? "Select a resume first" : "Message the assistant",
                      text: $input, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .padding(8)
                .background(Theme.bg2)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(.white)
                .disabled(app.selected == nil || !chat.ready)
                .onSubmit(submit)
            if chat.thinking {
                Button { chat.stop() } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.danger)
                }
                .buttonStyle(.plain)
                .help("Stop")
            } else {
                Button(action: submit) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(canSend ? Theme.accent : Theme.textMuted)
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
            }
        }
        .padding(10)
        .background(Theme.bg)
    }

    private var canSend: Bool {
        app.selected != nil && chat.ready && !chat.thinking &&
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        guard canSend else { return }
        chat.send(input)
        input = ""
    }
}

private struct MessageRow: View {
    let message: ChatMessage

    // Render inline markdown (bold, italic, code, links) while keeping newlines.
    static func markdown(_ s: String) -> AttributedString {
        (try? AttributedString(
            markdown: s,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(s)
    }

    var body: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
            if !message.tools.isEmpty {
                ForEach(message.tools) { tool in
                    let d = tool.display
                    HStack(spacing: 5) {
                        Image(systemName: d.icon).font(.system(size: 9))
                        Text(d.text).font(.system(size: 10.5)).lineLimit(1)
                    }
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Theme.elevated)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
                }
            }
            if !message.text.isEmpty || message.streaming {
                Group {
                    if message.text.isEmpty && message.streaming {
                        Text("...")
                    } else if message.role == .assistant {
                        Text(Self.markdown(message.text))
                    } else {
                        Text(message.text)
                    }
                }
                .textSelection(.enabled)
                .font(.system(size: 13))
                .foregroundStyle(message.role == .user ? .white : Theme.text)
                .padding(.horizontal, 11).padding(.vertical, 8)
                .background(message.role == .user ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.elevated))
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLg))
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }
}
