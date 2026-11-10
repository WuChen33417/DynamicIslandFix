import XCTest
@testable import DynamicIslandCore

final class IslandConfigurationTests: XCTestCase {
    func config() throws -> IslandConfiguration {
        try IslandConfiguration(width: "1170", height: "2532", subtype: "2532")
    }
    func fixture() throws -> (Data, Data) {
        (try IslandConfiguration.encode(["CacheData": Data([1, 2]), "CacheExtra": [
            "unrelated": "keep", "oPeik/9e8lQWMszEjbPzng": ["ArtworkDeviceSubType": 2556, "other": true]
        ]]), try IslandConfiguration.encode(["other": "keep"]))
    }
    func testRejectsMalformedAndOutOfBoundsParameters() {
        for value in ["", "0", "-1", "+1", "1.5", " 1170", "１２", "999999999999999999999999"] {
            XCTAssertThrowsError(try IslandConfiguration(width: value, height: "2532", subtype: "2532"))
        }
        XCTAssertThrowsError(try IslandConfiguration(width: "2532", height: "1170", subtype: "2532"))
        XCTAssertThrowsError(try IslandConfiguration(width: "1170", height: "2532", subtype: "65536"))
    }
    func testPatchPreservesUnrelatedFields() throws {
        let (mg, res) = try fixture()
        let pair = try config().patched(gestalt: mg, resolution: res)
        let root = try IslandConfiguration.dictionary(pair.0)
        let extra = try XCTUnwrap(root["CacheExtra"] as? [String: Any])
        let art = try XCTUnwrap(extra["oPeik/9e8lQWMszEjbPzng"] as? [String: Any])
        XCTAssertEqual(art["ArtworkDeviceSubType"] as? Int, 2532)
        XCTAssertEqual(extra["unrelated"] as? String, "keep")
        XCTAssertNil(extra["YlEtTtHlNesRBMal1CqRaA"])
        XCTAssertEqual(root["CacheData"] as? Data, Data([1, 2]))
        XCTAssertEqual(art["other"] as? Bool, true)
        let resolution = try IslandConfiguration.dictionary(pair.1)
        XCTAssertEqual(resolution["canvas_width"] as? Int, 1170)
        XCTAssertEqual(resolution["canvas_height"] as? Int, 2532)
        XCTAssertEqual(resolution["other"] as? String, "keep")
    }
    func testRejectsUnknownStructureAndBooleanInteger() throws {
        let (_, res) = try fixture()
        for value in [true, 2532.5, "2532"] as [Any] {
            let mg = try IslandConfiguration.encode(["CacheExtra": ["oPeik/9e8lQWMszEjbPzng": ["ArtworkDeviceSubType": value]]])
            XCTAssertThrowsError(try config().patched(gestalt: mg, resolution: res))
        }
        XCTAssertThrowsError(try config().patched(gestalt: Data("invalid".utf8), resolution: res))
        XCTAssertThrowsError(try config().patched(gestalt: IslandConfiguration.encode([:]), resolution: res))
    }
    func testDecodedConfigCannotBypassValidation() throws {
        let invalid = try JSONDecoder().decode(IslandConfiguration.self, from: Data(#"{"width":0,"height":2532,"subtype":2532}"#.utf8))
        let (mg, res) = try fixture()
        XCTAssertThrowsError(try invalid.patched(gestalt: mg, resolution: res))
    }
    func testBackupFailurePreventsWrites() {
        let original = [Data([1]), Data([2])]
        var writes = 0
        XCTAssertThrowsError(try IslandTransaction.perform(original: original, proposed: original,
            backup: { _ in throw IslandError.invalid("disk full") }, read: { original[$0] }, write: { _, _ in writes += 1 }))
        XCTAssertEqual(writes, 0)
    }
    func testSecondFileFailureRollsBackBoth() {
        let original = [Data([1]), Data([2])], proposed = [Data([3]), Data([4])]
        var disk = original
        var saved = false
        XCTAssertThrowsError(try IslandTransaction.perform(original: original, proposed: proposed,
            backup: { XCTAssertEqual($0, original); saved = true }, read: { disk[$0] }, write: { i, data in
                XCTAssertTrue(saved)
                disk[i] = data // Simulate a partial write that fails after mutation.
                if i == 1 && data == proposed[1] { throw IslandError.invalid("I/O") }
            }))
        XCTAssertEqual(disk, original)
    }
    func testRestoreIsInverseTransaction() throws {
        let original = [Data([1]), Data([2])], proposed = [Data([3]), Data([4])]
        var disk = original
        try IslandTransaction.perform(original: original, proposed: proposed, backup: { _ in }, read: { disk[$0] }, write: { disk[$0] = $1 })
        XCTAssertEqual(disk, proposed)
        try IslandTransaction.perform(original: proposed, proposed: original, backup: { _ in }, read: { disk[$0] }, write: { disk[$0] = $1 })
        XCTAssertEqual(disk, original)
    }
    func testConflictRefusesToWrite() {
        var writes = 0
        XCTAssertThrowsError(try IslandTransaction.perform(original: [Data([1]), Data([2])], proposed: [Data(), Data()],
            backup: { _ in XCTFail("Should not back up stale input") }, read: { _ in Data([9]) }, write: { _, _ in writes += 1 }))
        XCTAssertEqual(writes, 0)
    }
    func testReadbackFailureAndRollbackFailureAreReported() {
        let original = [Data([1]), Data([2])]
        var reads = 0
        XCTAssertThrowsError(try IslandTransaction.perform(original: original, proposed: [Data([3]), Data([4])],
            backup: { _ in }, read: { i in reads += 1; return reads <= 4 ? original[i] : Data([9]) },
            write: { _, _ in })) { error in
                XCTAssertTrue(error.localizedDescription.contains("严重错误"))
            }
    }
}
