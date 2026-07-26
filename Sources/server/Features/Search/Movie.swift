import Fluent
import Vapor

/// 검색 대상 카탈로그. 자동완성 실험용 코퍼스.
final class Movie: Model, @unchecked Sendable {
    static let schema = "movies"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "title")
    var title: String

    @OptionalField(key: "title_eng")
    var titleEng: String?

    @Field(key: "release_year")
    var releaseYear: Int

    /// 누적 관객수 — 검색 로그가 쌓이기 전 인기도 랭킹의 콜드스타트 초기값.
    @Field(key: "audience_count")
    var audienceCount: Int

    init() {}

    init(id: UUID? = nil, title: String, titleEng: String? = nil, releaseYear: Int, audienceCount: Int) {
        self.id = id
        self.title = title
        self.titleEng = titleEng
        self.releaseYear = releaseYear
        self.audienceCount = audienceCount
    }
}
