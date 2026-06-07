import AdminDoctorCore
import SwiftUI

struct LocalNetworkScanView: View {
    let snapshot: LocalNetworkScanSnapshot?
    let isScanning: Bool
    let error: String?
    let scan: () -> Void
    let clear: () -> Void

    @State private var rangeText = ""
    @State private var filterText = ""

    private var effectiveRangeText: String {
        if !rangeText.isEmpty {
            return rangeText
        }
        return snapshot?.scanRangeDescription ?? L10n.string("network.local.rangePlaceholder")
    }

    private var canClear: Bool {
        snapshot != nil || error != nil || !rangeText.isEmpty || !filterText.isEmpty
    }

    private var filteredDevices: [LocalNetworkDevice] {
        guard let snapshot else {
            return []
        }

        let query = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return snapshot.devices
        }

        return snapshot.devices.filter { device in
            [
                title(for: device, gateway: snapshot.gateway),
                device.ipAddress,
                device.macAddress,
                vendorText(for: device),
                device.vendorName,
                device.hostname,
                device.interfaceName
            ]
            .compactMap { $0?.localizedCaseInsensitiveContains(query) }
            .contains(true)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Button {
                    scan()
                } label: {
                    Label(
                        isScanning ? L10n.string("network.local.scanning") : L10n.string("network.local.scan"),
                        systemImage: isScanning ? "pause.fill" : "play.fill"
                    )
                    .labelStyle(.titleAndIcon)
                    .font(.headline)
                    .frame(minWidth: 136, alignment: .leading)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.green)
                .disabled(isScanning)

                Button {
                    rangeText = ""
                    filterText = ""
                    clear()
                } label: {
                    Label(L10n.string("network.local.clear"), systemImage: "xmark.circle")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(isScanning || !canClear)

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.string("network.local.range"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("", text: $rangeText)
                        .textFieldStyle(.roundedBorder)
                        .font(.callout.monospaced())
                        .frame(minWidth: 220)
                        .overlay(alignment: .trailing) {
                            if rangeText.isEmpty, snapshot != nil {
                                Text(effectiveRangeText)
                                    .font(.callout.monospaced())
                                    .foregroundStyle(.secondary)
                                    .padding(.trailing, 8)
                                    .allowsHitTesting(false)
                            }
                        }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.string("network.local.filter"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField(L10n.string("network.local.filterPlaceholder"), text: $filterText)
                            .textFieldStyle(.plain)
                        if !filterText.isEmpty {
                            Button {
                                filterText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(.background, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(.separator.opacity(0.65), lineWidth: 1)
                    }
                    .frame(minWidth: 180)
                }

                Spacer()
            }

            if isScanning {
                MagicScanStatus()
            } else if let error {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            } else if let snapshot {
                LocalNetworkSnapshotView(
                    snapshot: snapshot,
                    devices: filteredDevices,
                    filterText: filterText
                )
            } else {
                Text(L10n.string("network.local.description"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct MagicScanStatus: View {
    @State private var tilt = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "wand.and.stars")
                    .font(.title3)
                    .foregroundStyle(.blue)
                    .rotationEffect(.degrees(tilt ? 12 : -8))
                    .animation(.easeInOut(duration: 0.65).repeatForever(autoreverses: true), value: tilt)

                Text(L10n.string("network.local.discovering"))
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Spacer()

                ProgressView()
                    .controlSize(.small)
            }

            MagicSweepBar()
        }
        .onAppear {
            tilt = true
        }
    }
}

private struct MagicSweepBar: View {
    @State private var sweep = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(.secondary.opacity(0.14))

                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.clear, .blue.opacity(0.65), .purple.opacity(0.5), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(56, proxy.size.width * 0.32))
                    .offset(x: sweep ? proxy.size.width : -proxy.size.width * 0.36)
            }
        }
        .frame(height: 6)
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        .onAppear {
            sweep = false
            withAnimation(.linear(duration: 1.15).repeatForever(autoreverses: false)) {
                sweep = true
            }
        }
    }
}

private struct LocalNetworkSnapshotView: View {
    let snapshot: LocalNetworkScanSnapshot
    let devices: [LocalNetworkDevice]
    let filterText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(L10n.format("network.local.summary", snapshot.devices.count, snapshot.scannedHostCount))
                    .font(.callout.weight(.medium))
                Text(L10n.format("network.local.lastScan", snapshot.scannedAt.localizedShortTimeString()))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                MetadataPill(title: L10n.string("network.local.interface"), value: snapshot.interfaceName)
                MetadataPill(title: L10n.string("network.local.localAddress"), value: snapshot.localAddress)
                if let gateway = snapshot.gateway {
                    MetadataPill(title: L10n.string("network.local.gateway"), value: gateway)
                }
            }

            if snapshot.cappedToLocalSlash24 {
                Text(L10n.string("network.local.capped"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            DeviceResultsTable(
                devices: devices,
                gateway: snapshot.gateway,
                emptyText: emptyText
            )
        }
    }

    private var emptyText: String {
        let query = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            return L10n.string("network.local.filterEmpty")
        }
        return L10n.string("network.local.empty")
    }
}

private struct DeviceResultsTable: View {
    let devices: [LocalNetworkDevice]
    let gateway: String?
    let emptyText: String

    private let columns = [
        GridItem(.fixed(70), spacing: 0, alignment: .leading),
        GridItem(.flexible(minimum: 150), spacing: 0, alignment: .leading),
        GridItem(.fixed(130), spacing: 0, alignment: .leading),
        GridItem(.flexible(minimum: 140), spacing: 0, alignment: .leading),
        GridItem(.fixed(150), spacing: 0, alignment: .leading)
    ]

    var body: some View {
        VStack(spacing: 0) {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 0) {
                HeaderCell(L10n.string("network.local.columnStatus"))
                HeaderCell(L10n.string("network.local.columnName"))
                HeaderCell("IP")
                HeaderCell(L10n.string("network.local.columnVendor"))
                HeaderCell(L10n.string("network.local.columnMac"))
            }
            .background(.background.opacity(0.72))

            Divider()

            if devices.isEmpty {
                Text(emptyText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(devices) { device in
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 0) {
                            StatusCell(device: device, gateway: gateway)
                            Text(title(for: device, gateway: gateway))
                                .font(.callout.weight(.medium))
                                .lineLimit(1)
                                .textSelection(.enabled)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 8)
                            Text(device.ipAddress)
                                .font(.callout.monospaced())
                                .lineLimit(1)
                                .textSelection(.enabled)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 8)
                            Text(vendorText(for: device))
                                .font(.callout)
                                .foregroundStyle(device.vendorName == nil ? .secondary : .primary)
                                .lineLimit(1)
                                .textSelection(.enabled)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 8)
                            Text(device.macAddress ?? L10n.string("network.local.noMac"))
                                .font(.callout.monospaced())
                                .lineLimit(1)
                                .textSelection(.enabled)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 8)
                        }
                        .background(rowBackground(for: device))

                        if device.id != devices.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(.separator.opacity(0.9), lineWidth: 1)
        }
    }

    private func rowBackground(for device: LocalNetworkDevice) -> Color {
        device.ipAddress == gateway ? Color.blue.opacity(0.08) : Color.clear
    }
}

private struct HeaderCell: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
    }
}

private struct StatusCell: View {
    let device: LocalNetworkDevice
    let gateway: String?

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(.green)
                .frame(width: 8, height: 8)
            Image(systemName: iconName)
                .foregroundStyle(.secondary)
        }
        .help(L10n.string("network.local.online"))
        .lineLimit(1)
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    private var iconName: String {
        if device.ipAddress == gateway {
            return "wifi.router"
        }
        if device.hostname != nil {
            return "desktopcomputer"
        }
        return "network"
    }
}

private struct MetadataPill: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 5) {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .fontWeight(.medium)
                .textSelection(.enabled)
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.tertiary.opacity(0.45), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

private func title(for device: LocalNetworkDevice, gateway: String?) -> String {
    if device.ipAddress == gateway {
        return L10n.string("network.local.defaultGateway")
    }

    return device.hostname
        ?? device.vendorName
        ?? L10n.format("network.local.deviceFallback", lastAddressSegment(device.ipAddress))
}

private func vendorText(for device: LocalNetworkDevice) -> String {
    if let macAddress = device.macAddress, MACAddressClassifier.isLocallyAdministered(macAddress) {
        return L10n.string("network.local.privateVendor")
    }

    return device.vendorName ?? L10n.string("network.local.unknownVendor")
}

private func lastAddressSegment(_ ipAddress: String) -> String {
    ipAddress.split(separator: ".").last.map { ".\(String($0))" } ?? ipAddress
}
