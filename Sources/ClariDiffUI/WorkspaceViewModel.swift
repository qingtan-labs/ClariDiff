import AppKit
import Combine
import Foundation
import ClariDiffCore

enum SourceSide: Equatable { case left, right }

enum ResultMode: String, CaseIterable, Identifiable {
    case tree
    case report
    var id: String { rawValue }
}

enum ChangeFilter: String, CaseIterable, Identifiable {
    case all
    case added
    case removed
    case modified
    var id: String { rawValue }

    var statuses: Set<DiffStatus> {
        switch self {
        case .all: return [.added, .removed, .modified, .typeChanged, .moved]
        case .added: return [.added]
        case .removed: return [.removed]
        case .modified: return [.modified, .typeChanged, .moved]
        }
    }
}

final class WorkspaceViewModel: ObservableObject {
    @Published var leftText: String
    @Published var rightText: String
    @Published var leftName = "Example A.json"
    @Published var rightName = "Example B.json"
    @Published var leftError: String?
    @Published var rightError: String?
    @Published var leftFormat: ContentFormat?
    @Published var rightFormat: ContentFormat?
    @Published var comparisonError: String?
    @Published var result: DiffNode?
    @Published var language: AppLanguage = .zh
    @Published var resultMode: ResultMode = .tree
    @Published var filter: ChangeFilter = .all
    @Published var searchText = ""
    @Published var showingRules = false

    @Published var ignorePathsText = "/updatedAt"
    @Published var arrayRulesText = "/roles=ignore"
    @Published var absoluteTolerance = 0.0
    @Published var relativeTolerance = 0.0
    @Published var trimWhitespace = false
    @Published var ignoreCase = false
    @Published var normalizeDates = false
    @Published var coerceNumericStrings = false

    private let loader = UniversalContentLoader()
    private var scheduledComparison: DispatchWorkItem?

    init() {
        leftText = """
        {
          "name": "Alice",
          "age": 20,
          "updatedAt": "2026-09-20",
          "roles": ["user", "admin"]
        }
        """
        rightText = """
        {
          "roles": ["admin", "user"],
          "age": 21,
          "name": "Alice",
          "updatedAt": "2026-09-25"
        }
        """
        compareNow()
    }

    var summary: DiffSummary { result?.summary ?? DiffSummary() }

    var filteredResult: DiffNode? {
        result?.filtering(statuses: filter.statuses, search: searchText)
    }

    var markdownReport: String {
        guard let result else { return "" }
        return ReportExporter().markdown(result)
    }

    func scheduleComparison() {
        scheduledComparison?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.compareNow() }
        scheduledComparison = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    func compareNow() {
        scheduledComparison?.cancel()
        var parsedLeft: ParsedContent?
        var parsedRight: ParsedContent?
        do {
            parsedLeft = try loader.parse(leftText, fileName: leftName)
            leftFormat = parsedLeft?.format
            leftError = nil
        } catch {
            leftFormat = nil
            leftError = error.localizedDescription
        }
        do {
            parsedRight = try loader.parse(rightText, fileName: rightName)
            rightFormat = parsedRight?.format
            rightError = nil
        } catch {
            rightFormat = nil
            rightError = error.localizedDescription
        }
        guard let parsedLeft, let parsedRight else {
            result = nil
            comparisonError = nil
            return
        }
        do {
            result = try UniversalDiffEngine(options: buildOptions()).compare(parsedLeft, parsedRight)
            comparisonError = nil
        } catch {
            result = nil
            if language == .zh,
               let semanticError = error as? SemanticDiffError,
               case let .invalidArrayKey(path, key) = semanticError {
                comparisonError = "数组规则 \(path.isEmpty ? "/" : path) 无法按“\(key)”匹配：每个元素都必须包含唯一键值。"
            } else {
                comparisonError = error.localizedDescription
            }
        }
    }

    func format(_ side: SourceSide) {
        do {
            switch side {
            case .left:
                leftText = try loader.parse(leftText, fileName: leftName).formattedText
                leftError = nil
            case .right:
                rightText = try loader.parse(rightText, fileName: rightName).formattedText
                rightError = nil
            }
            compareNow()
        } catch {
            switch side {
            case .left: leftError = error.localizedDescription
            case .right: rightError = error.localizedDescription
            }
        }
    }

    func paste(_ side: SourceSide) {
        guard let value = NSPasteboard.general.string(forType: .string) else { return }
        set(value, name: language == .zh ? "剪贴板" : "Clipboard", side: side)
    }

    func load(_ url: URL, side: SourceSide) {
        do {
            let content = try loader.load(url)
            set(content.originalText, name: url.lastPathComponent, side: side)
        } catch {
            switch side {
            case .left: leftError = error.localizedDescription
            case .right: rightError = error.localizedDescription
            }
        }
    }

    func set(_ value: String, name: String, side: SourceSide) {
        switch side {
        case .left:
            leftText = value
            leftName = name
        case .right:
            rightText = value
            rightName = name
        }
        compareNow()
    }

    func applyRules() {
        showingRules = false
        compareNow()
    }

    func copyPointer(_ path: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
    }

    private func buildOptions() -> DiffOptions {
        let ignored = ignorePathsText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var arrays: [String: ArrayComparisonMode] = [:]
        for line in arrayRulesText.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let separator = trimmed.lastIndex(of: "=") else { continue }
            let path = JSONPointer.normalizeRule(String(trimmed[..<separator]))
            let value = String(trimmed[trimmed.index(after: separator)...])
                .trimmingCharacters(in: .whitespaces)
            if value == "ignore" {
                arrays[path] = .unordered
            } else if value == "position" || value == "positional" {
                arrays[path] = .positional
            } else if !value.isEmpty {
                arrays[path] = .keyed(value)
            }
        }
        return DiffOptions(
            ignorePaths: ignored.map(JSONPointer.normalizeRule),
            arrayRules: arrays,
            numberTolerance: NumberTolerance(
                absolute: absoluteTolerance,
                relativePercent: relativeTolerance
            ),
            strings: StringNormalization(
                trimWhitespace: trimWhitespace,
                ignoreCase: ignoreCase,
                normalizeLineEndings: true,
                normalizeISODates: normalizeDates,
                coerceNumericStrings: coerceNumericStrings
            )
        )
    }
}
