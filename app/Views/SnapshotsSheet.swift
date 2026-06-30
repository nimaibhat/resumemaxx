import SwiftUI

struct SnapshotsSheet: View {
    @ObservedObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var snaps: [Snapshot] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Version history")
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.text)
                Spacer()
                Button { app.takeSnapshot(); reload() } label: {
                    Label("Snapshot", systemImage: "camera")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain).foregroundStyle(Theme.accent)
                Button("Done") { dismiss() }.foregroundStyle(Theme.textSecondary)
            }

            if snaps.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath").font(.system(size: 24)).foregroundStyle(Theme.textMuted)
                    Text("No snapshots yet").font(.system(size: 12)).foregroundStyle(Theme.textMuted)
                    Text("Take a snapshot before big edits so you can roll back.")
                        .font(.system(size: 11)).foregroundStyle(Theme.textMuted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(snaps) { snap in
                            row(snap)
                            Divider().overlay(Theme.borderSubtle)
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 460, height: 420)
        .background(Theme.bg)
        .onAppear(perform: reload)
    }

    private func row(_ snap: Snapshot) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(snap.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 12)).foregroundStyle(Theme.text)
                if !snap.label.isEmpty {
                    Text(snap.label).font(.system(size: 10)).foregroundStyle(Theme.textMuted)
                }
            }
            Spacer()
            Button("Restore") { app.restoreSnapshot(snap); reload() }
                .buttonStyle(.plain).font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.accent)
            Button { Snapshots.delete(snap); reload() } label: {
                Image(systemName: "trash").font(.system(size: 11)).foregroundStyle(Theme.textMuted)
            }.buttonStyle(.plain)
        }
        .padding(.vertical, 9)
    }

    private func reload() { snaps = app.snapshotList() }
}
