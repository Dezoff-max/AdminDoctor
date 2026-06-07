import Foundation

public enum MACAddressClassifier {
    public static func normalizedHex(_ macAddress: String) -> String? {
        let trimmed = macAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        if trimmed.contains(":") || trimmed.contains("-") {
            let parts = trimmed.split { character in
                character == ":" || character == "-"
            }
            guard parts.count == 6 else {
                return normalizedCompactHex(trimmed)
            }

            var normalized = ""
            for part in parts {
                guard (1...2).contains(part.count), part.allSatisfy(\.isHexDigit) else {
                    return nil
                }

                if part.count == 1 {
                    normalized.append("0")
                }
                normalized.append(contentsOf: part.uppercased())
            }
            return normalized
        }

        return normalizedCompactHex(trimmed)
    }

    public static func isLocallyAdministered(_ macAddress: String) -> Bool {
        guard
            let normalized = normalizedHex(macAddress),
            normalized.count >= 2,
            let firstOctet = UInt8(String(normalized.prefix(2)), radix: 16)
        else {
            return false
        }

        return firstOctet & 0x02 == 0x02
    }

    private static func normalizedCompactHex(_ value: String) -> String? {
        let hex = value.filter(\.isHexDigit).uppercased()
        guard hex.count >= 6 else {
            return nil
        }
        return String(hex.prefix(12))
    }
}

struct OUIVendorDatabase: Sendable {
    static let shared = OUIVendorDatabase.loadBundled()

    private let vendorsByPrefix: [String: String]

    init(vendorsByPrefix: [String: String]) {
        var normalized: [String: String] = [:]
        for (prefix, vendor) in vendorsByPrefix {
            guard
                let normalizedPrefix = Self.normalizedPrefix(prefix),
                !vendor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                continue
            }
            normalized[normalizedPrefix] = vendor.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        self.vendorsByPrefix = normalized
    }

    func vendorName(for macAddress: String) -> String? {
        guard
            let normalized = MACAddressClassifier.normalizedHex(macAddress),
            !MACAddressClassifier.isLocallyAdministered(macAddress)
        else {
            return nil
        }

        for prefixLength in [9, 7, 6] where normalized.count >= prefixLength {
            let prefix = String(normalized.prefix(prefixLength))
            if let vendor = vendorsByPrefix[prefix] {
                return vendor
            }
        }

        return nil
    }

    static func parseAssignmentRows(_ text: String) -> [(prefix: String, vendor: String)] {
        parseAssignmentRows(Data(text.utf8))
    }

    static func parseAssignmentRows(_ data: Data) -> [(prefix: String, vendor: String)] {
        let bytes = [UInt8](data)
        var rows: [(prefix: String, vendor: String)] = []
        var lineStart = 0
        var index = 0

        while index <= bytes.count {
            if index == bytes.count || bytes[index] == 10 || bytes[index] == 13 {
                if let row = parseAssignmentLine(bytes, start: lineStart, end: index) {
                    rows.append(row)
                }

                if index < bytes.count, bytes[index] == 13, index + 1 < bytes.count, bytes[index + 1] == 10 {
                    index += 1
                }
                lineStart = index + 1
            }

            index += 1
        }

        return rows
    }

    private static func loadBundled() -> OUIVendorDatabase {
        var vendors: [String: String] = [:]
        for resourceName in ["oui", "mam", "oui36"] {
            guard
                let url = Bundle.module.url(forResource: resourceName, withExtension: "csv"),
                let data = try? Data(contentsOf: url)
            else {
                continue
            }

            for row in parseAssignmentRows(data) {
                guard let prefix = normalizedPrefix(row.prefix) else {
                    continue
                }

                let vendor = row.vendor.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !vendor.isEmpty else {
                    continue
                }

                vendors[prefix] = vendor
            }
        }

        return OUIVendorDatabase(vendorsByPrefix: vendors)
    }

    private static func parseAssignmentLine(_ bytes: [UInt8], start: Int, end: Int) -> (prefix: String, vendor: String)? {
        guard start < end, !startsWithHeader(bytes, start: start, end: end) else {
            return nil
        }

        var fields: [String] = []
        var field: [UInt8] = []
        var isQuoted = false
        var index = start

        while index < end, fields.count < 3 {
            let byte = bytes[index]

            if byte == 34 {
                let nextIndex = index + 1
                if isQuoted, nextIndex < end, bytes[nextIndex] == 34 {
                    field.append(34)
                    index = nextIndex
                } else {
                    isQuoted.toggle()
                }
            } else if byte == 44 && !isQuoted {
                fields.append(String(decoding: field, as: UTF8.self))
                field.removeAll(keepingCapacity: true)
            } else {
                field.append(byte)
            }

            index += 1
        }

        if fields.count < 3 {
            fields.append(String(decoding: field, as: UTF8.self))
        }

        guard fields.count >= 3 else {
            return nil
        }

        return (fields[1], fields[2])
    }

    private static func startsWithHeader(_ bytes: [UInt8], start: Int, end: Int) -> Bool {
        let header = Array("Registry,".utf8)
        guard end - start >= header.count else {
            return false
        }

        for offset in header.indices where bytes[start + offset] != header[offset] {
            return false
        }
        return true
    }

    private static func normalizedPrefix(_ prefix: String) -> String? {
        let normalized = prefix.filter(\.isHexDigit).uppercased()
        guard [6, 7, 9].contains(normalized.count) else {
            return nil
        }
        return normalized
    }
}
