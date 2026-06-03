import Fluent

struct CreateAppVersion: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("app_versions")
            .id()
            .field("platform", .string, .required)
            .field("min_version", .string, .required)
            .field("latest_version", .string, .required)
            .field("release_notes", .array(of: .string), .required)
            .field("updated_at", .datetime)
            .unique(on: "platform")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("app_versions").delete()
    }
}
