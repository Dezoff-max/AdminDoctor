import AdminDocCore
import SwiftUI

struct SidebarView: View {
    @Binding var selectedCategoryRaw: String
    @ObservedObject var store: DiagnosticStore

    var body: some View {
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
        .navigationTitle("AdminDoc")
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
