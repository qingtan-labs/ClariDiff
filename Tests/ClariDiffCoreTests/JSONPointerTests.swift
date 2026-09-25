import XCTest
@testable import ClariDiffCore

final class JSONPointerTests: XCTestCase {
    func testEscapesPointerComponents() {
        let path = JSONPointer.appending("a/b~c", to: "/root")

        XCTAssertEqual(path, "/root/a~1b~0c")
        XCTAssertEqual(JSONPointer.components(of: path), ["root", "a/b~c"])
    }

    func testNormalizesDottedWildcardPath() {
        XCTAssertEqual(JSONPointer.normalizeRule("items[*].traceId"), "/items/*/traceId")
        XCTAssertTrue(JSONPointer.matches(
            path: "/items/12/traceId",
            pattern: "items[*].traceId"
        ))
    }

    func testWildcardMatchesOneSegmentOnly() {
        XCTAssertFalse(JSONPointer.matches(
            path: "/items/nested/12/traceId",
            pattern: "/items/*/traceId"
        ))
    }
}
