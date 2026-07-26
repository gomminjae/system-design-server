import Fluent
import Vapor

/// 검색 확정 로그 — 인기도 랭킹·연관검색어 집계의 원료.
/// suggest(자동완성) 호출은 적재하지 않는다. 타이핑 중간값("아", "아이")이 섞이면 집계가 오염된다.
final class SearchLog: Model, @unchecked Sendable {
    static let schema = "search_logs"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "query")
    var query: String

    /// 클라이언트가 만들어 보내는 세션 식별자. 연관검색어의 co-occurrence 묶음 단위.
    @Field(key: "session_id")
    var sessionID: String

    @OptionalField(key: "clicked_movie_id")
    var clickedMovieID: UUID?

    @Timestamp(key: "searched_at", on: .create)
    var searchedAt: Date?

    init() {}

    init(id: UUID? = nil, query: String, sessionID: String, clickedMovieID: UUID? = nil) {
        self.id = id
        self.query = query
        self.sessionID = sessionID
        self.clickedMovieID = clickedMovieID
    }
}
