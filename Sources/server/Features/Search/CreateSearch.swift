import Fluent

struct CreateMovie: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(Movie.schema)
            .id()
            .field("title", .string, .required)
            .field("title_eng", .string)
            .field("release_year", .int, .required)
            .field("audience_count", .int, .required)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(Movie.schema).delete()
    }
}

struct CreateSearchLog: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(SearchLog.schema)
            .id()
            .field("query", .string, .required)
            .field("session_id", .string, .required)
            .field("clicked_movie_id", .uuid)
            .field("searched_at", .datetime)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(SearchLog.schema).delete()
    }
}
