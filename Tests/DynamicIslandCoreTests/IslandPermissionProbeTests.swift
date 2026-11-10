import XCTest
@testable import DynamicIslandCore

final class IslandPermissionProbeTests: XCTestCase {
    func testBoundedPlanUsesOnlyResolutionAliasesAndTwoKnownFlags() {
        XCTAssertEqual(IslandPermissionProbe.routes.count, 8)
        for directory in IslandPermissionProbe.directories {
            let subset = IslandPermissionProbe.routes.filter { $0.file == directory + "/" + IslandPermissionProbe.filename }
            XCTAssertEqual(subset.count, 4)
            XCTAssertEqual(subset.filter(\.alternativeFlags).count, 2)
            XCTAssertTrue(subset.allSatisfy { $0.target == directory || $0.target == $0.file })
        }
    }
    func testDirectSuccessNeedsNoQuery() {
        let result = IslandPermissionProbe.run(read: { _ in }, acquire: { _ in XCTFail("Unneeded token request"); return -6 }, release: { _ in XCTFail("No token") })
        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result[0].readable)
    }
    func testTokenWithoutSuccessfulReadDoesNotCountAsPermission() {
        var released: [Int64] = []
        let result = IslandPermissionProbe.run(read: { _ in throw IslandError.invalid("open denied") }, acquire: { _ in 42 }, release: { released.append($0) })
        XCTAssertEqual(result.count, 9)
        XCTAssertFalse(result.contains { $0.readable })
        XCTAssertEqual(released, Array(repeating: 42, count: 8))
    }
    func testStopsAfterReadableRouteAndReleasesItsToken() {
        var reads = 0, queries = 0
        var released: [Int64] = []
        let result = IslandPermissionProbe.run(read: { _ in
            reads += 1
            if reads == 1 { throw IslandError.invalid("initial denial") }
        }, acquire: { _ in queries += 1; return 7 }, release: { released.append($0) })
        XCTAssertEqual(queries, 1)
        XCTAssertEqual(released, [7])
        XCTAssertTrue(result.last!.readable)
    }
    func testLocalGuardFailureStopsFurtherRequests() {
        var queries = 0
        let result = IslandPermissionProbe.run(read: { _ in throw IslandError.invalid("denied") }, acquire: { _ in
            queries += 1; throw IslandError.invalid("cache conflict")
        }, release: { _ in XCTFail("No acquired token") })
        XCTAssertEqual(queries, 1)
        XCTAssertEqual(result.count, 2)
    }
    private func fixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Caches/nested"), withIntermediateDirectories: true)
        try Data([1, 2, 3]).write(to: root.appendingPathComponent("Caches/nested/keep"))
        return root
    }
    func testPreservesOriginalCacheContentsAfterLinkSwapAndAfterError() throws {
        let fm = FileManager.default, root = try fixture()
        defer { try? fm.removeItem(at: root) }
        let cache = root.appendingPathComponent("Caches")
        try IslandProbeCacheGuard.run(cache: cache, target: "/not-accessed") {
            try fm.createSymbolicLink(atPath: cache.path, withDestinationPath: "/not-accessed")
        }
        XCTAssertEqual(try Data(contentsOf: cache.appendingPathComponent("nested/keep")), Data([1, 2, 3]))
        XCTAssertThrowsError(try IslandProbeCacheGuard.run(cache: cache, target: "/not-accessed") {
            throw IslandError.invalid("query failed")
        })
        XCTAssertEqual(try Data(contentsOf: cache.appendingPathComponent("nested/keep")), Data([1, 2, 3]))
    }
    func testUnexpectedNewCacheFilesAreNotDeletedAndOriginalRemainsPreserved() throws {
        let fm = FileManager.default, root = try fixture()
        defer { try? fm.removeItem(at: root) }
        let cache = root.appendingPathComponent("Caches")
        XCTAssertThrowsError(try IslandProbeCacheGuard.run(cache: cache, target: "/not-accessed") {
            try fm.createDirectory(at: cache, withIntermediateDirectories: false)
            try Data([9]).write(to: cache.appendingPathComponent("concurrent"))
        })
        XCTAssertEqual(try Data(contentsOf: cache.appendingPathComponent("concurrent")), Data([9]))
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent(".DynamicIslandFix-PreservedCaches/nested/keep")), Data([1, 2, 3]))
        XCTAssertThrowsError(try IslandProbeCacheGuard.run(cache: cache, target: "/not-accessed", action: { XCTFail("Must stop on recovery conflict") }))
    }
}
