import XCTest
@testable import ClariDiffCore

final class RuleConfigurationTests: XCTestCase {
    func testParsesDocumentedConfiguration() throws {
        let source = """
        version: 1

        ignore:
          - /updatedAt
          - /items/*/traceId

        arrays:
          /users:
            matchBy: id
            order: ignore
          /tags:
            order: ignore

        numbers:
          defaultTolerance: 0.001
          relativeTolerancePercent: 0.1

        strings:
          trimWhitespace: true
          ignoreCase: false
        """

        let config = try RuleConfigurationParser().parse(source)

        XCTAssertEqual(config.options.ignorePaths, ["/updatedAt", "/items/*/traceId"])
        XCTAssertEqual(config.options.arrayRules["/users"], .keyed("id"))
        XCTAssertEqual(config.options.arrayRules["/tags"], .unordered)
        XCTAssertEqual(config.options.numberTolerance.absolute, 0.001)
        XCTAssertEqual(config.options.numberTolerance.relativePercent, 0.1)
        XCTAssertTrue(config.options.strings.trimWhitespace)
    }

    func testRejectsUnsupportedVersion() {
        XCTAssertThrowsError(try RuleConfigurationParser().parse("version: 2"))
    }
}
