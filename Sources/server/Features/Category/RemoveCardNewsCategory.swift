import Fluent

/// 'cardnews' 카테고리 제거. 카드뉴스가 독립 콘텐츠 타입이 되어
/// 더 이상 Product의 카테고리(주제)가 아니므로 시드에서 빼고 기존 행도 삭제한다.
struct RemoveCardNewsCategory: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await Category.query(on: database)
            .filter(\.$slug == "cardnews")
            .delete()
    }

    func revert(on database: any Database) async throws {
        // 데이터 정리 성격이라 복구는 시드와 중복. revert 시 재삽입.
        let exists = try await Category.query(on: database).filter(\.$slug == "cardnews").first() != nil
        if !exists {
            try await Category(slug: "cardnews", name: "카드뉴스", emoji: "📰", sortOrder: 7).save(on: database)
        }
    }
}
