import AdminDoctorCore
import SwiftUI

struct CleanupReviewView: View {
    let snapshot: CleanupSnapshot?
    @Binding var selectedIDs: Set<UUID>
    let isScanning: Bool
    let isCleaning: Bool
    let error: String?
    let notice: String?
    let failures: [CleanupFailure]
    let scan: () -> Void
    let clean: () -> Void

    @State private var confirmingCleanup = false

    private var candidates: [CleanupCandidate] {
        snapshot?.candidates ?? []
    }

    private var selectedCandidates: [CleanupCandidate] {
        candidates.filter { selectedIDs.contains($0.id) && !$0.requiresPrivilegedHelper }
    }

    private var selectedBytes: Int64 {
        selectedCandidates.reduce(0) { $0 + $1.byteCount }
    }

    private var hasHelperRequiredCandidates: Bool {
        candidates.contains { $0.requiresPrivilegedHelper }
    }

    private var candidateGroups: [CleanupCandidateGroup] {
        Dictionary(grouping: candidates, by: \.groupIdentifier)
            .map { identifier, groupedCandidates in
                CleanupCandidateGroup(
                    id: identifier,
                    title: localizedCleanupGroupTitle(
                        identifier: identifier,
                        fallback: groupedCandidates.first?.groupTitle ?? identifier
                    ),
                    candidates: groupedCandidates.sorted {
                        if $0.defaultSelected != $1.defaultSelected {
                            return $0.defaultSelected && !$1.defaultSelected
                        }
                        if $0.byteCount != $1.byteCount {
                            return $0.byteCount > $1.byteCount
                        }
                        return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                    }
                )
            }
            .sorted {
                if $0.selectableCount == 0, $1.selectableCount > 0 {
                    return false
                }
                if $0.selectableCount > 0, $1.selectableCount == 0 {
                    return true
                }
                if $0.byteCount != $1.byteCount {
                    return $0.byteCount > $1.byteCount
                }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Label(L10n.string("cleanup.storageCleanup"), systemImage: "trash")
                    .font(.headline)

                Spacer()

                if let snapshot {
                    Text(L10n.format("cleanup.candidateCount", candidates.count, snapshot.totalBytesLabel))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Button {
                    scan()
                } label: {
                    Label(L10n.string("cleanup.scan"), systemImage: "magnifyingglass")
                }
                .disabled(isScanning || isCleaning)

                Button(role: .destructive) {
                    confirmingCleanup = true
                } label: {
                    Label(L10n.string("common.moveToTrash"), systemImage: "trash")
                }
                .disabled(selectedCandidates.isEmpty || isScanning || isCleaning)
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

            if !failures.isEmpty {
                CleanupFailuresView(failures: failures)
            }

            if candidates.isEmpty {
                Text(snapshot == nil ? L10n.string("cleanup.empty.notRun") : L10n.string("cleanup.empty.found"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                HStack {
                    Button(L10n.string("cleanup.selectRecommended")) {
                        selectRecommendedCandidates()
                    }
                    .disabled(isScanning || isCleaning)

                    Button(L10n.string("common.clear")) {
                        selectedIDs.removeAll()
                    }
                    .disabled(selectedIDs.isEmpty || isScanning || isCleaning)

                    Spacer()

                    Text(L10n.format("cleanup.selectedSummary", selectedCandidates.count, ByteCountFormatter.string(fromByteCount: selectedBytes, countStyle: .file)))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                if hasHelperRequiredCandidates {
                    HelperRequiredNotice()
                }

                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(candidateGroups) { group in
                        CleanupCandidateGroupSection(
                            group: group,
                            selectedIDs: $selectedIDs,
                            isDisabled: isScanning || isCleaning
                        )

                        if group.id != candidateGroups.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .confirmationDialog(
            L10n.string("cleanup.confirm.title"),
            isPresented: $confirmingCleanup,
            titleVisibility: .visible
        ) {
            Button(L10n.string("common.moveToTrash"), role: .destructive) {
                clean()
            }
            Button(L10n.string("common.cancel"), role: .cancel) {}
        } message: {
            Text(L10n.format("cleanup.confirm.message", selectedCandidates.count, ByteCountFormatter.string(fromByteCount: selectedBytes, countStyle: .file)))
        }
    }

    private func selectRecommendedCandidates() {
        selectedIDs = Set(candidates.filter { $0.defaultSelected && !$0.requiresPrivilegedHelper }.map(\.id))
    }
}

private struct CleanupFailuresView: View {
    let failures: [CleanupFailure]

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(failures.prefix(8), id: \.path) { failure in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayCleanupPath(failure.path))
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                        Text(failure.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                if failures.count > 8 {
                    Text(L10n.format("cleanup.failures.more", failures.count - 8))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 6)
        } label: {
            Label(L10n.format("cleanup.failures.title", failures.count), systemImage: "exclamationmark.triangle")
                .font(.callout.weight(.medium))
                .foregroundStyle(.orange)
        }
    }
}

private struct HelperRequiredNotice: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "lock.shield")
                .foregroundStyle(.secondary)
            Text(L10n.string("cleanup.helper.notice"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.tertiary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

private struct CleanupCandidateGroup: Identifiable {
    let id: String
    let title: String
    let candidates: [CleanupCandidate]

    var byteCount: Int64 {
        candidates.reduce(0) { $0 + $1.byteCount }
    }

    var byteCountLabel: String {
        ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
    }

    var selectableCount: Int {
        candidates.filter { !$0.requiresPrivilegedHelper }.count
    }
}

private struct CleanupCandidateGroupSection: View {
    let group: CleanupCandidateGroup
    @Binding var selectedIDs: Set<UUID>
    let isDisabled: Bool

    private var selectableIDs: Set<UUID> {
        Set(group.candidates.filter { !$0.requiresPrivilegedHelper }.map(\.id))
    }

    private var selectedSelectableCount: Int {
        selectableIDs.filter { selectedIDs.contains($0) }.count
    }

    private var allSelectableSelected: Bool {
        !selectableIDs.isEmpty && selectableIDs.isSubset(of: selectedIDs)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text(group.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Text(L10n.format("cleanup.group.summary", group.candidates.count, group.byteCountLabel))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if group.selectableCount == 0 {
                    CleanupRiskBadge(risk: .requiresHelper)
                } else {
                    Text(L10n.format("cleanup.group.selected", selectedSelectableCount, group.selectableCount))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                Button {
                    selectedIDs = selectedIDs.union(selectableIDs)
                } label: {
                    Label(L10n.string("cleanup.group.select"), systemImage: "checkmark.circle")
                }
                .controlSize(.small)
                .disabled(isDisabled || selectableIDs.isEmpty || allSelectableSelected)

                Button {
                    selectedIDs = selectedIDs.subtracting(Set(group.candidates.map(\.id)))
                } label: {
                    Label(L10n.string("cleanup.group.clear"), systemImage: "xmark.circle")
                }
                .controlSize(.small)
                .disabled(isDisabled || selectedSelectableCount == 0)
            }
            .padding(.vertical, 8)

            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(group.candidates) { candidate in
                    CleanupCandidateRow(
                        candidate: candidate,
                        isSelected: Binding(
                            get: { selectedIDs.contains(candidate.id) && !candidate.requiresPrivilegedHelper },
                            set: { isSelected in
                                if candidate.requiresPrivilegedHelper {
                                    selectedIDs.remove(candidate.id)
                                } else if isSelected {
                                    selectedIDs.insert(candidate.id)
                                } else {
                                    selectedIDs.remove(candidate.id)
                                }
                            }
                        ),
                        isDisabled: isDisabled
                    )

                    if candidate.id != group.candidates.last?.id {
                        Divider()
                            .padding(.leading, 28)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct CleanupCandidateRow: View {
    let candidate: CleanupCandidate
    @Binding var isSelected: Bool
    let isDisabled: Bool

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

                        CleanupRiskBadge(risk: candidate.risk)

                        if candidate.defaultSelected {
                            Text(L10n.string("cleanup.recommended"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.tertiary.opacity(0.5), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                        }
                    }

                    Text("\(candidate.kind.localizedTitle) - \(localizedCleanupReason(candidate.reason))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text(displayCleanupPath(candidate.path))
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
        .disabled(isDisabled || candidate.requiresPrivilegedHelper)
        .help(candidate.requiresPrivilegedHelper ? L10n.string("cleanup.helper.help") : "")
    }
}

private func displayCleanupPath(_ path: String) -> String {
    let homePath = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path

    if path == homePath {
        return "~"
    }

    if path.hasPrefix(homePath + "/") {
        return "~" + path.dropFirst(homePath.count)
    }

    return path
}

private struct CleanupRiskBadge: View {
    let risk: CleanupRisk

    var body: some View {
        Text(risk.localizedTitle)
            .font(.caption.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(background, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }

    private var foreground: Color {
        switch risk {
        case .safe:
            return .green
        case .caution:
            return .orange
        case .manualReview:
            return .blue
        case .requiresHelper:
            return .secondary
        }
    }

    private var background: Color {
        switch risk {
        case .safe:
            return .green.opacity(0.12)
        case .caution:
            return .orange.opacity(0.14)
        case .manualReview:
            return .blue.opacity(0.12)
        case .requiresHelper:
            return .secondary.opacity(0.12)
        }
    }
}
