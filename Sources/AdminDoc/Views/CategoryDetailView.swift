import AdminDocCore
import SwiftUI

struct CategoryDetailView: View {
    let category: DiagnosticCategory
    let results: [DiagnosticResult]
    let isRunning: Bool
    let lastRunDate: Date?
    let totalSummary: (fail: Int, warning: Int, pass: Int, info: Int)

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(
                category: category,
                isRunning: isRunning,
                lastRunDate: lastRunDate,
                totalSummary: totalSummary
            )

            Divider()

            if results.isEmpty {
                EmptyCategoryView(isRunning: isRunning)
            } else {
                List {
                    ForEach(results) { result in
                        DiagnosticRowView(result: result)
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle(category.title)
    }
}

private struct HeaderView: View {
    let category: DiagnosticCategory
    let isRunning: Bool
    let lastRunDate: Date?
    let totalSummary: (fail: Int, warning: Int, pass: Int, info: Int)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Label(category.title, systemImage: category.symbolName)
                    .font(.title2.weight(.semibold))
                Spacer()
                Text(statusText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                SeverityCountPill(title: "Fail", count: totalSummary.fail, severity: .fail)
                SeverityCountPill(title: "Warning", count: totalSummary.warning, severity: .warning)
                SeverityCountPill(title: "Pass", count: totalSummary.pass, severity: .pass)
                SeverityCountPill(title: "Info", count: totalSummary.info, severity: .info)
                Spacer()
            }
        }
        .padding(20)
    }

    private var statusText: String {
        if isRunning {
            return "Running local checks..."
        }

        guard let lastRunDate else {
            return "Not run"
        }

        return "Last run \(lastRunDate.formatted(date: .abbreviated, time: .shortened))"
    }
}

private struct EmptyCategoryView: View {
    let isRunning: Bool

    var body: some View {
        VStack(spacing: 10) {
            if isRunning {
                ProgressView()
                    .controlSize(.small)
                Text("Collecting diagnostics")
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "checklist")
                    .font(.system(size: 30))
                    .foregroundStyle(.secondary)
                Text("No findings yet")
                    .font(.headline)
                Text("Run diagnostics to populate this category.")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SeverityCountPill: View {
    let title: String
    let count: Int
    let severity: DiagnosticSeverity

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(severityColor)
                .frame(width: 7, height: 7)
            Text("\(count)")
                .font(.callout.monospacedDigit().weight(.semibold))
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var severityColor: Color {
        switch severity {
        case .pass:
            return .green
        case .warning:
            return .yellow
        case .fail:
            return .red
        case .info:
            return .blue
        }
    }
}
