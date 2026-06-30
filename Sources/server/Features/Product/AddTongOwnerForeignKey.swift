import Fluent
import SQLKit

/// `tongs.owner_id → users.id` 외래키 (ON DELETE SET NULL).
/// 유저 삭제 시 통은 보존하고 소유자만 끊는다(익명화).
///
/// 기존 컬럼에 FK를 ALTER로 추가하는 건 SQLite가 지원 안 하므로 **Postgres 전용**.
/// 테스트(인메모리 SQLite)는 FK 정합성을 검증하지 않으니 스킵해도 무방하다.
struct AddTongOwnerForeignKey: AsyncMigration {
    func prepare(on database: any Database) async throws {
        guard let sql = database as? any SQLDatabase,
              sql.dialect.name == "postgresql" else { return }
        try await sql.raw("""
            ALTER TABLE tongs
            ADD CONSTRAINT fk_tongs_owner
            FOREIGN KEY (owner_id) REFERENCES users (id) ON DELETE SET NULL
        """).run()
    }

    func revert(on database: any Database) async throws {
        guard let sql = database as? any SQLDatabase,
              sql.dialect.name == "postgresql" else { return }
        try await sql.raw("ALTER TABLE tongs DROP CONSTRAINT IF EXISTS fk_tongs_owner").run()
    }
}
