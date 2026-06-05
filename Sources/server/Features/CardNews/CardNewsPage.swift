import Fluent
import struct Foundation.UUID

/// 카드뉴스의 카드 한 장. 부모 CardNews에 1:N으로 속한다.
final class CardNewsPage: Model, @unchecked Sendable {
    static let schema = "card_news_pages"

    @ID(key: .id)
    var id: UUID?

    /// 부모 카드뉴스 (FK: card_news_id, 부모 삭제 시 CASCADE).
    @Parent(key: "card_news_id")
    var cardNews: CardNews

    /// 표시 순서 (0부터).
    @Field(key: "page_index")
    var pageIndex: Int

    @Field(key: "image_url")
    var imageURL: String

    @OptionalField(key: "title")
    var title: String?

    @OptionalField(key: "body")
    var body: String?

    /// 이미지 없을 때 배경색.
    @OptionalField(key: "bg_color")
    var bgColor: String?

    init() {}

    init(
        id: UUID? = nil,
        cardNewsID: UUID,
        pageIndex: Int,
        imageURL: String,
        title: String? = nil,
        body: String? = nil,
        bgColor: String? = nil
    ) {
        self.id = id
        self.$cardNews.id = cardNewsID
        self.pageIndex = pageIndex
        self.imageURL = imageURL
        self.title = title
        self.body = body
        self.bgColor = bgColor
    }
}
