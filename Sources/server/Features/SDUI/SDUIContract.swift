import Vapor

/// 앱과 서버가 공유하는 SDUI wire protocol의 최상위 문서.
/// 화면은 실제 색상을 가지지 않고, 별도로 배포되는 theme revision만 참조한다.
struct SDUIScreenDocument: Content, Sendable {
    let protocolVersion: Int
    let catalogVersion: String
    let theme: SDUIThemeReference
    let screen: SDUIScreen
}

struct SDUIThemeReference: Content, Sendable {
    let id: String
    let revision: Int
}

struct SDUIScreen: Content, Sendable {
    let id: String
    let revision: Int
    let fallback: SDUIFallback
    let root: SDUINode
}

struct SDUIFallback: Content, Sendable {
    let type: SDUIFallbackType
    let target: String
}

enum SDUIFallbackType: String, Content, Sendable {
    case native
}

/// v1은 의도적으로 작은 공통 컴포넌트 집합만 제공한다.
/// 새로운 type을 추가하면 해당 type을 그릴 수 있는 클라이언트 배포가 필요하다.
enum SDUIComponentType: String, Content, Sendable {
    case vStack
    case hStack
    case text
    case image
    case button
}

/// type별로 허용되는 필드는 `SDUIScreenValidator`가 검증한다.
/// 하나의 안정된 JSON 형태를 유지하면서 Swift에서는 모든 값의 타입을 제한한다.
struct SDUIProps: Content, Sendable {
    let text: String?
    let textStyle: SDUITextStyle?
    let color: SDUIColorToken?
    let maxLines: Int?

    let gap: SDUISpacingToken?
    let paddingX: SDUISpacingToken?
    let alignment: SDUIAlignment?

    let imageURL: String?
    let alt: String?
    let aspectRatio: Double?

    let label: String?
    let tone: SDUIButtonTone?
    let variant: SDUIButtonVariant?
    let size: SDUIButtonSize?
    let accessibilityLabel: String?

    init(
        text: String? = nil,
        textStyle: SDUITextStyle? = nil,
        color: SDUIColorToken? = nil,
        maxLines: Int? = nil,
        gap: SDUISpacingToken? = nil,
        paddingX: SDUISpacingToken? = nil,
        alignment: SDUIAlignment? = nil,
        imageURL: String? = nil,
        alt: String? = nil,
        aspectRatio: Double? = nil,
        label: String? = nil,
        tone: SDUIButtonTone? = nil,
        variant: SDUIButtonVariant? = nil,
        size: SDUIButtonSize? = nil,
        accessibilityLabel: String? = nil
    ) {
        self.text = text
        self.textStyle = textStyle
        self.color = color
        self.maxLines = maxLines
        self.gap = gap
        self.paddingX = paddingX
        self.alignment = alignment
        self.imageURL = imageURL
        self.alt = alt
        self.aspectRatio = aspectRatio
        self.label = label
        self.tone = tone
        self.variant = variant
        self.size = size
        self.accessibilityLabel = accessibilityLabel
    }
}

struct SDUINode: Content, Sendable {
    let id: String
    let type: SDUIComponentType
    let props: SDUIProps
    let children: [SDUINode]?
    let action: SDUIAction?

    init(
        id: String,
        type: SDUIComponentType,
        props: SDUIProps = .init(),
        children: [SDUINode]? = nil,
        action: SDUIAction? = nil
    ) {
        self.id = id
        self.type = type
        self.props = props
        self.children = children
        self.action = action
    }
}

enum SDUITextStyle: String, Content, Sendable {
    case body = "t4Regular"
    case bodyEmphasis = "t4Bold"
    case title = "t7Bold"
    case heading = "t8Bold"
}

/// 화면 payload가 참조할 수 있는 semantic color만 노출한다.
enum SDUIColorToken: String, Content, Sendable {
    case neutral = "fg.neutral"
    case neutralMuted = "fg.neutralMuted"
    case brand = "fg.brand"
    case critical = "fg.critical"
}

enum SDUISpacingToken: String, Content, Sendable {
    case x1
    case x2
    case x3
    case x4
    case x6
    case componentDefault = "spacingY.componentDefault"
    case globalGutter = "spacingX.globalGutter"
}

enum SDUIAlignment: String, Content, Sendable {
    case start
    case center
    case end
    case stretch
}

enum SDUIButtonTone: String, Content, Sendable {
    case brand
    case neutral
    case danger
}

enum SDUIButtonVariant: String, Content, Sendable {
    case solid
    case weak
    case outline
    case ghost
}

enum SDUIButtonSize: String, Content, Sendable {
    case small
    case medium
    case large
}

struct SDUIAction: Content, Sendable {
    let type: SDUIActionType
    let target: String?
    let actionID: String?

    static func navigate(to target: String) -> SDUIAction {
        .init(type: .navigate, target: target, actionID: nil)
    }

    static func invoke(_ actionID: String) -> SDUIAction {
        .init(type: .invoke, target: nil, actionID: actionID)
    }
}

enum SDUIActionType: String, Content, Sendable {
    case navigate
    case invoke
}

/// Theme는 화면 문서와 독립적으로 revision을 갖고 캐시된다.
struct SDUIThemeDocument: Content, Sendable {
    let schemaVersion: Int
    let id: String
    let revision: Int
    let baseThemeID: String
    let modes: SDUIThemeModes

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case id
        case revision
        case baseThemeID = "extends"
        case modes
    }
}

struct SDUIThemeModes: Content, Sendable {
    let light: SDUIBrandColors
    let dark: SDUIBrandColors
}

/// SEED semantic color에 연결되는 프로젝트별 브랜드 색상 집합.
struct SDUIBrandColors: Content, Sendable {
    let brandSolid: String
    let brandSolidPressed: String
    let brandWeak: String
    let brandWeakPressed: String
    let foregroundBrand: String
    let foregroundOnBrand: String
}
