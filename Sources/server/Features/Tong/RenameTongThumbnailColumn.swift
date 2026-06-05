import Fluent
import SQLKit

/// `tongs.thumb_url` → `thumbnail_url` 컬럼명 정리 (약어 제거).
/// SQLite 3.25+/Postgres 모두 `ALTER TABLE ... RENAME COLUMN` 지원.
struct RenameTongThumbnailColumn: AsyncMigration {
    func prepare(on database: any Database) async throws {
        guard let sql = database as? any SQLDatabase else { return }
        try await sql.raw("ALTER TABLE tongs RENAME COLUMN thumb_url TO thumbnail_url").run()
    }

    func revert(on database: any Database) async throws {
        guard let sql = database as? any SQLDatabase else { return }
        try await sql.raw("ALTER TABLE tongs RENAME COLUMN thumbnail_url TO thumb_url").run()
    }
}
