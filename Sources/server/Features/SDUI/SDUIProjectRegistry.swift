import Foundation

struct SDUIProjectDefinition: Sendable {
    let id: String
    let catalogVersion: String
    let theme: SDUIThemeDocument
    let screens: [String: SDUIScreen]
}

/// v1 저장소. 계약이 안정되기 전까지 DB/CMS 대신 코드로 정의해 변경을 추적한다.
enum SDUIProjectRegistry {
    static func project(id: String) -> SDUIProjectDefinition? {
        switch id {
        case demo.id:
            demo
        default:
            nil
        }
    }

    private static let demo = SDUIProjectDefinition(
        id: "demo",
        catalogVersion: "seed-mobile-v1",
        theme: SDUIThemeDocument(
            schemaVersion: 1,
            id: "demo-purple",
            revision: 1,
            baseThemeID: "seed-default",
            modes: .init(
                light: .init(
                    brandSolid: "#7057E8",
                    brandSolidPressed: "#5C43CC",
                    brandWeak: "#F0EDFF",
                    brandWeakPressed: "#DED7FF",
                    foregroundBrand: "#6046D5",
                    foregroundOnBrand: "#FFFFFF"
                ),
                dark: .init(
                    brandSolid: "#927EFF",
                    brandSolidPressed: "#806AEF",
                    brandWeak: "#28213F",
                    brandWeakPressed: "#352A55",
                    foregroundBrand: "#A99AFF",
                    foregroundOnBrand: "#171321"
                )
            )
        ),
        screens: [
            "home": SDUIScreen(
                id: "home",
                revision: 1,
                fallback: .init(type: .native, target: "home"),
                root: SDUINode(
                    id: "root",
                    type: .vStack,
                    props: .init(
                        gap: .x4,
                        paddingX: .globalGutter,
                        alignment: .stretch
                    ),
                    children: [
                        SDUINode(
                            id: "title",
                            type: .text,
                            props: .init(
                                text: "범용 SDUI",
                                textStyle: .heading,
                                color: .neutral
                            )
                        ),
                        SDUINode(
                            id: "description",
                            type: .text,
                            props: .init(
                                text: "화면 구조와 브랜드 테마를 서버에서 전달합니다.",
                                textStyle: .body,
                                color: .neutralMuted,
                                maxLines: 3
                            )
                        ),
                        SDUINode(
                            id: "aboutButton",
                            type: .button,
                            props: .init(
                                label: "구성 알아보기",
                                tone: .brand,
                                variant: .solid,
                                size: .large
                            ),
                            action: .navigate(to: "about")
                        ),
                    ]
                )
            ),
            "about": SDUIScreen(
                id: "about",
                revision: 1,
                fallback: .init(type: .native, target: "about"),
                root: SDUINode(
                    id: "aboutRoot",
                    type: .vStack,
                    props: .init(
                        gap: .x3,
                        paddingX: .globalGutter,
                        alignment: .stretch
                    ),
                    children: [
                        SDUINode(
                            id: "aboutTitle",
                            type: .text,
                            props: .init(
                                text: "서비스와 디자인을 분리합니다",
                                textStyle: .title,
                                color: .neutral
                            )
                        ),
                        SDUINode(
                            id: "aboutBody",
                            type: .text,
                            props: .init(
                                text: "새 서비스는 프로젝트와 화면, 테마만 등록해서 시작할 수 있습니다.",
                                textStyle: .body,
                                color: .neutralMuted,
                                maxLines: 4
                            )
                        ),
                    ]
                )
            ),
        ]
    )
}
