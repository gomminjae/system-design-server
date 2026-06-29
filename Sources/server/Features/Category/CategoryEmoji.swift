/// 카테고리 slug → 대표 이모지. 썸네일이 없는 통의 fallback 비주얼에 쓰인다.
/// ponytail: categories 테이블(SeedCategories)과 동기화된 고정 7종. 카테고리를 추가하면 여기도 추가.
enum CategoryEmoji {
    static func of(_ slug: String) -> String {
        switch slug {
        case "personality": return "🧠"
        case "love": return "💕"
        case "fortune": return "🔮"
        case "iq": return "💡"
        case "trivia": return "📚"
        case "game": return "🎮"
        case "tool": return "🛠"
        default: return "🎴"
        }
    }
}
