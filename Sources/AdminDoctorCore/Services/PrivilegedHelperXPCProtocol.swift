import Foundation

@objc public protocol AdminDoctorPrivilegedHelperXPC {
    func helperVersion(withReply reply: @escaping (String) -> Void)
    func scanSystemCleanup(withReply reply: @escaping (Data?, String?) -> Void)
    func planSystemCleanup(paths: [String], withReply reply: @escaping (Data?, String?) -> Void)
    func quarantineSystemCleanup(paths: [String], withReply reply: @escaping (Data?, String?) -> Void)
}

public enum PrivilegedHelperXPCContract {
    public static let machServiceName = PrivilegedHelperStatusService.helperLabel
    public static let clientBundleIdentifier = "dev.admindoctor.AdminDoctor"

    /// Code-signing requirement an XPC client must satisfy before the root helper
    /// accepts its connection: the AdminDoctor app, signed by an Apple-issued
    /// certificate that belongs to the same team as the helper itself.
    ///
    /// Returns nil when the team identifier is missing or malformed (for example an
    /// ad-hoc signed build), in which case the helper must refuse every connection.
    public static func clientCodeSigningRequirement(teamIdentifier: String?) -> String? {
        guard
            let teamIdentifier,
            !teamIdentifier.isEmpty,
            teamIdentifier.count <= 32,
            teamIdentifier.unicodeScalars.allSatisfy({ scalar in
                scalar.isASCII && CharacterSet.alphanumerics.contains(scalar)
            })
        else {
            return nil
        }

        return "anchor apple generic"
            + " and identifier \"\(clientBundleIdentifier)\""
            + " and certificate leaf[subject.OU] = \"\(teamIdentifier)\""
    }
}
