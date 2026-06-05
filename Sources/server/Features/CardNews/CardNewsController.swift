import Vapor
import VaporToOpenAPI

/// 공개 카드뉴스 엔드포인트. 발행본만 노출.
struct CardNewsController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let cardNews = routes.grouped("card-news")
        cardNews.get(use: self.list)
            .openAPI(
                summary: "카드뉴스 목록",
                description: "발행된 카드뉴스를 최신순 커서 페이징으로 반환한다. (카테고리 필터 지원)",
                response: .type(APIResponse<CursorList<CardNewsListItem>>.self)
            )
        cardNews.get(":cardNewsID", use: self.detail)
            .openAPI(
                summary: "카드뉴스 상세",
                description: "카드뉴스 상세(페이지 전체 포함)를 반환한다. 미발행은 404.",
                response: .type(APIResponse<CardNewsDetailDTO>.self)
            )
    }

    @Sendable
    func list(req: Request) async throws -> APIResponse<CursorList<CardNewsListItem>> {
        let category = req.query[String.self, at: "category"]
        let after = req.query[String.self, at: "after"].flatMap { UUID(uuidString: $0) }
        let limit = min(req.query[Int.self, at: "limit"] ?? 20, 50)
        let result = try await req.cardNewsService.list(category: category, after: after, limit: limit)
        return APIResponse(result)
    }

    @Sendable
    func detail(req: Request) async throws -> APIResponse<CardNewsDetailDTO> {
        let id = try req.parameters.require("cardNewsID", as: UUID.self)
        let result = try await req.cardNewsService.detail(id)
        return APIResponse(result)
    }
}
