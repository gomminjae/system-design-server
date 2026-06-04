import Fluent
import Vapor

/// 카테고리 조회/검증. App 피처처럼 모델을 직접 쿼리하는 슬림 서비스.
struct CategoryService {
    let db: any Database

    /// 노출 순서대로 전체 카테고리 반환.
    func list() async throws -> [CategoryDTO] {
        try await Category.query(on: db)
            .sort(\.$sortOrder, .ascending)
            .all()
            .map { $0.toDTO() }
    }

    /// 해당 slug의 카테고리가 존재하는지.
    func exists(slug: String) async throws -> Bool {
        try await Category.query(on: db)
            .filter(\.$slug == slug)
            .first() != nil
    }
}
