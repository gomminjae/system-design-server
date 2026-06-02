import Fluent

struct CreateTong: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("tongs")
            .id()
            .field("type", .string, .required)
            .field("title", .string, .required)
            .field("subtitle", .string)
            .field("thumb_url", .string)
            .field("bundle_url", .string, .required)
            .field("version", .string, .required)
            .field("category", .string, .required)
            .field("age_rating", .string, .required)
            .field("status", .string, .required)
            .field("rejection_reason", .string)
            .field("submitter_contact", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("tongs").delete()
    }
}
