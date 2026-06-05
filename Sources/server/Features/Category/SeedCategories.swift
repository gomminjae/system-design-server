import Fluent

/// 기본 카테고리 시드. 순서대로 sort_order 부여.
struct SeedCategories: AsyncMigration {
    /// (slug, 표시명, 이모지)
    static let seeds: [(String, String, String)] = [
        ("personality", "성격·심리", "🧠"),
        ("love", "연애·관계", "💕"),
        ("fortune", "운세·타로", "🔮"),
        ("iq", "지능·두뇌", "💡"),
        ("trivia", "상식·잡지식", "📚"),
        ("game", "미니게임", "🎮"),
        ("tool", "도구·유틸", "🛠"),
    ]

    func prepare(on database: any Database) async throws {
        for (index, seed) in Self.seeds.enumerated() {
            let category = Category(slug: seed.0, name: seed.1, emoji: seed.2, sortOrder: index)
            try await category.save(on: database)
        }
    }

    func revert(on database: any Database) async throws {
        let slugs = Self.seeds.map(\.0)
        try await Category.query(on: database)
            .filter(\.$slug ~~ slugs)
            .delete()
    }
}
