import Fluent
import SQLKit

/// tongs, card_news에 market 컬럼 추가. 기존 행은 'ko' 기본.
struct AddContentMarket: AsyncMigration {
    func prepare(on database: any Database) async throws {
        guard let sql = database as? any SQLDatabase else { return }
        try await sql.raw("ALTER TABLE tongs ADD COLUMN market TEXT NOT NULL DEFAULT 'ko'").run()
        try await sql.raw("ALTER TABLE card_news ADD COLUMN market TEXT NOT NULL DEFAULT 'ko'").run()
        try await sql.raw("""
            CREATE INDEX IF NOT EXISTS idx_tongs_status_market_cat_created
            ON tongs (status, market, category, created_at DESC)
            """).run()
        try await sql.raw("""
            CREATE INDEX IF NOT EXISTS idx_card_news_status_market_created
            ON card_news (status, market, created_at DESC)
            """).run()
    }

    func revert(on database: any Database) async throws {
        guard let sql = database as? any SQLDatabase else { return }
        try await sql.raw("DROP INDEX IF EXISTS idx_tongs_status_market_cat_created").run()
        try await sql.raw("DROP INDEX IF EXISTS idx_card_news_status_market_created").run()
        try await sql.raw("ALTER TABLE tongs DROP COLUMN market").run()
        try await sql.raw("ALTER TABLE card_news DROP COLUMN market").run()
    }
}
