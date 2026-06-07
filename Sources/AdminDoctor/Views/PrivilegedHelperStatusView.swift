import AdminDoctorCore
import SwiftUI

struct PrivilegedHelperStatusView: View {
    let status: PrivilegedHelperStatus
    let isManaging: Bool
    let message: String?
    let refresh: () -> Void
    let register: () -> Void
    let unregister: () -> Void
    let ping: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Label(L10n.string("helper.status.title"), systemImage: "lock.shield")
                    .font(.headline)

                HelperStatePill(state: status.state)

                Spacer()

                if isManaging {
                    ProgressView()
                        .controlSize(.small)
                }

                Button {
                    ping()
                } label: {
                    Label(L10n.string("helper.status.ping"), systemImage: "bolt.horizontal.circle")
                }
                .disabled(isManaging || status.serviceManagementStatus != "Enabled")

                Button {
                    register()
                } label: {
                    Label(L10n.string("helper.status.register"), systemImage: "checkmark.shield")
                }
                .disabled(isManaging)

                Button(role: .destructive) {
                    unregister()
                } label: {
                    Label(L10n.string("helper.status.unregister"), systemImage: "xmark.shield")
                }
                .disabled(isManaging)

                Button {
                    refresh()
                } label: {
                    Label(L10n.string("helper.status.refresh"), systemImage: "arrow.clockwise")
                }
                .disabled(isManaging)
            }

            Text(L10n.string("helper.status.description"))
                .font(.callout)
                .foregroundStyle(.secondary)

            if let message, !message.isEmpty {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(message.localizedCaseInsensitiveContains("error") ? .orange : .secondary)
                    .textSelection(.enabled)
            }

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 6) {
                HelperStatusRow(
                    title: L10n.string("helper.status.serviceManagement"),
                    value: status.serviceManagementStatus ?? L10n.string("helper.status.unknown")
                )
                HelperStatusRow(
                    title: L10n.string("helper.status.bundled"),
                    value: status.bundledToolPresent ? L10n.string("helper.status.present") : L10n.string("helper.status.missing")
                )
                HelperStatusRow(
                    title: L10n.string("helper.status.installedTool"),
                    value: status.installedToolPresent ? status.installedToolPath : L10n.string("helper.status.notInstalled")
                )
                HelperStatusRow(
                    title: L10n.string("helper.status.launchDaemon"),
                    value: status.launchDaemonPresent ? status.launchDaemonPath : L10n.string("helper.status.notInstalled")
                )
                HelperStatusRow(
                    title: L10n.string("helper.status.codeSignature"),
                    value: signatureText
                )
                HelperStatusRow(
                    title: L10n.string("helper.status.xpc"),
                    value: status.xpcVersion ?? L10n.string("helper.status.notConnected")
                )
                HelperStatusRow(
                    title: L10n.string("helper.status.label"),
                    value: status.label
                )
            }
        }
        .padding(14)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var signatureText: String {
        switch status.codeSignatureVerified {
        case .some(true):
            return L10n.string("helper.status.signatureVerified")
        case .some(false):
            return L10n.string("helper.status.signatureFailed")
        case .none:
            return L10n.string("helper.status.notInstalled")
        }
    }
}

private struct HelperStatusRow: View {
    let title: String
    let value: String

    var body: some View {
        GridRow {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospaced())
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
    }
}

private struct HelperStatePill: View {
    let state: PrivilegedHelperInstallState

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.tertiary.opacity(0.45), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var title: String {
        switch state {
        case .notBundled:
            return L10n.string("helper.status.state.notBundled")
        case .bundledOnly:
            return L10n.string("helper.status.state.bundledOnly")
        case .requiresApproval:
            return L10n.string("helper.status.state.requiresApproval")
        case .registered:
            return L10n.string("helper.status.state.registered")
        case .installed:
            return L10n.string("helper.status.state.installed")
        }
    }

    private var color: Color {
        switch state {
        case .notBundled:
            return .orange
        case .bundledOnly:
            return .blue
        case .requiresApproval:
            return .yellow
        case .registered:
            return .green
        case .installed:
            return .green
        }
    }
}
