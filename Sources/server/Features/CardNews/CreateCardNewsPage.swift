import Fluent

struct CreateCardNewsPage: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("card_news_pages")
            .id()
            // 부모 삭제 시 페이지도 삭제(CASCADE). 생성 시점 FK라 SQLite·Postgres 모두 동작.
            .field("card_news_id", .uuid, .required,
                   .references("card_news", "id", onDelete: .cascade))
            .field("page_index", .int, .required)
            .field("image_url", .string, .required)
            .field("title", .string)
            .field("body", .string)
            .field("bg_color", .string)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("card_news_pages").delete()
    }
}
