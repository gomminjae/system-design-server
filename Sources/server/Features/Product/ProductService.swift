import Vapor

/// 콘텐츠 CRUD 비즈니스 로직.
struct ProductService {
    let repository: any ProductRepository

    func catalog(category: String?, market: Market, after: UUID?, limit: Int) async throws -> CursorList<ProductDTO> {
        let products = try await repository.getApproved(category: category, market: market, after: after, limit: limit)
        let hasMore = products.count > limit
        let items = hasMore ? Array(products.prefix(limit)) : products
        let nextCursor = hasMore ? items.last?.id?.uuidString : nil
        return CursorList(items: items.map { $0.toDTO() }, nextCursor: nextCursor, hasMore: hasMore)
    }

    func submit(_ submission: ProductSubmission, ownerID: UUID) async throws -> Product {
        let product = submission.toModel()
        product.$owner.id = ownerID
        try await repository.save(product)
        return product
    }

    /// 특정 유저가 제출한 콘텐츠 목록 (최신순). "내 제출 목록"용.
    func mySubmissions(ownerID: UUID) async throws -> [ProductDTO] {
        try await repository.ownedBy(ownerID).map { $0.toDTO() }
    }

    func find(_ id: UUID) async throws -> Product {
        guard let product = try await repository.find(id) else {
            throw APIError.notFound("콘텐츠를 찾을 수 없습니다.")
        }
        return product
    }
}
