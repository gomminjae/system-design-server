@testable import server
import Fluent
import Testing
import VaporTesting
import Foundation

@Suite("SDUI Tests", .serialized)
struct SDUITests {
    private var adminHeaders: HTTPHeaders {
        var headers = HTTPHeaders()
        headers.basicAuthorization = .init(
            username: Environment.get("ADMIN_USER") ?? "admin",
            password: Environment.get("ADMIN_PASSWORD") ?? "dev-password"
        )
        headers.contentType = .json
        return headers
    }

    private func withApp(_ test: (Application) async throws -> Void) async throws {
        let app = try await Application.make(.testing)
        do {
            try await configure(app)
            try await app.autoMigrate()
            try await test(app)
            try await app.autoRevert()
        } catch {
            try? await app.autoRevert()
            try await app.asyncShutdown()
            throw error
        }
        try await app.asyncShutdown()
    }

    @Test("프로젝트 화면 문서를 조회한다")
    func getScreen() async throws {
        try await withApp { app in
            try await app.testing().test(
                .GET,
                "v1/projects/demo/screens/home",
                beforeRequest: { req in
                    req.headers.add(
                        name: .init("X-SDUI-Catalog-Version"),
                        value: "seed-mobile-v1"
                    )
                },
                afterResponse: { res async throws in
                    #expect(res.status == .ok)
                    let document = try res.content.decode(APIResponse<SDUIScreenDocument>.self).data
                    #expect(document.protocolVersion == 1)
                    #expect(document.catalogVersion == "seed-mobile-v1")
                    #expect(document.theme.id == "demo-purple")
                    #expect(document.screen.id == "home")
                    #expect(document.screen.root.type == .vStack)
                    #expect(document.screen.root.children?.count == 3)
                }
            )
        }
    }

    @Test("프로젝트 테마는 SEED 기본 테마를 확장한다")
    func getTheme() async throws {
        try await withApp { app in
            try await app.testing().test(
                .GET,
                "v1/projects/demo/theme",
                afterResponse: { res async throws in
                    #expect(res.status == .ok)
                    let theme = try res.content.decode(APIResponse<SDUIThemeDocument>.self).data
                    #expect(theme.baseThemeID == "seed-default")
                    #expect(theme.modes.light.brandSolid == "#7057E8")
                    #expect(theme.modes.dark.brandSolid == "#927EFF")
                }
            )
        }
    }

    @Test("지원하지 않는 컴포넌트 카탈로그를 거절한다")
    func rejectUnsupportedCatalog() async throws {
        try await withApp { app in
            try await app.testing().test(
                .GET,
                "v1/projects/demo/screens/home",
                beforeRequest: { req in
                    req.headers.add(
                        name: .init("X-SDUI-Catalog-Version"),
                        value: "unknown-v1"
                    )
                },
                afterResponse: { res async throws in
                    #expect(res.status == .preconditionFailed)
                    let error = try res.content.decode(APIErrorResponse.self)
                    #expect(error.error.code == "unsupported_sdui_catalog")
                }
            )
        }
    }

    @Test("중복 노드 ID를 거절한다")
    func rejectDuplicateNodeID() throws {
        let duplicateText = SDUINode(
            id: "duplicate",
            type: .text,
            props: .init(text: "텍스트", textStyle: .body, color: .neutral)
        )
        let document = SDUIScreenDocument(
            protocolVersion: 1,
            catalogVersion: "seed-mobile-v1",
            theme: .init(id: "test-theme", revision: 1),
            screen: .init(
                id: "test",
                revision: 1,
                fallback: .init(type: .native, target: "test"),
                root: .init(
                    id: "root",
                    type: .vStack,
                    children: [duplicateText, duplicateText]
                )
            )
        )

        #expect(throws: SDUIValidationError.self) {
            try SDUIScreenValidator().validate(document)
        }
    }

    @Test("CMS가 화면을 저장하고 발행하면 공개 SDUI API가 최신 revision을 전달한다")
    func cmsDraftPublishAndDelivery() async throws {
        try await withApp { app in
            let screen = SDUIScreen(
                id: "landing",
                revision: 1,
                fallback: .init(type: .native, target: "landing"),
                root: .init(
                    id: "root",
                    type: .vStack,
                    props: .init(gap: .x3, alignment: .stretch),
                    children: [
                        .init(id: "title", type: .text, props: .init(text: "CMS 화면", textStyle: .heading, color: .neutral))
                    ]
                )
            )
            try await app.testing().test(
                .PUT,
                "admin/sdui/projects/cms-demo",
                headers: adminHeaders,
                beforeRequest: { req in
                    req.headers.contentType = .json
                    try req.content.encode(SDUICMSProjectRequest(catalogVersion: "seed-mobile-v1"))
                },
                afterResponse: { res async throws in
                    #expect(res.status == .ok)
                }
            )
            try await app.testing().test(
                .PUT,
                "admin/sdui/projects/cms-demo/screens/landing/draft",
                headers: adminHeaders,
                beforeRequest: { req in
                    req.headers.contentType = .json
                    try req.content.encode(SDUICMSScreenDraftRequest(catalogVersion: nil, screen: screen))
                },
                afterResponse: { res async throws in
                    #expect(res.status == .ok)
                    let summary = try res.content.decode(APIResponse<SDUICMSRevisionSummary>.self).data
                    #expect(summary.revision == 1)
                    #expect(summary.status == "draft")
                }
            )
            try await app.testing().test(
                .POST,
                "admin/sdui/projects/cms-demo/screens/landing/publish",
                headers: adminHeaders,
                beforeRequest: { req in
                    req.headers.contentType = .json
                    try req.content.encode(SDUICMSPublishRequest(revision: nil))
                },
                afterResponse: { res async throws in
                    #expect(res.status == .ok)
                    let summary = try res.content.decode(APIResponse<SDUICMSRevisionSummary>.self).data
                    #expect(summary.status == "published")
                }
            )
            try await app.testing().test(
                .GET,
                "v1/projects/cms-demo/screens/landing",
                beforeRequest: { req in
                    req.headers.add(name: .init("X-SDUI-Catalog-Version"), value: "seed-mobile-v1")
                },
                afterResponse: { res async throws in
                    #expect(res.status == .ok)
                    let document = try res.content.decode(APIResponse<SDUIScreenDocument>.self).data
                    #expect(document.screen.id == "landing")
                    #expect(document.screen.root.children?.first?.props.text == "CMS 화면")
                }
            )
            let v2 = SDUIScreen(
                id: "landing",
                revision: 2,
                fallback: .init(type: .native, target: "landing"),
                root: .init(
                    id: "root",
                    type: .vStack,
                    props: .init(gap: .x3, alignment: .stretch),
                    children: [
                        .init(id: "title", type: .text, props: .init(text: "CMS 화면 v2", textStyle: .heading, color: .neutral))
                    ]
                )
            )
            try await app.testing().test(
                .PUT,
                "admin/sdui/projects/cms-demo/screens/landing/draft",
                headers: adminHeaders,
                beforeRequest: { req in
                    req.headers.contentType = .json
                    try req.content.encode(SDUICMSScreenDraftRequest(catalogVersion: nil, screen: v2))
                },
                afterResponse: { res async in
                    #expect(res.status == .ok)
                }
            )
            try await app.testing().test(
                .POST,
                "admin/sdui/projects/cms-demo/screens/landing/publish",
                headers: adminHeaders,
                beforeRequest: { req in
                    req.headers.contentType = .json
                    try req.content.encode(SDUICMSPublishRequest(revision: nil))
                },
                afterResponse: { res async in
                    #expect(res.status == .ok)
                }
            )
            try await app.testing().test(
                .POST,
                "admin/sdui/projects/cms-demo/screens/landing/rollback",
                headers: adminHeaders,
                beforeRequest: { req in
                    req.headers.contentType = .json
                    try req.content.encode(SDUICMSPublishRequest(revision: 1))
                },
                afterResponse: { res async throws in
                    #expect(res.status == .ok)
                    let summary = try res.content.decode(APIResponse<SDUICMSRevisionSummary>.self).data
                    #expect(summary.revision == 1)
                    #expect(summary.status == "published")
                }
            )
            try await app.testing().test(
                .GET,
                "v1/projects/cms-demo/screens/landing",
                beforeRequest: { req in
                    req.headers.add(name: .init("X-SDUI-Catalog-Version"), value: "seed-mobile-v1")
                },
                afterResponse: { res async throws in
                    let document = try res.content.decode(APIResponse<SDUIScreenDocument>.self).data
                    #expect(document.screen.root.children?.first?.props.text == "CMS 화면")
                }
            )
        }
    }
}
