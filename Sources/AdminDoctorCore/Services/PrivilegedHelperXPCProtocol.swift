import Foundation

@objc public protocol AdminDoctorPrivilegedHelperXPC {
    func helperVersion(withReply reply: @escaping (String) -> Void)
    func scanSystemCleanup(withReply reply: @escaping (Data?, String?) -> Void)
    func planSystemCleanup(paths: [String], withReply reply: @escaping (Data?, String?) -> Void)
    func quarantineSystemCleanup(paths: [String], withReply reply: @escaping (Data?, String?) -> Void)
}

public enum PrivilegedHelperXPCContract {
    public static let machServiceName = PrivilegedHelperStatusService.helperLabel
}
