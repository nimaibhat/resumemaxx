import SwiftUI

struct Sidebar: View {
    @ObservedObject var app: AppState
    @State private var selectedURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(Theme.border)
            folderBar
            Divider().overlay(Theme.borderSubtle)
            list
        }
        .background(Theme.panel)
        .onChange(of: selectedURL) { url in
            if let url, url.pathExtension.lowercased() == "tex" { app.select(url: url) }
        }
    }

    private var header: some View {
        HStack {
            Wordmark(size: 14)
            Spacer()
            Menu {
                Button("New Resume") { app.newResume(in: nil) }
                Button("New Folder") { app.newFolder(in: nil) }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 22)
            .help("New resume or folder")
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm + 2)
    }

    private var folderBar: some View {
        Button(action: pickFolder) {
            HStack(spacing: 6) {
                Image(systemName: "folder").font(.system(size: 10))
                Text(app.folder.lastPathComponent).font(.system(size: 11)).lineLimit(1)
                Spacer()
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 8))
            }
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, Space.md)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .help("Change library folder")
    }

    private var list: some View {
        List(selection: $selectedURL) {
            OutlineGroup(app.tree, children: \.children) { node in
                row(node).tag(node.url)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(Theme.panel)
        .environment(\.defaultMinListRowHeight, 26)
    }

    private func row(_ node: FileNode) -> some View {
        HStack(spacing: 7) {
            Image(systemName: node.isDir ? "folder" : "doc.text")
                .font(.system(size: 11))
                .foregroundStyle(node.isDir ? Theme.textSecondary
                                 : (node.isBuilt ? Theme.accent : Theme.textMuted))
            Text(node.name)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .contextMenu { menu(node) }
    }

    @ViewBuilder
    private func menu(_ node: FileNode) -> some View {
        if node.isDir {
            Button("New Resume Here") { app.newResume(in: node.url) }
            Button("New Folder Here") { app.newFolder(in: node.url) }
            Divider()
        }
        Button("Rename") { app.rename(node.url) }
        if !node.isDir {
            Button("Duplicate") { app.duplicate(node.url) }
        }
        Button("Reveal in Finder") { FileOps.reveal(node.url) }
        Divider()
        Button("Delete", role: .destructive) { app.delete(node.url) }
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
