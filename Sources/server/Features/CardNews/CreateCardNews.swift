import Fluent

struct CreateCardNews: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("card_news")
            .id()
            .field("title", .string, .required)
            .field("subtitle", .string)
            .field("thumbnail_url", .string)
            .field("category", .string, .required)
            .field("status", .string, .required)
            .field("page_count", .int, .required)
            .field("is_sponsored", .bool, .required)
            .field("sponsor_name", .string)
            .field("sponsor_link", .string)
            .field("is_premium", .bool, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("card_news").delete()
    }
}
