import Fluent

struct CreateScreen: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("screens")
            .id()
            .field("screen_id", .string, .required)
            .field("title", .string, .required)
            .field("sections_json", .string, .required)
            .field("is_published", .bool, .required)
            .field("updated_at", .datetime)
            .unique(on: "screen_id")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("screens").delete()
    }
}
