import Fluent
import SQLKit

/// 도메인 개념 `Tong` → `Product` 리네임에 맞춰 라이브 테이블 `tongs` → `products`로 변경.
///
/// 모델의 `static let schema`가 `"products"`로 바뀌었으므로 실제 DB 테이블명도 맞춘다.
/// 과거 마이그레이션(CreateTong 등)은 `tongs`에 기록돼 있어 그대로 두고, 이 마이그레이션을
/// 마지막에 추가해 운영 DB를 안전하게 이전한다.
///
/// 인덱스 리네임은 Postgres만 `ALTER INDEX ... RENAME`을 지원한다. SQLite(테스트)에선
/// 해당 인덱스가 없거나 구문이 달라 실패할 수 있으므로 `try?`로 감싸 전체 마이그레이션을
/// 중단시키지 않는다(테이블 리네임만 보장).
struct RenameTongsToProducts: AsyncMigration {
    func prepare(on database: any Database) async throws {
        guard let sql = database as? any SQLDatabase else { return }
        try await sql.raw("ALTER TABLE tongs RENAME TO products").run()
        try? await sql.raw("ALTER INDEX IF EXISTS idx_tongs_status_market_cat_created RENAME TO idx_products_status_market_cat_created").run()
        try? await sql.raw("ALTER INDEX IF EXISTS idx_tongs_status_cat_created RENAME TO idx_products_status_cat_created").run()
    }

    func revert(on database: any Database) async throws {
        guard let sql = database as? any SQLDatabase else { return }
        try? await sql.raw("ALTER INDEX IF EXISTS idx_products_status_market_cat_created RENAME TO idx_tongs_status_market_cat_created").run()
        try? await sql.raw("ALTER INDEX IF EXISTS idx_products_status_cat_created RENAME TO idx_tongs_status_cat_created").run()
        try await sql.raw("ALTER TABLE products RENAME TO tongs").run()
    }
}
