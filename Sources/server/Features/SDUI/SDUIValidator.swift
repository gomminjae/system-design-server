import Foundation

struct SDUIValidationError: Error, Equatable, Sendable {
    let issues: [String]
}

struct SDUIScreenValidator: Sendable {
    private static let maxDepth = 20
    private static let maxNodeCount = 200
    private static let maxTextLength = 5_000

    func validate(_ document: SDUIScreenDocument) throws {
        var issues: [String] = []
        var nodeIDs = Set<String>()
        var nodeCount = 0

        if document.protocolVersion != 1 {
            issues.append("protocolVersion은 1이어야 합니다.")
        }
        if document.catalogVersion.isEmpty {
            issues.append("catalogVersion이 필요합니다.")
        }
        if document.screen.id.isEmpty {
            issues.append("screen.id가 필요합니다.")
        }
        if document.screen.revision < 1 {
            issues.append("screen.revision은 1 이상이어야 합니다.")
        }
        if document.screen.fallback.target.isEmpty {
            issues.append("screen.fallback.target이 필요합니다.")
        }

        validateNode(
            document.screen.root,
            depth: 1,
            nodeIDs: &nodeIDs,
            nodeCount: &nodeCount,
            issues: &issues
        )

        if !issues.isEmpty {
            throw SDUIValidationError(issues: issues)
        }
    }

    private func validateNode(
        _ node: SDUINode,
        depth: Int,
        nodeIDs: inout Set<String>,
        nodeCount: inout Int,
        issues: inout [String]
    ) {
        nodeCount += 1
        if nodeCount > Self.maxNodeCount {
            appendOnce("화면은 최대 \(Self.maxNodeCount)개 노드만 가질 수 있습니다.", to: &issues)
            return
        }
        if depth > Self.maxDepth {
            appendOnce("화면 트리 깊이는 최대 \(Self.maxDepth)입니다.", to: &issues)
            return
        }

        if !isValidIdentifier(node.id) {
            issues.append("node.id '\(node.id)' 형식이 올바르지 않습니다.")
        } else if !nodeIDs.insert(node.id).inserted {
            issues.append("중복 node.id '\(node.id)'가 있습니다.")
        }

        switch node.type {
        case .vStack, .hStack:
            validateLayout(node, issues: &issues)
        case .text:
            validateText(node, issues: &issues)
        case .image:
            validateImage(node, issues: &issues)
        case .button:
            validateButton(node, issues: &issues)
        }

        validateAction(node.action, nodeID: node.id, issues: &issues)
        for child in node.children ?? [] {
            validateNode(
                child,
                depth: depth + 1,
                nodeIDs: &nodeIDs,
                nodeCount: &nodeCount,
                issues: &issues
            )
        }
    }

    private func validateLayout(_ node: SDUINode, issues: inout [String]) {
        if node.children == nil {
            issues.append("layout 노드 '\(node.id)'에는 children이 필요합니다.")
        }
        if node.action != nil {
            issues.append("layout 노드 '\(node.id)'에는 action을 지정할 수 없습니다.")
        }
        requireOnly(
            node.props,
            allowed: [.gap, .paddingX, .alignment],
            nodeID: node.id,
            issues: &issues
        )
    }

    private func validateText(_ node: SDUINode, issues: inout [String]) {
        if let text = node.props.text {
            if text.isEmpty || text.count > Self.maxTextLength {
                issues.append("text 노드 '\(node.id)'의 text 길이가 올바르지 않습니다.")
            }
        } else {
            issues.append("text 노드 '\(node.id)'에는 text가 필요합니다.")
        }
        if node.props.textStyle == nil || node.props.color == nil {
            issues.append("text 노드 '\(node.id)'에는 textStyle과 color가 필요합니다.")
        }
        if let maxLines = node.props.maxLines, !(1...20).contains(maxLines) {
            issues.append("text 노드 '\(node.id)'의 maxLines는 1...20이어야 합니다.")
        }
        validateLeaf(node, issues: &issues)
        requireOnly(
            node.props,
            allowed: [.text, .textStyle, .color, .maxLines],
            nodeID: node.id,
            issues: &issues
        )
    }

    private func validateImage(_ node: SDUINode, issues: inout [String]) {
        if let rawURL = node.props.imageURL,
           let url = URL(string: rawURL),
           url.scheme == "https",
           url.host != nil {
            // Valid HTTPS asset URL.
        } else {
            issues.append("image 노드 '\(node.id)'에는 유효한 HTTPS imageURL이 필요합니다.")
        }
        if node.props.alt?.isEmpty != false {
            issues.append("image 노드 '\(node.id)'에는 alt가 필요합니다.")
        }
        if let aspectRatio = node.props.aspectRatio, !(0.1...10).contains(aspectRatio) {
            issues.append("image 노드 '\(node.id)'의 aspectRatio가 허용 범위를 벗어났습니다.")
        }
        validateLeaf(node, issues: &issues)
        requireOnly(
            node.props,
            allowed: [.imageURL, .alt, .aspectRatio],
            nodeID: node.id,
            issues: &issues
        )
    }

    private func validateButton(_ node: SDUINode, issues: inout [String]) {
        if let label = node.props.label {
            if label.isEmpty || label.count > 100 {
                issues.append("button 노드 '\(node.id)'의 label 길이가 올바르지 않습니다.")
            }
        } else {
            issues.append("button 노드 '\(node.id)'에는 label이 필요합니다.")
        }
        if node.props.tone == nil || node.props.variant == nil || node.props.size == nil {
            issues.append("button 노드 '\(node.id)'에는 tone, variant, size가 필요합니다.")
        }
        if node.action == nil {
            issues.append("button 노드 '\(node.id)'에는 action이 필요합니다.")
        }
        validateLeaf(node, allowAction: true, issues: &issues)
        requireOnly(
            node.props,
            allowed: [.label, .tone, .variant, .size, .accessibilityLabel],
            nodeID: node.id,
            issues: &issues
        )
    }

    private func validateLeaf(
        _ node: SDUINode,
        allowAction: Bool = false,
        issues: inout [String]
    ) {
        if node.children != nil {
            issues.append("leaf 노드 '\(node.id)'에는 children을 지정할 수 없습니다.")
        }
        if !allowAction, node.action != nil {
            issues.append("노드 '\(node.id)'에는 action을 지정할 수 없습니다.")
        }
    }

    private func validateAction(
        _ action: SDUIAction?,
        nodeID: String,
        issues: inout [String]
    ) {
        guard let action else { return }

        switch action.type {
        case .navigate:
            if action.target.map(isValidIdentifier) != true || action.actionID != nil {
                issues.append("노드 '\(nodeID)'의 navigate action이 올바르지 않습니다.")
            }
        case .invoke:
            if action.actionID.map(isValidIdentifier) != true || action.target != nil {
                issues.append("노드 '\(nodeID)'의 invoke action이 올바르지 않습니다.")
            }
        }
    }

    private func isValidIdentifier(_ value: String) -> Bool {
        guard !value.isEmpty, value.count <= 80 else { return false }
        return value.allSatisfy { character in
            character.isLetter || character.isNumber || character == "." || character == "_" || character == "-"
        }
    }

    private func appendOnce(_ issue: String, to issues: inout [String]) {
        if !issues.contains(issue) {
            issues.append(issue)
        }
    }

    private func requireOnly(
        _ props: SDUIProps,
        allowed: Set<SDUIPropKey>,
        nodeID: String,
        issues: inout [String]
    ) {
        let unsupported = props.presentKeys.subtracting(allowed)
        if !unsupported.isEmpty {
            issues.append(
                "노드 '\(nodeID)'에 지원하지 않는 props가 있습니다: "
                    + unsupported.map(\.rawValue).sorted().joined(separator: ", ")
            )
        }
    }
}

struct SDUIThemeValidator: Sendable {
    func validate(_ theme: SDUIThemeDocument) throws {
        var issues: [String] = []
        if theme.schemaVersion != 1 {
            issues.append("theme.schemaVersion은 1이어야 합니다.")
        }
        if theme.id.isEmpty || theme.baseThemeID.isEmpty {
            issues.append("theme id와 extends가 필요합니다.")
        }
        if theme.revision < 1 {
            issues.append("theme.revision은 1 이상이어야 합니다.")
        }

        validate(theme.modes.light, mode: "light", issues: &issues)
        validate(theme.modes.dark, mode: "dark", issues: &issues)
        if !issues.isEmpty {
            throw SDUIValidationError(issues: issues)
        }
    }

    private func validate(_ colors: SDUIBrandColors, mode: String, issues: inout [String]) {
        let values = [
            colors.brandSolid,
            colors.brandSolidPressed,
            colors.brandWeak,
            colors.brandWeakPressed,
            colors.foregroundBrand,
            colors.foregroundOnBrand,
        ]
        if values.contains(where: { !isHexColor($0) }) {
            issues.append("theme의 \(mode) 색상은 #RRGGBB 또는 #RRGGBBAA 형식이어야 합니다.")
        }
    }

    private func isHexColor(_ value: String) -> Bool {
        guard value.first == "#", value.count == 7 || value.count == 9 else { return false }
        return value.dropFirst().allSatisfy(\.isHexDigit)
    }
}

private enum SDUIPropKey: String, Hashable {
    case text
    case textStyle
    case color
    case maxLines
    case gap
    case paddingX
    case alignment
    case imageURL
    case alt
    case aspectRatio
    case label
    case tone
    case variant
    case size
    case accessibilityLabel
}

private extension SDUIProps {
    var presentKeys: Set<SDUIPropKey> {
        var keys = Set<SDUIPropKey>()
        if text != nil { keys.insert(.text) }
        if textStyle != nil { keys.insert(.textStyle) }
        if color != nil { keys.insert(.color) }
        if maxLines != nil { keys.insert(.maxLines) }
        if gap != nil { keys.insert(.gap) }
        if paddingX != nil { keys.insert(.paddingX) }
        if alignment != nil { keys.insert(.alignment) }
        if imageURL != nil { keys.insert(.imageURL) }
        if alt != nil { keys.insert(.alt) }
        if aspectRatio != nil { keys.insert(.aspectRatio) }
        if label != nil { keys.insert(.label) }
        if tone != nil { keys.insert(.tone) }
        if variant != nil { keys.insert(.variant) }
        if size != nil { keys.insert(.size) }
        if accessibilityLabel != nil { keys.insert(.accessibilityLabel) }
        return keys
    }
}
