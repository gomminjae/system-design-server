import Fluent
import struct Foundation.UUID
import struct Foundation.Date

/// 카드뉴스 = 표지(메타) + 순서 있는 페이지 N장(@Children). 인스타 카드뉴스 형식.
/// 페이지는 항상 카드뉴스와 함께 다니지만, 각 페이지가 자기 id를 가져 수정/재정렬에 유리하다.
final class CardNews: Model, @unchecked Sendable {
    static let schema = "card_news"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "title")
    var title: String

    @OptionalField(key: "subtitle")
    var subtitle: String?

    /// 대표 이미지(목록용). 비면 첫 페이지 이미지로 폴백(서비스에서 처리).
    @OptionalField(key: "thumbnail_url")
    var thumbnailURL: String?

    /// 카테고리 slug (personality, love ...). Tong과 동일 카테고리 재사용.
    @Field(key: "category")
    var category: String

    @Field(key: "market")
    var market: Market

    @Field(key: "status")
    var status: CardNewsStatus

    /// 페이지 수(역정규화). 목록에서 N+1 없이 노출하려고 쓰기 시점에 갱신.
    @Field(key: "page_count")
    var pageCount: Int

    // 수익화-레디 훅 (데이터만, 로직 없음)
    @Field(key: "is_sponsored")
    var isSponsored: Bool

    @OptionalField(key: "sponsor_name")
    var sponsorName: String?

    @OptionalField(key: "sponsor_link")
    var sponsorLink: String?

    @Field(key: "is_premium")
    var isPremium: Bool

    /// 카드뉴스의 페이지들. 상세 조회 시 `.with(\.$pages)`로 eager load.
    @Children(for: \.$cardNews)
    var pages: [CardNewsPage]

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        title: String,
        subtitle: String? = nil,
        thumbnailURL: String? = nil,
        category: String,
        market: Market = .ko,
        status: CardNewsStatus = .draft,
        pageCount: Int = 0,
        isSponsored: Bool = false,
        sponsorName: String? = nil,
        sponsorLink: String? = nil,
        isPremium: Bool = false
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.thumbnailURL = thumbnailURL
        self.category = category
        self.market = market
        self.status = status
        self.pageCount = pageCount
        self.isSponsored = isSponsored
        self.sponsorName = sponsorName
        self.sponsorLink = sponsorLink
        self.isPremium = isPremium
    }
}
