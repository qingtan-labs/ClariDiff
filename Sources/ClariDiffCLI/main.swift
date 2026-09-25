import Darwin
import Foundation
import ClariDiffCore

@main
struct ClariDiffCommand {
    static func main() {
        do {
            let invocation = try Invocation.parse(Array(CommandLine.arguments.dropFirst()))
            if invocation.showHelp {
                print(Invocation.help)
                exit(0)
            }
            if invocation.showVersion {
                print("claridiff 1.0.0")
                exit(0)
            }

            guard invocation.files.count == 2 else {
                throw CLIError("Expected two files. Run claridiff --help for usage.")
            }

            var options = DiffOptions()
            if let configPath = invocation.configPath {
                let source = try String(contentsOfFile: configPath, encoding: .utf8)
                options = try RuleConfigurationParser().parse(source).options
            }
            options.ignorePaths.append(contentsOf: invocation.ignorePaths.map(JSONPointer.normalizeRule))
            for (path, mode) in invocation.arrayRules {
                options.arrayRules[JSONPointer.normalizeRule(path)] = mode
            }
            if let absolute = invocation.absoluteTolerance {
                options.numberTolerance.absolute = absolute
            }
            if let relative = invocation.relativeTolerancePercent {
                options.numberTolerance.relativePercent = relative
            }
            if invocation.trimWhitespace { options.strings.trimWhitespace = true }
            if invocation.ignoreCase { options.strings.ignoreCase = true }
            if invocation.coerceNumericStrings { options.strings.coerceNumericStrings = true }

            let loader = UniversalContentLoader()
            let left = try loader.load(URL(fileURLWithPath: invocation.files[0]))
            let right = try loader.load(URL(fileURLWithPath: invocation.files[1]))
            let result = try UniversalDiffEngine(options: options).compare(left, right)
            let report = ReportExporter().export(result, format: invocation.format)

            if let outputPath = invocation.outputPath {
                try report.write(toFile: outputPath, atomically: true, encoding: .utf8)
            } else {
                print(report, terminator: "")
            }
            exit(result.summary.total == 0 ? 0 : 1)
        } catch {
            writeError("claridiff: \(error.localizedDescription)\n")
            exit(2)
        }
    }

    private static func writeError(_ message: String) {
        FileHandle.standardError.write(Data(message.utf8))
    }
}

private struct Invocation {
    var files: [String] = []
    var ignorePaths: [String] = []
    var arrayRules: [String: ArrayComparisonMode] = [:]
    var configPath: String?
    var outputPath: String?
    var format: ReportFormat = .text
    var absoluteTolerance: Double?
    var relativeTolerancePercent: Double?
    var trimWhitespace = false
    var ignoreCase = false
    var coerceNumericStrings = false
    var showHelp = false
    var showVersion = false

    static func parse(_ arguments: [String]) throws -> Invocation {
        var result = Invocation()
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "-h", "--help":
                result.showHelp = true
            case "--version":
                result.showVersion = true
            case "--ignore":
                result.ignorePaths.append(try value(after: argument, arguments: arguments, index: &index))
            case "--array-key":
                let rule = try value(after: argument, arguments: arguments, index: &index)
                let pair = try splitRule(rule, option: argument)
                result.arrayRules[pair.path] = .keyed(pair.value)
            case "--array-order":
                let rule = try value(after: argument, arguments: arguments, index: &index)
                let pair = try splitRule(rule, option: argument)
                switch pair.value {
                case "ignore": result.arrayRules[pair.path] = .unordered
                case "position", "positional": result.arrayRules[pair.path] = .positional
                default: throw CLIError("--array-order expects PATH=ignore or PATH=position")
                }
            case "--config":
                result.configPath = try value(after: argument, arguments: arguments, index: &index)
            case "-o", "--output":
                result.outputPath = try value(after: argument, arguments: arguments, index: &index)
            case "--format":
                let value = try value(after: argument, arguments: arguments, index: &index)
                guard let format = ReportFormat(rawValue: value) else {
                    throw CLIError("--format expects text or markdown")
                }
                result.format = format
            case "--absolute-tolerance":
                let value = try value(after: argument, arguments: arguments, index: &index)
                guard let number = Double(value), number >= 0 else {
                    throw CLIError("--absolute-tolerance expects a non-negative number")
                }
                result.absoluteTolerance = number
            case "--relative-tolerance":
                let value = try value(after: argument, arguments: arguments, index: &index)
                guard let number = Double(value), number >= 0 else {
                    throw CLIError("--relative-tolerance expects a non-negative percentage")
                }
                result.relativeTolerancePercent = number
            case "--trim-whitespace":
                result.trimWhitespace = true
            case "--ignore-case":
                result.ignoreCase = true
            case "--coerce-numeric-strings":
                result.coerceNumericStrings = true
            default:
                if argument.hasPrefix("-") {
                    throw CLIError("Unknown option: \(argument)")
                }
                result.files.append(argument)
            }
            index += 1
        }
        return result
    }

    private static func value(
        after option: String,
        arguments: [String],
        index: inout Int
    ) throws -> String {
        index += 1
        guard index < arguments.count else { throw CLIError("Missing value after \(option)") }
        return arguments[index]
    }

    private static func splitRule(_ rule: String, option: String) throws -> (path: String, value: String) {
        guard let separator = rule.lastIndex(of: "=") else {
            throw CLIError("\(option) expects PATH=VALUE")
        }
        let path = String(rule[..<separator])
        let value = String(rule[rule.index(after: separator)...])
        guard !path.isEmpty, !value.isEmpty else {
            throw CLIError("\(option) expects PATH=VALUE")
        }
        return (path, value)
    }

    static let help = """
    ClariDiff — meaningful comparison for data, code, and documents

    USAGE
      claridiff <before-file> <after-file> [options]

    FORMATS
      Data: JSON, JSONL/NDJSON, YAML, TOML, XML, CSV
      Front end: Vue, React JSX/TSX, JavaScript/TypeScript, Svelte, Astro, HTML/CSS
      Other code: Swift, Python, Java, Go, Rust, C/C++, and text code
      Documents: TXT, Markdown, RTF, DOCX, and text-based PDF

    OPTIONS
      --ignore <path>                Ignore a structured path (repeatable)
      --array-key <path=field>       Match array objects by a field
      --array-order <path=mode>      mode: ignore or position
      --absolute-tolerance <number>  Absolute numeric tolerance
      --relative-tolerance <percent> Relative numeric tolerance in percent
      --trim-whitespace              Trim strings before comparing
      --ignore-case                  Compare strings case-insensitively
      --coerce-numeric-strings       Treat "1" and 1 as equal
      --config <file>                Read a .claridiff.yml rule file
      --format <text|markdown>       Report format (default: text)
      -o, --output <file>            Write the report to a file
      -h, --help                     Show help
      --version                      Show version

    EXIT CODES
      0  no semantic differences
      1  semantic differences found
      2  input or configuration error
    """
}

private struct CLIError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
