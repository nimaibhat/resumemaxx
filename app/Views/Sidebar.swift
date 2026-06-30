import SwiftUI

struct Sidebar: View {
    @ObservedObject var app: AppState
    @ObservedObject var chat: ChatViewModel
    @State private var expanded: Set<URL> = []
    @State private var didInit = false
    @State private var search = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            folderBar
            searchBar
            Divider().overlay(Theme.border)
            tree
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.panel)
        .overlay(alignment: .trailing) {
            Rectangle().fill(Theme.border).frame(width: 1)
        }
        .onAppear {
            if !didInit { expanded = allFolders(app.tree); didInit = true }
        }
        .onChange(of: app.folder) { _ in expanded = allFolders(app.tree) }
    }

    // MARK: header

    private var header: some View {
        HStack(spacing: 6) {
            Wordmark(size: 13)
            Spacer()
            Button(action: organize) {
                HStack(spacing: 4) {
                    Image(systemName: "wand.and.stars").font(.system(size: 10, weight: .medium))
                    Text("Organize").font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(chat.ready ? Theme.accent : Theme.textMuted)
                .padding(.horizontal, 7)
                .frame(height: 22)
                .background(chat.ready ? Theme.accent.opacity(0.12) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!chat.ready)
            .help("Let the assistant sort your resumes into folders by target")

            Menu {
                Picker("Sort by", selection: $app.sortMode) {
                    ForEach(SortMode.allCases) { Text($0.label).tag($0) }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 18, height: 20)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Sort resumes")

            Menu {
                Button("New Resume") { app.newResume(in: nil) }
                Button("New Folder") { app.newFolder(in: nil) }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 18, height: 20)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("New resume or folder")
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .frame(height: 34)
    }

    private var searchBar: some View {
        HStack(spacing: 5) {
            Image(systemName: "magnifyingglass").font(.system(size: 10)).foregroundStyle(Theme.textMuted)
            TextField("Search resumes", text: $search)
                .textFieldStyle(.plain)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.text)
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 10)).foregroundStyle(Theme.textMuted)
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 26)
        .background(Theme.elevated)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
    }

    private var folderBar: some View {
        Button(action: pickFolder) {
            HStack(spacing: 5) {
                Image(systemName: "folder").font(.system(size: 9))
                Text(app.folder.lastPathComponent.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .kerning(0.4)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 7))
            }
            .foregroundStyle(Theme.textMuted)
            .padding(.horizontal, 10)
            .frame(height: 24)
        }
        .buttonStyle(.plain)
        .help("Change library folder")
    }

    // MARK: tree

    @ViewBuilder
    private var tree: some View {
        let isSearching = !search.trimmingCharacters(in: .whitespaces).isEmpty
        if !app.hasResumes && !isSearching {
            emptyState
        } else {
            let r = rows()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if r.isEmpty {
                        Text("No matches")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textMuted)
                            .padding(.horizontal, 12).padding(.top, 10)
                    }
                    ForEach(r) { row in
                        FileRow(
                            node: row.node,
                            depth: row.depth,
                            isExpanded: expanded.contains(row.node.url),
                            isSelected: app.selected?.url == row.node.url,
                            onTap: { tap(row.node) }
                        )
                        .contextMenu { menu(row.node) }
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.panel)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 26))
                .foregroundStyle(Theme.textMuted)
            Text("No resumes here")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
            Text("Create a resume in this folder, or open one that already has .tex files.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 7) {
                Button { app.newResume(in: nil) } label: {
                    Text("New Resume")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                }
                .buttonStyle(.plain)
                Button(action: pickFolder) {
                    Text("Open Folder")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Theme.elevated)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(Theme.panel)
    }

    private struct Row: Identifiable { let node: FileNode; let depth: Int; var id: URL { node.url } }

    private func rows() -> [Row] {
        let query = search.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            // Ranked results (fuzzy name + content), flattened.
            return app.search(query).map { Row(node: $0, depth: 0) }
        }
        var out: [Row] = []
        func walk(_ nodes: [FileNode], _ depth: Int) {
            for n in nodes {
                out.append(Row(node: n, depth: depth))
                if n.isDir, expanded.contains(n.url), let kids = n.children { walk(kids, depth + 1) }
            }
        }
        walk(app.tree, 0)
        return out
    }

    private func allFolders(_ nodes: [FileNode]) -> Set<URL> {
        var set: Set<URL> = []
        func walk(_ ns: [FileNode]) {
            for n in ns where n.isDir { set.insert(n.url); if let k = n.children { walk(k) } }
        }
        walk(nodes)
        return set
    }

    private func tap(_ node: FileNode) {
        if node.isDir {
            if expanded.contains(node.url) { expanded.remove(node.url) } else { expanded.insert(node.url) }
        } else {
            app.select(url: node.url)
        }
    }

    @ViewBuilder
    private func menu(_ node: FileNode) -> some View {
        if node.isDir {
            Button("New Resume Here") { app.newResume(in: node.url) }
            Button("New Folder Here") { app.newFolder(in: node.url) }
            Divider()
        }
        Button("Rename") { app.rename(node.url) }
        if !node.isDir { Button("Duplicate") { app.duplicate(node.url) } }
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
        if panel.runModal() == .OK, let url = panel.url { app.setFolder(url) }
    }

    private func organize() {
        let alert = NSAlert()
        alert.messageText = "Organize resumes with the assistant?"
        alert.informativeText = "Claude will read the resumes in \"\(app.folder.lastPathComponent)\" and "
            + "sort them into subfolders by target. It moves files but does not change their contents."
        alert.addButton(withTitle: "Organize")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn { app.organizeLibrary() }
    }
}

// A single dense, full-width row in the file tree.
private struct FileRow: View {
    let node: FileNode
    let depth: Int
    let isExpanded: Bool
    let isSelected: Bool
    let onTap: () -> Void
    @State private var hover = false

    var body: some View {
        HStack(spacing: 5) {
            if node.isDir {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 10)
            } else {
                Color.clear.frame(width: 10)
            }
            Image(systemName: node.isDir ? "folder.fill" : "doc.text")
                .font(.system(size: 11))
                .foregroundStyle(iconColor)
                .frame(width: 14)
            Text(node.name)
                .font(.system(size: 12.5, weight: isSelected ? .medium : .regular))
                .foregroundStyle(isSelected ? .white : Theme.textSecondary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.leading, CGFloat(8 + depth * 12))
        .padding(.trailing, 8)
        .padding(.vertical, 2.5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Theme.selection : (hover ? Theme.hover : Color.clear))
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onHover { hover = $0 }
    }

    private var iconColor: Color {
        if node.isDir { return Theme.textMuted }
        if isSelected { return .white }
        return node.isBuilt ? Theme.accent : Theme.textMuted
    }
}
