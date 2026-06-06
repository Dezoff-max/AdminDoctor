import AdminDocCore
import SwiftUI

struct CleanupReviewView: View {
    let snapshot: CleanupSnapshot?
    @Binding var selectedIDs: Set<UUID>
    let isScanning: Bool
    let isCleaning: Bool
    let error: String?
    let notice: String?
    let scan: () -> Void
    let clean: () -> Void

    @State private var confirmingCleanup = false

    private var candidates: [CleanupCandidate] {
        snapshot?.candidates ?? []
    }

    private var selectedCandidates: [CleanupCandidate] {
        candidates.filter { selectedIDs.contains($0.id) }
    }

    private var selectedBytes: Int64 {
        selectedCandidates.reduce(0) { $0 + $1.byteCount }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Label("Storage cleanup", systemImage: "trash")
                    .font(.headline)

                Spacer()

                if let snapshot {
                    Text("\(candidates.count) items, \(snapshot.totalBytesLabel)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Button {
                    scan()
                } label: {
                    Label("Scan", systemImage: "magnifyingglass")
                }
                .disabled(isScanning || isCleaning)

                Button(role: .destructive) {
                    confirmingCleanup = true
                } label: {
                    Label("Move to Trash", systemImage: "trash")
                }
                .disabled(selectedIDs.isEmpty || isScanning || isCleaning)
            }

            if isScanning || isCleaning {
                ProgressView()
                    .controlSize(.small)
            }

            if let error {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            } else if let notice {
                Text(notice)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if candidates.isEmpty {
                Text(snapshot == nil ? "No cleanup scan has been run." : "No cleanup candidates found.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                HStack {
                    Button("Select recommended") {
                        selectedIDs = Set(candidates.filter(\.defaultSelected).map(\.id))
                    }
                    .disabled(isScanning || isCleaning)

                    Button("Clear") {
                        selectedIDs.removeAll()
                    }
                    .disabled(selectedIDs.isEmpty || isScanning || isCleaning)

                    Spacer()

                    Text("\(selectedCandidates.count) selected, \(ByteCountFormatter.string(fromByteCount: selectedBytes, countStyle: .file))")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(candidates.prefix(120)) { candidate in
                            CleanupCandidateRow(
                                candidate: candidate,
                                isSelected: Binding(
                                    get: { selectedIDs.contains(candidate.id) },
                                    set: { isSelected in
                                        if isSelected {
                                            selectedIDs.insert(candidate.id)
                                        } else {
                                            selectedIDs.remove(candidate.id)
                                        }
                                    }
                                )
                            )
                            .disabled(isScanning || isCleaning)

                            if candidate.id != candidates.prefix(120).last?.id {
                                Divider()
                            }
                        }
                    }
                }
                .frame(maxHeight: 260)
            }
        }
        .padding(16)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .confirmationDialog(
            "Move selected cleanup items to Trash?",
            isPresented: $confirmingCleanup,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                clean()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(selectedCandidates.count) item(s), \(ByteCountFormatter.string(fromByteCount: selectedBytes, countStyle: .file)).")
        }
    }
}

private struct CleanupCandidateRow: View {
    let candidate: CleanupCandidate
    @Binding var isSelected: Bool

    var body: some View {
        Toggle(isOn: $isSelected) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: candidate.kind.symbolName)
                    .frame(width: 18)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(candidate.displayName)
                            .font(.callout.weight(.medium))
                            .lineLimit(1)

                        if candidate.defaultSelected {
                            Text("Recommended")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.tertiary.opacity(0.5), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                        }
                    }

                    Text("\(candidate.kind.title) - \(candidate.reason)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text(candidate.path)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }

                Spacer(minLength: 12)

                Text(candidate.byteCountLabel)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
        }
        .toggleStyle(.checkbox)
    }
}
