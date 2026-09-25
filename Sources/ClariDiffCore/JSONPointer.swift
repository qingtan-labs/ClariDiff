import Foundation

public enum JSONPointer {
    public static func appending(_ component: String, to path: String) -> String {
        let escaped = component
            .replacingOccurrences(of: "~", with: "~0")
            .replacingOccurrences(of: "/", with: "~1")
        return path + "/" + escaped
    }

    public static func components(of path: String) -> [String] {
        guard !path.isEmpty, path.hasPrefix("/") else { return [] }
        return path.dropFirst().split(separator: "/", omittingEmptySubsequences: false).map {
            String($0)
                .replacingOccurrences(of: "~1", with: "/")
                .replacingOccurrences(of: "~0", with: "~")
        }
    }

    public static func lastComponent(of path: String) -> String {
        components(of: path).last ?? "$"
    }

    public static func normalizeRule(_ rule: String) -> String {
        let trimmed = rule.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.hasPrefix("/") { return trimmed }

        var converted = trimmed
            .replacingOccurrences(of: "[*]", with: ".*")
            .replacingOccurrences(of: "[", with: ".")
            .replacingOccurrences(of: "]", with: "")
        if converted.hasPrefix("$.") { converted.removeFirst(2) }
        return "/" + converted.split(separator: ".").map(String.init).joined(separator: "/")
    }

    public static func matches(path: String, pattern: String) -> Bool {
        let pathParts = components(of: path)
        let patternParts = components(of: normalizeRule(pattern))
        guard pathParts.count == patternParts.count else { return false }
        return zip(pathParts, patternParts).allSatisfy { actual, expected in
            expected == "*" || actual == expected
        }
    }
}
