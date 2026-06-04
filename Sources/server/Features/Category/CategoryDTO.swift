import Vapor

/// API로 나가는 카테고리 표현. (slug + 표시명 + 이모지)
struct CategoryDTO: Content {
    var slug: String
    var name: String
    var emoji: String?
}
