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
                #expect(body.data.count == 7)
                #expect(body.data.first?.slug == "personality")
                #expect(body.data.contains { $0.slug == "cardnews" } == false)  // 카드뉴스는 독립 타입
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

    @Test("Card-news list and detail (paging, page order, thumbnail fallback)")
    func cardNews() async throws {
        try await withApp { app in
            // 발행 카드뉴스 + 페이지 2장(일부러 역순 저장 → 정렬 검증). thumbnail 없음 → 첫 페이지 폴백
            let cn = CardNews(title: "MBTI 연애", category: "love", status: .published,
                              pageCount: 2, isSponsored: true, sponsorName: "어떤브랜드")
            try await cn.save(on: app.db)
            try await CardNewsPage(cardNewsID: cn.id!, pageIndex: 1, imageURL: "https://i/1", title: "INTJ").save(on: app.db)
            try await CardNewsPage(cardNewsID: cn.id!, pageIndex: 0, imageURL: "https://i/0", title: "ENFP").save(on: app.db)
            // 미발행은 노출 안 됨
            let draft = CardNews(title: "초안", category: "love", status: .draft)
            try await draft.save(on: app.db)

            // 목록 — 발행본 1개, pageCount·스폰서 플래그
            try await app.testing().test(.GET, "card-news", afterResponse: { res async throws in
                #expect(res.status == .ok)
                let body = try res.content.decode(APIResponse<CursorList<CardNewsListItem>>.self).data
                #expect(body.items.count == 1)
                #expect(body.items.first?.pageCount == 2)
                #expect(body.items.first?.isSponsored == true)
                #expect(body.items.first?.sponsorName == "어떤브랜드")
            })

            // 상세 — 페이지 정렬(0,1) + 썸네일 폴백(첫 페이지 이미지)
            try await app.testing().test(.GET, "card-news/\(cn.id!)", afterResponse: { res async throws in
                #expect(res.status == .ok)
                let body = try res.content.decode(APIResponse<CardNewsDetailDTO>.self).data
                #expect(body.pages.count == 2)
                #expect(body.pages.first?.pageIndex == 0)
                #expect(body.pages.first?.title == "ENFP")
                #expect(body.thumbnailURL == "https://i/0")   // 폴백
            })

            // 미발행 상세 → 404
            try await app.testing().test(.GET, "card-news/\(draft.id!)", afterResponse: { res async in
                #expect(res.status == .notFound)
            })
        }
    }

    @Test("Card-news admin CRUD with page id-preserving diff-merge")
    func cardNewsAdmin() async throws {
        try await withApp { app in
            let basic = BasicAuthorization(username: "admin", password: "dev-password")

            // 1) 생성 (페이지 2장)
            var createdID: UUID!
            var page0ID: UUID!
            try await app.testing().test(.POST, "admin/api/card-news", beforeRequest: { req in
                req.headers.basicAuthorization = basic
                try req.content.encode(CardNewsUpsertRequest(
                    id: nil, title: "MBTI 연애", subtitle: nil, thumbnailURL: nil,
                    category: "love", isSponsored: false, sponsorName: nil, sponsorLink: nil, isPremium: false,
                    pages: [
                        CardNewsPageInput(id: nil, imageURL: "https://i/0", title: "ENFP", body: nil, bgColor: nil),
                        CardNewsPageInput(id: nil, imageURL: "https://i/1", title: "INTJ", body: nil, bgColor: nil),
                    ]
                ))
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
                let body = try res.content.decode(APIResponse<CardNewsDetailDTO>.self).data
                #expect(body.pages.count == 2)
                createdID = body.id
                let saved = try await CardNewsPage.query(on: app.db)
                    .filter(\.$cardNews.$id == createdID).sort(\.$pageIndex).all()
                page0ID = saved.first?.id
            })

            // 2) 수정 — 0번 페이지는 id 유지하며 텍스트 변경, 1번 삭제, 새 페이지 추가
            try await app.testing().test(.POST, "admin/api/card-news", beforeRequest: { req in
                req.headers.basicAuthorization = basic
                try req.content.encode(CardNewsUpsertRequest(
                    id: createdID, title: "MBTI 연애(수정)", subtitle: nil, thumbnailURL: nil,
                    category: "love", isSponsored: false, sponsorName: nil, sponsorLink: nil, isPremium: false,
                    pages: [
                        CardNewsPageInput(id: page0ID, imageURL: "https://i/0", title: "ENFP 수정", body: nil, bgColor: nil),
                        CardNewsPageInput(id: nil, imageURL: "https://i/new", title: "NEW", body: nil, bgColor: nil),
                    ]
                ))
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
                let body = try res.content.decode(APIResponse<CardNewsDetailDTO>.self).data
                #expect(body.title == "MBTI 연애(수정)")
                #expect(body.pages.count == 2)
                #expect(body.pages.first?.title == "ENFP 수정")
                // 0번 페이지 id가 보존됐는지
                let kept = try await CardNewsPage.query(on: app.db)
                    .filter(\.$cardNews.$id == createdID).filter(\.$pageIndex == 0).first()
                #expect(kept?.id == page0ID)
            })

            // 3) 발행 전엔 공개 목록에 안 보임
            try await app.testing().test(.GET, "card-news", afterResponse: { res async throws in
                let body = try res.content.decode(APIResponse<CursorList<CardNewsListItem>>.self).data
                #expect(body.items.isEmpty)
            })

            // 4) 발행 토글 → 공개 노출
            try await app.testing().test(.PUT, "admin/api/card-news/\(createdID!)/publish", beforeRequest: { req in
                req.headers.basicAuthorization = basic
            }, afterResponse: { res async in #expect(res.status == .ok) })
            try await app.testing().test(.GET, "card-news", afterResponse: { res async throws in
                let body = try res.content.decode(APIResponse<CursorList<CardNewsListItem>>.self).data
                #expect(body.items.count == 1)
            })

            // 5) 삭제 → 페이지도 함께 사라짐(CASCADE)
            try await app.testing().test(.DELETE, "admin/api/card-news/\(createdID!)", beforeRequest: { req in
                req.headers.basicAuthorization = basic
            }, afterResponse: { res async in #expect(res.status == .noContent) })
            let remaining = try await CardNewsPage.query(on: app.db)
                .filter(\.$cardNews.$id == createdID).count()
            #expect(remaining == 0)
        }
    }

    @Test("Screen resolves dynamic tong_list and category chips")
    func screenDynamicBinding() async throws {
        try await withApp { app in
            // 승인된 personality 통 1개
            let tong = Tong(
                type: "quiz", title: "성격테스트", subtitle: "재밌음",
                thumbnailURL: "https://img/x.png", bundleURL: "https://b/x",
                version: "1.0", category: "personality", ageRating: "all", status: .approved
            )
            try await tong.save(on: app.db)

            // 발행 카드뉴스 1개(love, 3페이지)
            let cn = CardNews(title: "MBTI 카드뉴스", category: "love", status: .published, pageCount: 3)
            try await cn.save(on: app.db)

            // tong_list + category_chips + card_news_list 섹션을 가진 발행 화면
            let sectionsJSON = """
            [
              {"id":"s1","type":"tong_list","data":{"headerTitle":"성격","categorySlug":"personality","limit":5}},
              {"id":"s2","type":"category_chips","data":{}},
              {"id":"s3","type":"card_news_list","data":{"headerTitle":"오늘의 카드뉴스","categorySlug":"love","limit":5}}
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

                // card_news_list가 발행 카드뉴스로 채워졌는지
                let cnList = body.sections.first { $0.type == .cardNewsList }
                #expect(cnList?.data.cardNewsItems?.count == 1)
                #expect(cnList?.data.cardNewsItems?.first?.title == "MBTI 카드뉴스")
                #expect(cnList?.data.cardNewsItems?.first?.pageCount == 3)
            })
        }
    }

    private static let sampleSubmission = TongSubmission(
        type: "quiz",
        title: "Test Tong",
        subtitle: nil,
        thumbnailURL: nil,
        bundleURL: "https://example.com",
        version: "1.0.0",
        category: "personality",
        ageRating: "all",
        submitterContact: "test@example.com"
    )
}
