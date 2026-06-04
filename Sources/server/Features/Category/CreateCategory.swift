import Fluent

struct CreateCategory: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("categories")
            .id()
            .field("slug", .string, .required)
            .field("name", .string, .required)
            .field("emoji", .string)
            .field("sort_order", .int, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "slug")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("categories").delete()
    }
}
