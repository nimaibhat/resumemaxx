import SwiftUI

struct Sidebar: View {
    @ObservedObject var app: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Wordmark(size: 18)
                Button(action: pickFolder) {
                    Label(app.folder.lastPathComponent, systemImage: "folder")
                        .font(.caption)
                        .foregroundStyle(Theme.peri)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            }
            .padding(12)

            Divider()

            List(selection: Binding(get: { app.selected }, set: { if let r = $0 { app.select(r) } })) {
                Section("Resumes") {
                    ForEach(app.resumes) { resume in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(resume.isBuilt ? Theme.lilac : Theme.dimText)
                                .frame(width: 7, height: 7)
                            Text(resume.name)
                                .lineLimit(1)
                            Spacer()
                        }
                        .tag(resume)
                    }
                }
            }
            .listStyle(.sidebar)
        }
        .frame(maxHeight: .infinity)
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = app.folder
        if panel.runModal() == .OK, let url = panel.url {
            app.setFolder(url)
        }
    }
}
