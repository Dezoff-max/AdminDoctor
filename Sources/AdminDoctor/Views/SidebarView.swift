import AdminDoctorCore
import SwiftUI

struct SidebarView: View {
    @Binding var selectedCategoryRaw: String
    @ObservedObject var store: DiagnosticStore
    @AppStorage(L10n.languagePreferenceKey) private var languageRaw = AppLanguage.systemDefault.rawValue

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selectedCategoryRaw) {
                Section(L10n.string("diagnostics.section")) {
                    ForEach(DiagnosticCategory.allCases) { category in
                        SidebarCategoryRow(
                            category: category,
                            summary: store.summary(for: category)
                        )
                        .tag(category.rawValue)
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            SidebarHistoryView(history: store.scanHistory)

            Divider()

            HStack(spacing: 8) {
                Image(systemName: "globe")
                    .foregroundStyle(.secondary)

                Picker(L10n.string("language.switcher"), selection: $languageRaw) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.shortTitle)
                            .tag(language.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .navigationTitle("AdminDoctor")
    }
}

private struct SidebarCategoryRow: View {
    let category: DiagnosticCategory
    let summary: CategorySummary

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: category.symbolName)
                .frame(width: 18)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(category.localizedTitle)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 3)
    }

    private var subtitle: String {
        let total = summary.passCount + summary.warningCount + summary.failCount + summary.infoCount
        guard total > 0 else {
            return L10n.string("diagnostics.notRun")
        }
        return L10n.format("diagnostics.sidebarSummary", summary.failCount, summary.warningCount, summary.passCount)
    }
}

private struct SidebarHistoryView: View {
    let history: [ScanHistoryEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label(L10n.string("history.title"), systemImage: "clock.arrow.circlepath")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if history.isEmpty {
                Text(L10n.string("history.empty"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            } else {
                ForEach(history.prefix(3)) { entry in
                    HStack(spacing: 8) {
                        Text(entry.startedAt.localizedShortTimeString())
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 42, alignment: .leading)

                        HStack(spacing: 4) {
                            SeverityDot(color: .red, count: entry.failCount)
                            SeverityDot(color: .yellow, count: entry.warningCount)
                            SeverityDot(color: .green, count: entry.passCount)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .help(entryTooltip(entry))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func entryTooltip(_ entry: ScanHistoryEntry) -> String {
        let warning = entry.topWarningTitles.first.map { "\n\($0)" } ?? ""
        return L10n.format("history.tooltip", entry.failCount, entry.warningCount, entry.passCount, entry.infoCount) + warning
    }
}

private struct SeverityDot: View {
    let color: Color
    let count: Int

    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("\(count)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}
