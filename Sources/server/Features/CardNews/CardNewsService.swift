import Vapor

/// 카드뉴스 조회 비즈니스 로직. ProductService.catalog와 동일한 커서 페이징 구조.
struct CardNewsService {
    let repository: any CardNewsRepository

    func list(category: String?, market: Market, after: UUID?, limit: Int) async throws -> CursorList<CardNewsListItem> {
        let rows = try await repository.published(category: category, market: market, after: after, limit: limit)
        let hasMore = rows.count > limit
        let items = hasMore ? Array(rows.prefix(limit)) : rows
        let nextCursor = hasMore ? items.last?.id?.uuidString : nil
        return CursorList(items: items.map { $0.toListItem() }, nextCursor: nextCursor, hasMore: hasMore)
    }

    func detail(_ id: UUID) async throws -> CardNewsDetailDTO {
        guard let cardNews = try await repository.findPublished(id) else {
            throw APIError.notFound("카드뉴스를 찾을 수 없습니다.")
        }
        return cardNews.toDetail()
    }
}
