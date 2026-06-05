import Fluent
import Vapor

/// 어드민 카드뉴스 관리 — CRUD + 발행. (BasicAuth 그룹 하위에 등록)
/// 페이지는 id 보존 diff-merge로 저장해 수정/재정렬 시 페이지 정체성을 유지한다.
struct CardNewsAdminController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let group = routes.grouped("admin", "api", "card-news")
        group.get(use: self.list)
        group.post(use: self.upsert)
        group.get(":cardNewsID", use: self.get)
        group.put(":cardNewsID", "publish", use: self.publish)
        group.delete(":cardNewsID", use: self.delete)
    }

    /// GET /admin/api/card-news — 전체(상태 무관) 목록.
    @Sendable
    func list(req: Request) async throws -> APIResponse<[CardNewsAdminListItem]> {
        let rows = try await CardNews.query(on: req.db)
            .sort(\.$createdAt, .descending)
            .all()
        return APIResponse(rows.map { $0.toAdminListItem() })
    }

    /// GET /admin/api/card-news/:id — 상세(상태 무관, 페이지 포함).
    @Sendable
    func get(req: Request) async throws -> APIResponse<CardNewsDetailDTO> {
        let id = try req.parameters.require("cardNewsID", as: UUID.self)
        guard let cardNews = try await CardNews.query(on: req.db)
            .filter(\.$id == id)
            .with(\.$pages)
            .first() else {
            throw APIError.notFound("카드뉴스를 찾을 수 없습니다.")
        }
        return APIResponse(cardNews.toDetail())
    }

    /// POST /admin/api/card-news — 생성/수정 (카드뉴스 + 페이지 일괄, 트랜잭션).
    @Sendable
    func upsert(req: Request) async throws -> APIResponse<CardNewsDetailDTO> {
        let body = try req.content.decode(CardNewsUpsertRequest.self)
        guard try await req.categoryService.exists(slug: body.category) else {
            throw APIError.validation("존재하지 않는 카테고리입니다: \(body.category)")
        }

        let cardNewsID = try await req.db.transaction { tx -> UUID in
            // 1) 카드뉴스 본체 (find or create)
            let cardNews: CardNews
            if let id = body.id, let existing = try await CardNews.find(id, on: tx) {
                cardNews = existing
            } else {
                cardNews = CardNews(title: body.title, category: body.category)
            }
            cardNews.title = body.title
            cardNews.subtitle = body.subtitle
            cardNews.thumbnailURL = body.thumbnailURL
            cardNews.category = body.category
            cardNews.isSponsored = body.isSponsored
            cardNews.sponsorName = body.sponsorName
            cardNews.sponsorLink = body.sponsorLink
            cardNews.isPremium = body.isPremium
            cardNews.pageCount = body.pages.count
            try await cardNews.save(on: tx)
            let id = try cardNews.requireID()

            // 2) 페이지 id 보존 diff-merge (배열 순서 = page_index)
            let existing = try await CardNewsPage.query(on: tx)
                .filter(\.$cardNews.$id == id)
                .all()
            let existingByID = Dictionary(
                existing.compactMap { page in page.id.map { ($0, page) } },
                uniquingKeysWith: { first, _ in first }
            )
            var keptIDs = Set<UUID>()

            for (index, input) in body.pages.enumerated() {
                if let pid = input.id, let page = existingByID[pid] {
                    page.pageIndex = index
                    page.imageURL = input.imageURL
                    page.title = input.title
                    page.body = input.body
                    page.bgColor = input.bgColor
                    try await page.save(on: tx)
                    keptIDs.insert(pid)
                } else {
                    try await CardNewsPage(
                        cardNewsID: id, pageIndex: index, imageURL: input.imageURL,
                        title: input.title, body: input.body, bgColor: input.bgColor
                    ).save(on: tx)
                }
            }
            // 3) 요청에 없는 기존 페이지는 삭제
            for page in existing where !(page.id.map { keptIDs.contains($0) } ?? false) {
                try await page.delete(on: tx)
            }
            return id
        }

        guard let saved = try await CardNews.query(on: req.db)
            .filter(\.$id == cardNewsID).with(\.$pages).first() else {
            throw APIError.notFound("저장된 카드뉴스를 찾을 수 없습니다.")
        }
        return APIResponse(saved.toDetail())
    }

    /// PUT /admin/api/card-news/:id/publish — 발행/비발행 토글.
    @Sendable
    func publish(req: Request) async throws -> APIResponse<CardNewsAdminListItem> {
        let id = try req.parameters.require("cardNewsID", as: UUID.self)
        guard let cardNews = try await CardNews.find(id, on: req.db) else {
            throw APIError.notFound("카드뉴스를 찾을 수 없습니다.")
        }
        cardNews.status = cardNews.status == .published ? .draft : .published
        try await cardNews.save(on: req.db)
        return APIResponse(cardNews.toAdminListItem())
    }

    /// DELETE /admin/api/card-news/:id — 삭제 (페이지는 FK CASCADE로 함께 삭제).
    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        let id = try req.parameters.require("cardNewsID", as: UUID.self)
        guard let cardNews = try await CardNews.find(id, on: req.db) else {
            throw APIError.notFound("카드뉴스를 찾을 수 없습니다.")
        }
        try await cardNews.delete(on: req.db)
        return .noContent
    }
}

// MARK: - Admin DTOs

struct CardNewsUpsertRequest: Content {
    var id: UUID?
    var title: String
    var subtitle: String?
    var thumbnailURL: String?
    var category: String
    var isSponsored: Bool
    var sponsorName: String?
    var sponsorLink: String?
    var isPremium: Bool
    var pages: [CardNewsPageInput]
}

/// 페이지 입력. id가 있으면 기존 페이지 수정, 없으면 신규. 순서는 배열 인덱스.
struct CardNewsPageInput: Content {
    var id: UUID?
    var imageURL: String
    var title: String?
    var body: String?
    var bgColor: String?
}

struct CardNewsAdminListItem: Content {
    var id: UUID?
    var title: String
    var category: String
    var status: CardNewsStatus
    var pageCount: Int
    var isSponsored: Bool
    var isPremium: Bool
    var updatedAt: Date?
}

extension CardNews {
    func toAdminListItem() -> CardNewsAdminListItem {
        .init(
            id: self.id,
            title: self.title,
            category: self.category,
            status: self.status,
            pageCount: self.pageCount,
            isSponsored: self.isSponsored,
            isPremium: self.isPremium,
            updatedAt: self.updatedAt
        )
    }
}
