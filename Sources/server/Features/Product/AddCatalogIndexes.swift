import Fluent
import SQLKit

/// tongs, card_news 테이블에 카탈로그 쿼리용 복합 인덱스 추가.
/// status + category + created_at 조합으로 커서 페이징 쿼리를 커버한다.
struct AddCatalogIndexes: AsyncMigration {
    func prepare(on database: any Database) async throws {
        guard let sql = database as? any SQLDatabase else { return }
        // tongs: WHERE status = 'approved' AND category = ? ORDER BY created_at DESC
        try await sql.raw("""
            CREATE INDEX IF NOT EXISTS idx_tongs_status_cat_created
            ON tongs (status, category, created_at DESC)
            """).run()
        // card_news: WHERE status = 'published' ORDER BY created_at DESC
        try await sql.raw("""
            CREATE INDEX IF NOT EXISTS idx_card_news_status_created
            ON card_news (status, created_at DESC)
            """).run()
    }

    func revert(on database: any Database) async throws {
        guard let sql = database as? any SQLDatabase else { return }
        try await sql.raw("DROP INDEX IF EXISTS idx_tongs_status_cat_created").run()
        try await sql.raw("DROP INDEX IF EXISTS idx_card_news_status_created").run()
    }
}
