import XCTest
@testable import ClariDiffCore

final class ReportExporterTests: XCTestCase {
    func testMarkdownContainsOnlyLeafChanges() throws {
        let parser = JSONParser()
        let result = try SemanticDiffEngine().compare(
            try parser.parse(#"{"same":1,"value":20}"#),
            try parser.parse(#"{"same":1,"value":21}"#)
        )

        let report = ReportExporter().markdown(result)

        XCTAssertTrue(report.contains("1 meaningful changes"))
        XCTAssertTrue(report.contains("`/value`"))
        XCTAssertFalse(report.contains("`/same`"))
    }

    func testNoDifferenceReportIsExplicit() throws {
        let value = try JSONParser().parse(#"{"ok":true}"#)
        let report = try ReportExporter().markdown(SemanticDiffEngine().compare(value, value))

        XCTAssertTrue(report.contains("No meaningful differences found"))
    }
}
