import Fluent

/// `tongs.owner_id` 컬럼 추가. 제출자(소유자) 검증용.
/// 기존 행은 소유자 없음(nil)이라 optional.
struct AddTongOwnerID: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("tongs")
            .field("owner_id", .uuid)
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("tongs")
            .deleteField("owner_id")
            .update()
    }
}
