import Fluent
import Vapor

/// Product 데이터 접근 추상화. 서비스는 이 프로토콜에만 의존한다.
protocol ProductRepository: Sendable {
    func find(_ id: UUID) async throws -> Product?
    func save(_ product: Product) async throws
    func getApproved(category: String?, market: Market, after: UUID?, limit: Int) async throws -> [Product]
    func pendingReview() async throws -> [Product]
    func approvedByIDs(_ ids: [UUID]) async throws -> [UUID: Product]
    /// 특정 소유자가 제출한 콘텐츠 전체 (최신순). 상태 무관 — "내 제출 목록"용.
    func ownedBy(_ ownerID: UUID) async throws -> [Product]
}

/// Fluent 기반 ProductRepository 구현체.
struct FluentProductRepository: ProductRepository {
    let db: any Database

    func find(_ id: UUID) async throws -> Product? {
        try await Product.find(id, on: db)
    }

    func save(_ product: Product) async throws {
        try await product.save(on: db)
    }

    func pendingReview() async throws -> [Product] {
        try await Product.query(on: db)
            .group(.or) { or in
                or.filter(\.$status == .submitted)
                or.filter(\.$status == .inReview)
            }
            .sort(\.$createdAt, .ascending)
            .all()
    }

    func getApproved(category: String?, market: Market, after cursor: UUID?, limit: Int) async throws -> [Product] {
        var query = Product.query(on: db)
            .filter(\.$status == .approved)
            .filter(\.$market ~~ Market.queryValues(for: market))

        if let category {
            query = query.filter(\.$category == category)
        }

        if let cursor {
            guard let cursorProduct = try await Product.find(cursor, on: db),
                  let cursorDate = cursorProduct.createdAt else {
                throw APIError.validation("유효하지 않은 커서입니다.")
            }
            query = query.group(.or) { or in
                or.filter(\.$createdAt < cursorDate)
                or.group(.and) { and in
                    and.filter(\.$createdAt == cursorDate)
                    and.filter(\.$id < cursor)
                }
            }
        }

        return try await query
            .sort(\.$createdAt, .descending)
            .sort(\.$id, .descending)
            .limit(limit + 1)
            .all()
    }

    func approvedByIDs(_ ids: [UUID]) async throws -> [UUID: Product] {
        guard !ids.isEmpty else { return [:] }
        let products = try await Product.query(on: db)
            .filter(\.$status == .approved)
            .filter(\.$id ~~ ids)
            .all()
        return Dictionary(products.compactMap { product in product.id.map { ($0, product) } }) { first, _ in first }
    }

    func ownedBy(_ ownerID: UUID) async throws -> [Product] {
        try await Product.query(on: db)
            .filter(\.$owner.$id == ownerID)   // FK 컬럼(owner_id) 기준 필터
            .sort(\.$createdAt, .descending)
            .all()
    }
}
