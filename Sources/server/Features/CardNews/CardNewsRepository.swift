import Fluent
import Vapor

/// 카드뉴스 데이터 접근 추상화.
protocol CardNewsRepository: Sendable {
    /// 발행된 카드뉴스 (최신순, 커서 페이징). limit+1을 가져와 hasMore 판정.
    func published(category: String?, market: Market, after: UUID?, limit: Int) async throws -> [CardNews]
    /// 발행된 카드뉴스 단건 + 페이지 eager load. 없으면 nil.
    func findPublished(_ id: UUID) async throws -> CardNews?
}

struct FluentCardNewsRepository: CardNewsRepository {
    let db: any Database

    func published(category: String?, market: Market, after cursor: UUID?, limit: Int) async throws -> [CardNews] {
        var query = CardNews.query(on: db)
            .filter(\.$status == .published)
            .filter(\.$market ~~ Market.queryValues(for: market))

        if let category {
            query = query.filter(\.$category == category)
        }

        if let cursor {
            guard let cursorRow = try await CardNews.find(cursor, on: db),
                  let cursorDate = cursorRow.createdAt else {
                throw APIError.validation("유효하지 않은 커서입니다.")
            }
            query = query.group(.or) { or in
                or.filter(\.$createdAt < cursorDate)
                or.group(.and) { and in
                    and.filter(\.$createdAt == cursorDate)
                    and.filter(\.$id < cursor)
                }
            }
        }

        return try await query
            .sort(\.$createdAt, .descending)
            .sort(\.$id, .descending)
            .limit(limit + 1)
            .all()
    }

    func findPublished(_ id: UUID) async throws -> CardNews? {
        try await CardNews.query(on: db)
            .filter(\.$id == id)
            .filter(\.$status == .published)
            .with(\.$pages)            // 페이지 한 방에 eager load (N+1 방지)
            .first()
    }
}
