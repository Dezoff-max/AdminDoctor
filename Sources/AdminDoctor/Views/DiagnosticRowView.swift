import AdminDoctorCore
import SwiftUI

struct DiagnosticRowView: View {
    let result: DiagnosticResult
    @State private var expanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 10) {
                if !result.details.isEmpty {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 7) {
                        ForEach(Array(result.details.enumerated()), id: \.offset) { _, detail in
                            GridRow {
                                Text(detail.key)
                                    .foregroundStyle(.secondary)
                                Text(detail.value)
                                    .textSelection(.enabled)
                                    .lineLimit(4)
                            }
                        }
                    }
                    .font(.callout)
                }

                if let remediation = result.remediation {
                    Text(remediation)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                Text(result.source)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }
            .padding(.top, 8)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                SeverityBadge(severity: result.severity)
                VStack(alignment: .leading, spacing: 3) {
                    Text(result.title)
                        .font(.headline)
                    Text(result.summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            .padding(.vertical, 7)
        }
    }
}

private struct SeverityBadge: View {
    let severity: DiagnosticSeverity

    var body: some View {
        Text(severity.localizedTitle)
            .font(.caption.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .frame(minWidth: 58)
            .background(background, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var foreground: Color {
        switch severity {
        case .pass:
            return .green
        case .warning:
            return .orange
        case .fail:
            return .red
        case .info:
            return .blue
        }
    }

    private var background: Color {
        foreground.opacity(0.12)
    }
}
