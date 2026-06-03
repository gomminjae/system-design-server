import Fluent

struct CreateUser: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("users")
            .id()
            .field("provider", .string, .required)
            .field("provider_id", .string, .required)
            .field("nickname", .string)
            .field("profile_image_url", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "provider", "provider_id")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("users").delete()
    }
}
