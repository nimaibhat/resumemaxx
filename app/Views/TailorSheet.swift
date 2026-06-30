import SwiftUI

struct TailorSheet: View {
    @ObservedObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var jd = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tailor to a job description")
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.text)
            Text("Paste a job description. The assistant rewrites and reorders bullets to match it, "
                 + "stays truthful, and verifies the resume still fits one page.")
                .font(.system(size: 11)).foregroundStyle(Theme.textMuted)
                .fixedSize(horizontal: false, vertical: true)

            TextEditor(text: $jd)
                .font(.system(size: 12))
                .foregroundStyle(Theme.text)
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minHeight: 220)
                .background(Theme.elevated)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.border, lineWidth: 1))

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.foregroundStyle(Theme.textSecondary)
                Button {
                    app.tailorToJob(jd); dismiss()
                } label: {
                    Text("Tailor").fontWeight(.medium).foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(canTailor ? Theme.accent : Theme.elevated)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                }
                .buttonStyle(.plain)
                .disabled(!canTailor)
            }
        }
        .padding(20)
        .frame(width: 500, height: 380)
        .background(Theme.bg)
    }

    private var canTailor: Bool {
        app.selected != nil && !jd.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
