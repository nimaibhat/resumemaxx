import SwiftUI

struct ChatPanel: View {
    @ObservedObject var app: AppState
    @ObservedObject var chat: ChatViewModel
    @State private var input = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Theme.bg2)
            messages
            inputBar
        }
        .background(Theme.bg)
    }

    private var header: some View {
        HStack(spacing: 7) {
            Image(systemName: "sparkle")
                .font(.system(size: 11))
                .foregroundStyle(Theme.accent)
            Text("Assistant")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.text)
            Spacer()
            if let r = app.selected {
                Text(r.name).font(.system(size: 11)).foregroundStyle(Theme.textMuted)
            } else if !chat.ready {
                Text("starting...").font(.system(size: 11)).foregroundStyle(Theme.textMuted)
            }
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
            Button(action: submit) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(canSend ? Theme.purple : Theme.dimText)
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
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

    var body: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
            if !message.tools.isEmpty {
                ForEach(message.tools, id: \.self) { tool in
                    HStack(spacing: 5) {
                        Image(systemName: "wrench.and.screwdriver").font(.caption2)
                        Text(tool).font(.caption.monospaced())
                    }
                    .foregroundStyle(Theme.peri)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Theme.bg2)
                    .clipShape(Capsule())
                }
            }
            if !message.text.isEmpty || message.streaming {
                Text(message.text.isEmpty && message.streaming ? "..." : message.text)
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
