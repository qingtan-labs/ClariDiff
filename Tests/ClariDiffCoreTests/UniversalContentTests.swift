import XCTest
@testable import ClariDiffCore

final class UniversalContentTests: XCTestCase {
    private let loader = UniversalContentLoader()

    func testYAMLObjectOrderIsSemantic() throws {
        let left = try loader.parse("name: Alice\nage: 20\n", fileName: "left.yaml")
        let right = try loader.parse("age: 20\nname: Alice\n", fileName: "right.yml")

        let result = try UniversalDiffEngine().compare(left, right)

        XCTAssertEqual(left.format, .yaml)
        XCTAssertEqual(result.summary.total, 0)
    }

    func testJSONLinesParsesEachRecord() throws {
        let content = try loader.parse("{\"id\":1}\n{\"id\":2}\n", fileName: "events.ndjson")

        XCTAssertEqual(content.format, .jsonLines)
        guard case let .array(records)? = content.structuredValue else {
            return XCTFail("Expected JSON Lines records")
        }
        XCTAssertEqual(records.count, 2)
    }

    func testTOMLTablesBecomeStructuredPaths() throws {
        let left = try loader.parse("[server]\nport = 8080\nhost = 'localhost'\n", fileName: "a.toml")
        let right = try loader.parse("[server]\nhost = 'localhost'\nport = 8081\n", fileName: "b.toml")

        let result = try UniversalDiffEngine().compare(left, right)

        XCTAssertEqual(result.leafChanges.map(\.path), ["/server/port"])
    }

    func testTOMLArrayTablesBecomeStructuredArrays() throws {
        let source = """
        [[products]]
        id = 1
        name = "Hammer"

        [[products]]
        id = 2
        name = "Nail"
        """

        let content = try loader.parse(source, fileName: "catalog.toml")

        guard case let .object(root)? = content.structuredValue,
              case let .array(products)? = root["products"] else {
            return XCTFail("Expected products array")
        }
        XCTAssertEqual(products.count, 2)
    }

    func testCSVRowsCompareByConfiguredKey() throws {
        let left = try loader.parse("id,name\n1,Alice\n2,Bob\n", fileName: "a.csv")
        let right = try loader.parse("id,name\n2,Bobby\n1,Alice\n", fileName: "b.csv")
        let options = DiffOptions(arrayRules: ["": .keyed("id")])

        let result = try UniversalDiffEngine(options: options).compare(left, right)

        XCTAssertEqual(result.summary.modified, 1)
        XCTAssertEqual(result.leafChanges.first?.name, "name")
    }

    func testXMLAttributesAndChildrenAreStructured() throws {
        let left = try loader.parse("<user id=\"1\"><name>Alice</name></user>", fileName: "a.xml")
        let right = try loader.parse("<user id=\"1\"><name>Alicia</name></user>", fileName: "b.xml")

        let result = try UniversalDiffEngine().compare(left, right)

        XCTAssertEqual(result.leafChanges.map(\.path), ["/user/name"])
    }

    func testCodeInsertionDoesNotCascadeEveryFollowingLine() throws {
        let left = try loader.parse("func greet() {\n    print(\"hi\")\n}\n", fileName: "a.swift")
        let right = try loader.parse("func greet() {\n    let name = \"Ada\"\n    print(\"hi\")\n}\n", fileName: "b.swift")

        let result = try UniversalDiffEngine().compare(left, right)

        XCTAssertEqual(left.kind, .code)
        XCTAssertEqual(result.summary.added, 1)
        XCTAssertEqual(result.summary.total, 1)
    }

    func testFrontEndFormatsAreComparedAsSourceCode() throws {
        let files = ["Component.vue", "Component.jsx", "Component.tsx", "page.astro", "page.html"]
        for file in files {
            let content = try loader.parse("<Widget title=\"Hello\" />\n", fileName: file)
            XCTAssertEqual(content.kind, .code, "Expected \(file) to be source code")
        }
    }

    func testMarkdownComparesHeadingsAndParagraphs() throws {
        let left = try loader.parse("# Title\n\nOld paragraph.\n", fileName: "a.md")
        let right = try loader.parse("# Title\n\nNew paragraph.\n", fileName: "b.md")

        let result = try UniversalDiffEngine().compare(left, right)

        XCTAssertEqual(result.summary.modified, 1)
        XCTAssertEqual(result.summary.total, 1)
    }

    func testAutoDetectsPastedJSONAndCode() throws {
        XCTAssertEqual(try loader.parse("{\"ok\":true}").format, .json)
        XCTAssertEqual(try loader.parse("func run() {\n}\n").format, .sourceCode)
    }
}
