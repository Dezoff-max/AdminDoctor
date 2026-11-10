import XCTest
@testable import AdminDoctorCore

final class OUIVendorDatabaseTests: XCTestCase {
    func testPrefersResourceBundleInsideMainBundleResources() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AdminDoctorOUITests-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        let packaged = root.appendingPathComponent(OUIVendorDatabase.resourceBundleName, isDirectory: true)
        try FileManager.default.createDirectory(at: packaged, withIntermediateDirectories: true)
        try Data("Registry,Assignment,Organization Name\n".utf8).write(to: packaged.appendingPathComponent("oui.csv"))
        let mainBundle = try XCTUnwrap(Bundle(url: root))

        let bundle = OUIVendorDatabase.resourceBundle(mainBundle: mainBundle)

        XCTAssertEqual(
            bundle.bundleURL.resolvingSymlinksInPath().path,
            packaged.resolvingSymlinksInPath().path
        )
        XCTAssertNotNil(bundle.url(forResource: "oui", withExtension: "csv"))
    }

    func testFallsBackToModuleBundleAndFindsBundledData() {
        let bundle = OUIVendorDatabase.resourceBundle(mainBundle: Bundle(for: OUIVendorDatabaseTests.self))

        for resource in ["oui", "mam", "oui36"] {
            XCTAssertNotNil(bundle.url(forResource: resource, withExtension: "csv"), resource)
        }
    }
}
