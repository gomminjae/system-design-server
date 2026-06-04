@testable import server
import VaporTesting
import Testing
import Fluent
import JWT

@Suite("App Tests with DB", .serialized)
struct serverTests {
    private func withApp(_ test: (Application) async throws -> ()) async throws {
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

    /// 테스트용 인증 유저 생성 + Bearer 토큰 발급.
    private func makeAuthenticatedUser(_ app: Application) async throws -> (user: User, token: String) {
        let user = User(provider: "apple", providerID: "test-sub-\(UUID())", nickname: "tester")
        try await user.save(on: app.db)
        let token = try await app.jwt.keys.sign(
            UserJWTPayload(
                subject: .init(value: user.id!.uuidString),
                expiration: .init(value: .distantFuture)
            )
        )
        return (user, token)
    }

    @Test("Health check")
    func healthCheck() async throws {
        try await withApp { app in
            try await app.testing().test(.GET, "health", afterResponse: { res async in
                #expect(res.status == .ok)
                #expect(res.body.string == "ok")
            })
        }
    }

    @Test("Catalog returns empty array initially")
    func catalogEmpty() async throws {
        try await withApp { app in
            try await app.testing().test(.GET, "catalog", afterResponse: { res async throws in
                #expect(res.status == .ok)
                let body = try res.content.decode(APIResponse<CursorList<TongDTO>>.self)
                #expect(body.data.items.isEmpty)
                #expect(body.data.hasMore == false)
            })
        }
    }

    @Test("Categories are seeded")
    func categoriesSeeded() async throws {
        try await withApp { app in
            try await app.testing().test(.GET, "categories", afterResponse: { res async throws in
                #expect(res.status == .ok)
                let body = try res.content.decode(APIResponse<[CategoryDTO]>.self)
                #expect(body.data.count == 8)
                #expect(body.data.first?.slug == "personality")
                #expect(body.data.contains { $0.slug == "cardnews" })
            })
        }
    }

    @Test("Submit without auth is rejected")
    func submitRequiresAuth() async throws {
        try await withApp { app in
            try await app.testing().test(.POST, "submissions", beforeRequest: { req in
                try req.content.encode(Self.sampleSubmission)
            }, afterResponse: { res async in
                #expect(res.status == .unauthorized)
            })
        }
    }

    @Test("Submit a tong")
    func submitTong() async throws {
        try await withApp { app in
            let (_, token) = try await makeAuthenticatedUser(app)
            try await app.testing().test(.POST, "submissions", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
                try req.content.encode(Self.sampleSubmission)
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
                let body = try res.content.decode(APIResponse<TongDTO>.self)
                #expect(body.data.title == "Test Tong")
                #expect(body.data.status == .submitted)
            })
        }
    }

    @Test("Submit with unknown category is rejected")
    func submitUnknownCategory() async throws {
        try await withApp { app in
            let (_, token) = try await makeAuthenticatedUser(app)
            var submission = Self.sampleSubmission
            submission.category = "does-not-exist"
            try await app.testing().test(.POST, "submissions", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
                try req.content.encode(submission)
            }, afterResponse: { res async in
                #expect(res.status == .badRequest)
            })
        }
    }

    @Test("My submissions returns only the owner's tongs")
    func mySubmissions() async throws {
        try await withApp { app in
            let (_, tokenA) = try await makeAuthenticatedUser(app)
            let (_, tokenB) = try await makeAuthenticatedUser(app)

            // A가 통 1개 제출
            try await app.testing().test(.POST, "submissions", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: tokenA)
                try req.content.encode(Self.sampleSubmission)
            }, afterResponse: { res async in
                #expect(res.status == .ok)
            })

            // A의 목록엔 1개
            try await app.testing().test(.GET, "submissions", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: tokenA)
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
                let body = try res.content.decode(APIResponse<[TongDTO]>.self)
                #expect(body.data.count == 1)
                #expect(body.data.first?.title == "Test Tong")
            })

            // B의 목록엔 0개 (소유자 격리)
            try await app.testing().test(.GET, "submissions", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: tokenB)
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
                let body = try res.content.decode(APIResponse<[TongDTO]>.self)
                #expect(body.data.isEmpty)
            })
        }
    }

    @Test("Screen resolves dynamic tong_list and category chips")
    func screenDynamicBinding() async throws {
        try await withApp { app in
            // 승인된 personality 통 1개
            let tong = Tong(
                type: "quiz", title: "성격테스트", subtitle: "재밌음",
                thumbURL: "https://img/x.png", bundleURL: "https://b/x",
                version: "1.0", category: "personality", ageRating: "all", status: .approved
            )
            try await tong.save(on: app.db)

            // tong_list(동적 categorySlug) + category_chips 섹션을 가진 발행 화면
            let sectionsJSON = """
            [
              {"id":"s1","type":"tong_list","data":{"headerTitle":"성격","categorySlug":"personality","limit":5}},
              {"id":"s2","type":"category_chips","data":{}}
            ]
            """
            let screen = Screen(screenId: "home", title: "홈", sectionsJSON: sectionsJSON, isPublished: true)
            try await screen.save(on: app.db)

            try await app.testing().test(.GET, "screens/home", afterResponse: { res async throws in
                #expect(res.status == .ok)
                let body = try res.content.decode(APIResponse<ScreenResponse>.self).data

                // 스키마 버전 노출
                #expect(body.schemaVersion == SDUISchema.version)

                // tong_list가 카탈로그에서 실시간으로 채워졌는지
                let list = body.sections.first { $0.type == .tongList }
                #expect(list?.data.items?.count == 1)
                #expect(list?.data.items?.first?.title == "성격테스트")

                // category_chips가 DB로 채워졌는지 ("전체" + 카테고리들)
                let chips = body.sections.first { $0.type == .categoryChips }
                #expect(chips?.data.chips?.first?.id == "all")
                #expect(chips?.data.chips?.contains { $0.id == "personality" } == true)
                #expect(chips?.data.selectedId == "all")
            })
        }
    }

    private static let sampleSubmission = TongSubmission(
        type: "quiz",
        title: "Test Tong",
        subtitle: nil,
        thumbURL: nil,
        bundleURL: "https://example.com",
        version: "1.0.0",
        category: "personality",
        ageRating: "all",
        submitterContact: "test@example.com"
    )
}
