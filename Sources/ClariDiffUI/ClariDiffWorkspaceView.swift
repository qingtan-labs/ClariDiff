import AppKit
import ClariDiffCore
import SwiftUI
import UniformTypeIdentifiers

public struct ClariDiffWorkspaceView: View {
    @StateObject private var model = WorkspaceViewModel()

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            HStack(spacing: 0) {
                InputPanel(
                    side: .left,
                    badge: "A",
                    title: model.language.text(.sourceA),
                    fileName: model.leftName,
                    formatName: model.leftFormat?.rawValue,
                    text: $model.leftText,
                    error: model.leftError,
                    language: model.language,
                    onChoose: { chooseFile(for: .left) },
                    onPaste: { model.paste(.left) },
                    onFormat: { model.format(.left) },
                    onDropURL: { model.load($0, side: .left) },
                    onDropContent: { content, name in model.set(content, name: name, side: .left) },
                    onEdit: model.scheduleComparison
                )
                .frame(minWidth: 310)

                Divider()

                InputPanel(
                    side: .right,
                    badge: "B",
                    title: model.language.text(.sourceB),
                    fileName: model.rightName,
                    formatName: model.rightFormat?.rawValue,
                    text: $model.rightText,
                    error: model.rightError,
                    language: model.language,
                    onChoose: { chooseFile(for: .right) },
                    onPaste: { model.paste(.right) },
                    onFormat: { model.format(.right) },
                    onDropURL: { model.load($0, side: .right) },
                    onDropContent: { content, name in model.set(content, name: name, side: .right) },
                    onEdit: model.scheduleComparison
                )
                .frame(minWidth: 310)

                Divider()

                ResultPanel(model: model)
                    .frame(minWidth: 430, idealWidth: 520)
            }
        }
        .frame(minWidth: 1120, minHeight: 680)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $model.showingRules) {
            RulesSheet(model: model)
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            BrandMark()
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text("ClariDiff")
                    .font(.system(size: 15, weight: .semibold))
                Text("Compare anything. See what matters.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }

            Label(model.language.text(.localOnly), systemImage: "lock.shield")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.leading, 8)

            Spacer()

            ToolbarAction(
                title: model.language.text(.rules),
                systemImage: "slider.horizontal.3"
            ) { model.showingRules = true }

            ToolbarAction(
                title: model.language.text(.export),
                systemImage: "square.and.arrow.up"
            ) { saveMarkdown() }
            .disabled(model.result == nil)

            Button(model.language.rawValue) {
                model.language = model.language == .zh ? .en : .zh
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("中文 / English")

            Button {
                model.compareNow()
            } label: {
                Label(model.language.text(.compare), systemImage: "arrow.left.arrow.right")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .keyboardShortcut(.return, modifiers: [.command])
        }
        .padding(.leading, 76)
        .padding(.trailing, 14)
        .frame(height: 58)
        .background(.ultraThinMaterial)
    }

    private func chooseFile(for side: SourceSide) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = model.language.text(.pasteOrDrop)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        model.load(url, side: side)
    }

    private func saveMarkdown() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md")!]
        panel.nameFieldStringValue = "claridiff-report.md"
        panel.title = model.language.text(.saveReport)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try model.markdownReport.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}

private struct BrandMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.03, green: 0.10, blue: 0.20),
                                 Color(red: 0.05, green: 0.18, blue: 0.34)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            HStack(spacing: 2) {
                ForEach(0..<2) { index in
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .fill(index == 0 ? Color(red: 0.58, green: 0.88, blue: 1.0)
                                         : Color(red: 0.70, green: 0.76, blue: 1.0))
                        .frame(width: 8, height: 15)
                        .overlay {
                            Capsule()
                                .fill(index == 0 ? Color(red: 1.0, green: 0.42, blue: 0.32)
                                                 : Color(red: 1.0, green: 0.70, blue: 0.12))
                                .frame(width: 6, height: 2.5)
                        }
                }
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12))
        }
    }
}

private struct ToolbarAction: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

private struct InputPanel: View {
    let side: SourceSide
    let badge: String
    let title: String
    let fileName: String
    let formatName: String?
    @Binding var text: String
    let error: String?
    let language: AppLanguage
    let onChoose: () -> Void
    let onPaste: () -> Void
    let onFormat: () -> Void
    let onDropURL: (URL) -> Void
    let onDropContent: (String, String) -> Void
    let onEdit: () -> Void

    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Text(badge)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 21, height: 21)
                        .background(side == .left ? Color.indigo : Color.teal)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title).font(.system(size: 13, weight: .semibold))
                        HStack(spacing: 5) {
                            Text(fileName)
                                .font(.system(size: 10.5, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            if let formatName {
                                Text(formatName)
                                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1.5)
                                    .background(Color.primary.opacity(0.06))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    Spacer()
                    Circle()
                        .fill(error == nil ? Color.green : Color.red)
                        .frame(width: 7, height: 7)
                        .help(error == nil ? (formatName ?? "Text") : language.text(.invalidInput))
                }

                HStack(spacing: 6) {
                    MiniAction(title: language.text(.chooseFile), icon: "folder", action: onChoose)
                    MiniAction(title: language.text(.clipboard), icon: "doc.on.clipboard", action: onPaste)
                    MiniAction(title: language.text(.format), icon: "text.alignleft", action: onFormat)
                    Spacer()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.55))

            Divider()

            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(.system(size: 12.5, design: .monospaced))
                    .lineSpacing(2)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor))
                    .onChange(of: text) { _ in onEdit() }

                if text.isEmpty {
                    Label(language.text(.pasteOrDrop), systemImage: "doc.badge.plus")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .padding(18)
                        .allowsHitTesting(false)
                }

                if isDropTargeted {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                        .overlay {
                            VStack(spacing: 8) {
                                Image(systemName: "arrow.down.doc.fill")
                                    .font(.system(size: 30))
                                Text(language.text(.dropHere)).fontWeight(.semibold)
                            }
                            .foregroundStyle(Color.accentColor)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [7]))
                        }
                        .padding(10)
                        .allowsHitTesting(false)
                }
            }
            .onDrop(of: [.fileURL, .plainText], isTargeted: $isDropTargeted, perform: handleDrop)

            if let error {
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(language.text(.invalidInput))
                            .font(.system(size: 11, weight: .semibold))
                        Text(error)
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                    Spacer()
                }
                .padding(9)
                .background(Color.red.opacity(0.08))
                .overlay(alignment: .top) { Divider() }
            }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url: URL?
                if let direct = item as? URL {
                    url = direct
                } else if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else {
                    url = nil
                }
                guard let url else { return }
                DispatchQueue.main.async { onDropURL(url) }
            }
            return true
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                let content = item as? String ?? (item as? Data).flatMap { String(data: $0, encoding: .utf8) }
                guard let content else { return }
                DispatchQueue.main.async { onDropContent(content, "Dropped text") }
            }
            return true
        }
        return false
    }
}

private struct MiniAction: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 10.5, weight: .medium))
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
    }
}

private struct ResultPanel: View {
    @ObservedObject var model: WorkspaceViewModel

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.language.text(.semanticDiff))
                            .font(.system(size: 13, weight: .semibold))
                        Text("\(model.summary.total) \(model.language.text(.changes))")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("", selection: $model.resultMode) {
                        Label(model.language.text(.tree), systemImage: "list.bullet.indent")
                            .tag(ResultMode.tree)
                        Label(model.language.text(.report), systemImage: "doc.plaintext")
                            .tag(ResultMode.report)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 170)
                }

                SummaryStrip(summary: model.summary, language: model.language)

                HStack(spacing: 8) {
                    Picker("", selection: $model.filter) {
                        Text(model.language.text(.allChanges)).tag(ChangeFilter.all)
                        Text(model.language.text(.added)).tag(ChangeFilter.added)
                        Text(model.language.text(.removed)).tag(ChangeFilter.removed)
                        Text(model.language.text(.modified)).tag(ChangeFilter.modified)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 260)

                    TextField(model.language.text(.search), text: $model.searchText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.55))

            Divider()

            Group {
                if model.leftError != nil || model.rightError != nil || model.comparisonError != nil {
                    ResultEmptyState(
                        icon: "exclamationmark.triangle",
                        title: model.comparisonError ?? model.language.text(.fixInput),
                        tint: .orange
                    )
                } else if model.result == nil {
                    ResultEmptyState(
                        icon: "arrow.left.arrow.right",
                        title: model.language.text(.emptyState),
                        tint: .gray
                    )
                } else if model.summary.total == 0 {
                    ResultEmptyState(
                        icon: "checkmark.seal.fill",
                        title: model.language.text(.noDifferences),
                        tint: .green
                    )
                } else if model.resultMode == .report {
                    TextEditor(text: .constant(model.markdownReport))
                        .font(.system(size: 11.5, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Color(nsColor: .textBackgroundColor))
                } else {
                    diffTree
                }
            }
        }
    }

    private var diffTree: some View {
        ScrollView {
            LazyVStack(spacing: 5) {
                if let root = model.filteredResult {
                    let nodes = root.children.isEmpty ? [root] : root.children
                    ForEach(nodes) { node in
                        DiffNodeRow(node: node, language: model.language) { path in
                            model.copyPointer(path.isEmpty ? "/" : path)
                        }
                    }
                } else {
                    Text(model.language.text(.noDifferences))
                        .foregroundStyle(.secondary)
                        .padding(30)
                }
            }
            .padding(10)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}

private struct SummaryStrip: View {
    let summary: DiffSummary
    let language: AppLanguage

    var body: some View {
        HStack(spacing: 7) {
            SummaryBadge(value: summary.added, title: language.text(.added), color: .green, icon: "plus")
            SummaryBadge(value: summary.removed, title: language.text(.removed), color: .red, icon: "minus")
            SummaryBadge(
                value: summary.modified + summary.typeChanged + summary.moved,
                title: language.text(.modified),
                color: .orange,
                icon: "pencil"
            )
        }
    }
}

private struct SummaryBadge: View {
    let value: Int
    let title: String
    let color: Color
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 20, height: 20)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            VStack(alignment: .leading, spacing: 0) {
                Text("\(value)").font(.system(size: 13, weight: .bold, design: .rounded))
                Text(title).font(.system(size: 9.5)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 2)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07))
        }
    }
}

private struct ResultEmptyState: View {
    let icon: String
    let title: String
    let tint: Color

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(tint)
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }
}

private struct DiffNodeRow: View {
    let node: DiffNode
    let language: AppLanguage
    let onCopy: (String) -> Void

    @State private var expanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 7) {
                if !node.children.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.16)) { expanded.toggle() }
                    } label: {
                        Image(systemName: expanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .frame(width: 14, height: 14)
                    }
                    .buttonStyle(.plain)
                } else {
                    Image(systemName: statusIcon)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(statusColor)
                        .frame(width: 14, height: 14)
                }

                Text(node.name)
                    .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                    .lineLimit(1)

                StatusPill(status: node.status, language: language)

                Spacer(minLength: 8)

                if node.children.isEmpty {
                    ValueTransition(node: node)
                } else {
                    Text("\(node.leafChanges.count)")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Button { onCopy(node.path) } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(language.text(.copyPointer))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(statusColor.opacity(node.children.isEmpty ? 0.07 : 0.045))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .contentShape(Rectangle())
            .onTapGesture { onCopy(node.path) }
            .contextMenu {
                Button(language.text(.copyPointer)) { onCopy(node.path) }
            }

            if expanded, !node.children.isEmpty {
                VStack(spacing: 4) {
                    ForEach(node.children) { child in
                        DiffNodeRow(node: child, language: language, onCopy: onCopy)
                    }
                }
                .padding(.leading, 17)
            }
        }
    }

    private var statusColor: Color {
        switch node.status {
        case .added: return .green
        case .removed: return .red
        case .modified: return .orange
        case .typeChanged: return .purple
        case .moved: return .blue
        case .unchanged: return .secondary
        }
    }

    private var statusIcon: String {
        switch node.status {
        case .added: return "plus"
        case .removed: return "minus"
        case .modified: return "pencil"
        case .typeChanged: return "arrow.triangle.2.circlepath"
        case .moved: return "arrow.right"
        case .unchanged: return "equal"
        }
    }
}

private struct StatusPill: View {
    let status: DiffStatus
    let language: AppLanguage

    var body: some View {
        Text(label.uppercased())
            .font(.system(size: 8, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private var label: String {
        switch status {
        case .added: return language.text(.added)
        case .removed: return language.text(.removed)
        case .modified, .typeChanged, .moved: return language.text(.modified)
        case .unchanged: return "="
        }
    }

    private var color: Color {
        switch status {
        case .added: return .green
        case .removed: return .red
        case .modified: return .orange
        case .typeChanged: return .purple
        case .moved: return .blue
        case .unchanged: return .secondary
        }
    }
}

private struct ValueTransition: View {
    let node: DiffNode

    var body: some View {
        HStack(spacing: 5) {
            if let left = node.leftValue {
                Text(short(left))
                    .foregroundStyle(node.status == .removed ? Color.red : Color.secondary)
            }
            if node.leftValue != nil, node.rightValue != nil {
                Image(systemName: "arrow.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            if let right = node.rightValue {
                Text(short(right))
                    .foregroundStyle(node.status == .added ? Color.green : Color.primary)
            }
        }
        .font(.system(size: 10.5, design: .monospaced))
        .lineLimit(1)
        .frame(maxWidth: 230, alignment: .trailing)
    }

    private func short(_ value: JSONValue) -> String {
        let text = value.scalarDescription.replacingOccurrences(of: "\n", with: "\\n")
        return text.count > 42 ? String(text.prefix(39)) + "…" : text
    }
}

private struct RulesSheet: View {
    @ObservedObject var model: WorkspaceViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var ignorePaths: String
    @State private var arrayRules: String
    @State private var absoluteTolerance: Double
    @State private var relativeTolerance: Double
    @State private var trimWhitespace: Bool
    @State private var ignoreCase: Bool
    @State private var normalizeDates: Bool
    @State private var coerceNumericStrings: Bool

    init(model: WorkspaceViewModel) {
        self.model = model
        _ignorePaths = State(initialValue: model.ignorePathsText)
        _arrayRules = State(initialValue: model.arrayRulesText)
        _absoluteTolerance = State(initialValue: model.absoluteTolerance)
        _relativeTolerance = State(initialValue: model.relativeTolerance)
        _trimWhitespace = State(initialValue: model.trimWhitespace)
        _ignoreCase = State(initialValue: model.ignoreCase)
        _normalizeDates = State(initialValue: model.normalizeDates)
        _coerceNumericStrings = State(initialValue: model.coerceNumericStrings)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.language.text(.settings))
                        .font(.system(size: 18, weight: .semibold))
                    Text(".claridiff.yml compatible concepts")
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(18)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    RuleSection(title: model.language.text(.ignorePaths), icon: "eye.slash") {
                        Text(model.language.text(.ignoreHint))
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                        TextEditor(text: $ignorePaths)
                            .font(.system(size: 11.5, design: .monospaced))
                            .frame(height: 82)
                            .padding(5)
                            .background(Color(nsColor: .textBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .overlay { RoundedRectangle(cornerRadius: 7).strokeBorder(Color.primary.opacity(0.1)) }
                    }

                    RuleSection(title: model.language.text(.arrayRules), icon: "list.number") {
                        Text(model.language.text(.arrayHint))
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                        TextEditor(text: $arrayRules)
                            .font(.system(size: 11.5, design: .monospaced))
                            .frame(height: 82)
                            .padding(5)
                            .background(Color(nsColor: .textBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .overlay { RoundedRectangle(cornerRadius: 7).strokeBorder(Color.primary.opacity(0.1)) }
                    }

                    RuleSection(title: model.language.text(.numberTolerance), icon: "plus.forwardslash.minus") {
                        HStack(spacing: 14) {
                            LabeledNumberField(
                                title: model.language.text(.absoluteTolerance),
                                value: $absoluteTolerance,
                                suffix: ""
                            )
                            LabeledNumberField(
                                title: model.language.text(.relativeTolerance),
                                value: $relativeTolerance,
                                suffix: "%"
                            )
                        }
                    }

                    RuleSection(title: model.language.text(.stringRules), icon: "textformat") {
                        Toggle(model.language.text(.trimWhitespace), isOn: $trimWhitespace)
                        Toggle(model.language.text(.ignoreCase), isOn: $ignoreCase)
                        Toggle(model.language.text(.normalizeDates), isOn: $normalizeDates)
                        Toggle(model.language.text(.numericStrings), isOn: $coerceNumericStrings)
                    }
                }
                .padding(20)
            }

            Divider()

            HStack {
                Spacer()
                Button(model.language.text(.cancel)) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(model.language.text(.apply)) { apply() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(14)
        }
        .frame(width: 560, height: 650)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func apply() {
        model.ignorePathsText = ignorePaths
        model.arrayRulesText = arrayRules
        model.absoluteTolerance = max(0, absoluteTolerance)
        model.relativeTolerance = max(0, relativeTolerance)
        model.trimWhitespace = trimWhitespace
        model.ignoreCase = ignoreCase
        model.normalizeDates = normalizeDates
        model.coerceNumericStrings = coerceNumericStrings
        model.applyRules()
    }
}

private struct RuleSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .semibold))
            VStack(alignment: .leading, spacing: 8) { content }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

private struct LabeledNumberField: View {
    let title: String
    @Binding var value: Double
    let suffix: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 10.5)).foregroundStyle(.secondary)
            HStack(spacing: 5) {
                TextField("0", value: $value, format: .number)
                    .textFieldStyle(.roundedBorder)
                if !suffix.isEmpty {
                    Text(suffix).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}
