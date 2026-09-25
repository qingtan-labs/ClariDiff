import XCTest
@testable import ClariDiffCore

final class SemanticDiffEngineTests: XCTestCase {
    private let parser = JSONParser()

    func testObjectOrderDoesNotMatter() throws {
        let left = try parser.parse(#"{"name":"Tom","age":20}"#)
        let right = try parser.parse(#"{"age":20,"name":"Tom"}"#)

        let result = try SemanticDiffEngine().compare(left, right)

        XCTAssertEqual(result.status, .unchanged)
        XCTAssertEqual(result.summary.total, 0)
    }

    func testIgnorePathAndUnorderedArrayLeavesOnlyAgeChange() throws {
        let left = try parser.parse(#"{"name":"Alice","age":20,"updatedAt":"2026-09-20","roles":["user","admin"]}"#)
        let right = try parser.parse(#"{"roles":["admin","user"],"age":21,"name":"Alice","updatedAt":"2026-09-25"}"#)
        let options = DiffOptions(
            ignorePaths: ["/updatedAt"],
            arrayRules: ["/roles": .unordered]
        )

        let result = try SemanticDiffEngine(options: options).compare(left, right)

        XCTAssertEqual(result.summary.modified, 1)
        XCTAssertEqual(result.leafChanges.map(\.path), ["/age"])
    }

    func testKeyedArrayMatchesObjectsAcrossReordering() throws {
        let left = try parser.parse(#"[{"id":1,"name":"Alice"},{"id":2,"name":"Bob"}]"#)
        let right = try parser.parse(#"[{"id":2,"name":"Bobby"},{"id":1,"name":"Alice"}]"#)
        let options = DiffOptions(arrayRules: ["": .keyed("id")])

        let result = try SemanticDiffEngine(options: options).compare(left, right)

        XCTAssertEqual(result.summary.modified, 1)
        XCTAssertEqual(result.leafChanges.first?.name, "name")
    }

    func testNumberToleranceSupportsAbsoluteAndRelative() throws {
        let left = try parser.parse(#"{"small":1.0001,"large":1000}"#)
        let right = try parser.parse(#"{"small":1,"large":1001}"#)
        let options = DiffOptions(numberTolerance: .init(absolute: 0.001, relativePercent: 0.1))

        let result = try SemanticDiffEngine(options: options).compare(left, right)

        XCTAssertEqual(result.summary.total, 0)
    }

    func testTypeChangeIsReported() throws {
        let result = try SemanticDiffEngine().compare(
            try parser.parse(#"{"value":1}"#),
            try parser.parse(#"{"value":"1"}"#)
        )

        XCTAssertEqual(result.summary.typeChanged, 1)
    }

    func testWildcardIgnorePath() throws {
        let left = try parser.parse(#"{"items":[{"traceId":"a","value":1},{"traceId":"b","value":2}]}"#)
        let right = try parser.parse(#"{"items":[{"traceId":"x","value":1},{"traceId":"y","value":2}]}"#)
        let options = DiffOptions(ignorePaths: ["/items/*/traceId"])

        let result = try SemanticDiffEngine(options: options).compare(left, right)

        XCTAssertEqual(result.summary.total, 0)
    }

    func testIgnoredPathIsSuppressedWhenPresentOnOnlyOneSide() throws {
        let left = try parser.parse(#"{"name":"Alice"}"#)
        let right = try parser.parse(#"{"name":"Alice","requestId":"dynamic"}"#)
        let options = DiffOptions(ignorePaths: ["/requestId"])

        let result = try SemanticDiffEngine(options: options).compare(left, right)

        XCTAssertEqual(result.summary.total, 0)
    }

    func testLargeIntegerIDsDoNotLosePrecision() throws {
        let left = try parser.parse(#"{"id":9007199254740992}"#)
        let right = try parser.parse(#"{"id":9007199254740993}"#)

        let result = try SemanticDiffEngine().compare(left, right)

        XCTAssertEqual(result.summary.modified, 1)
        XCTAssertEqual(result.leafChanges.first?.path, "/id")
    }

    func testUnorderedArrayRespectsNestedIgnoreRules() throws {
        let left = try parser.parse(#"{"items":[{"id":1,"traceId":"a"},{"id":2,"traceId":"b"}]}"#)
        let right = try parser.parse(#"{"items":[{"id":2,"traceId":"y"},{"id":1,"traceId":"x"}]}"#)
        let options = DiffOptions(
            ignorePaths: ["/items/*/traceId"],
            arrayRules: ["/items": .unordered]
        )

        let result = try SemanticDiffEngine(options: options).compare(left, right)

        XCTAssertEqual(result.summary.total, 0)
    }

    func testStringNormalization() throws {
        let options = DiffOptions(strings: .init(
            trimWhitespace: true,
            ignoreCase: true,
            coerceNumericStrings: true
        ))
        let left = try parser.parse(#"{"name":" Alice\r\n","score":"1.0"}"#)
        let right = try parser.parse(#"{"name":"alice","score":1}"#)

        XCTAssertEqual(try SemanticDiffEngine(options: options).compare(left, right).summary.total, 0)
    }

    func testInvalidKeyedArrayFailsInsteadOfSilentlyFallingBack() throws {
        let left = try parser.parse(#"[{"id":1},{"name":"missing id"}]"#)
        let right = try parser.parse(#"[{"id":1},{"id":2}]"#)
        let options = DiffOptions(arrayRules: ["": .keyed("id")])

        XCTAssertThrowsError(try SemanticDiffEngine(options: options).compare(left, right)) { error in
            XCTAssertEqual(
                error as? SemanticDiffError,
                .invalidArrayKey(path: "", key: "id")
            )
        }
    }
}
