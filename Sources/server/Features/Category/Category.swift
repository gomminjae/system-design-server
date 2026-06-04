import Fluent
import struct Foundation.UUID
import struct Foundation.Date

/// 통(Tong) 디스커버리 카테고리(주제축). 시드로 채워지고 어드민이 관리한다.
/// 통의 `category` 필드는 이 테이블의 `slug`를 참조한다.
final class Category: Model, @unchecked Sendable {
    static let schema = "categories"

    @ID(key: .id)
    var id: UUID?

    /// 기계용 키. 통.category가 이 값을 참조. (예: "personality")
    @Field(key: "slug")
    var slug: String

    /// 표시명. (예: "성격·심리")
    @Field(key: "name")
    var name: String

    /// 이모지/아이콘. (예: "🧠")
    @OptionalField(key: "emoji")
    var emoji: String?

    /// 노출 순서. 작을수록 앞.
    @Field(key: "sort_order")
    var sortOrder: Int

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        slug: String,
        name: String,
        emoji: String? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.slug = slug
        self.name = name
        self.emoji = emoji
        self.sortOrder = sortOrder
    }

    func toDTO() -> CategoryDTO {
        .init(slug: self.slug, name: self.name, emoji: self.emoji)
    }
}
