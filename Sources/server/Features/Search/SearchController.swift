import Fluent
import Vapor

struct SuggestItem: Content {
    let id: UUID
    let title: String
    let releaseYear: Int
    let audienceCount: Int
}

struct SuggestResponse: Content {
    let query: String
    let suggestions: [SuggestItem]
}

struct SearchLogRequest: Content {
    let query: String
    let sessionID: String
    let clickedMovieID: UUID?
}

struct SearchLogResponse: Content {
    let id: UUID
}

struct SearchController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let search = routes.grouped("search")
        search.get("suggest", use: self.suggest)
        search.post("logs", use: self.logSearch)
    }

    /// GET /search/suggest?q=아이언&limit=10 — 제목 prefix 자동완성, 관객수 내림차순.
    @Sendable
    func suggest(req: Request) async throws -> APIResponse<SuggestResponse> {
        let raw = req.query[String.self, at: "q"] ?? ""
        let q = raw.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else {
            throw APIError.validation("q 파라미터가 필요합니다.")
        }
        let limit = min(max(req.query[Int.self, at: "limit"] ?? 10, 1), 20)

        // ponytail: v1은 LIKE 'q%' 시퀀셜 스캔 — 수만 행까진 충분. 느려지면 text_pattern_ops 인덱스가 다음 단계.
        let movies = try await Movie.query(on: req.db)
            .filter(\.$title =~ q)
            .sort(\.$audienceCount, .descending)
            .limit(limit)
            .all()

        return APIResponse(SuggestResponse(
            query: q,
            suggestions: try movies.map {
                SuggestItem(id: try $0.requireID(), title: $0.title,
                            releaseYear: $0.releaseYear, audienceCount: $0.audienceCount)
            }
        ))
    }

    /// POST /search/logs — 검색 "확정"(엔터/결과 탭) 시점에만 적재. suggest 타이핑 중간값은 로그 오염이라 안 쌓는다.
    @Sendable
    func logSearch(req: Request) async throws -> APIResponse<SearchLogResponse> {
        let body = try req.content.decode(SearchLogRequest.self)
        let query = body.query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else {
            throw APIError.validation("query가 비어 있습니다.")
        }
        let log = SearchLog(query: query, sessionID: body.sessionID, clickedMovieID: body.clickedMovieID)
        try await log.save(on: req.db)
        return APIResponse(SearchLogResponse(id: try log.requireID()))
    }
}
