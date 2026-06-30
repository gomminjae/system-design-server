import Vapor

/// 심사 비즈니스 로직: 제출, 승인, 반려, 비활성화.
struct ReviewService {
    let repository: any ProductRepository
    let bundleService: BundleService

    /// 심사 대기 목록 조회.
    func pendingReviews() async throws -> [ProductDTO] {
        try await repository.pendingReview().map { $0.toDTO() }
    }

    /// 콘텐츠를 심사 목록에 제출한다.
    func submitForReview(_ product: Product) async throws {
        product.status = .submitted
        try await repository.save(product)
    }

    /// 콘텐츠를 승인하고, 번들이 있으면 published로 승격한다.
    func approve(_ productId: UUID) async throws {
        let product = try await findOrThrow(productId)
        product.status = .approved
        product.rejectionReason = nil

        let pending = BundleLocation.pending(productId: productId)
        let hasPending = try await bundleService.storage.list(pending)
        if !hasPending.isEmpty {
            let publishedURL = try await bundleService.promote(productId: productId, version: product.version)
            product.bundleURL = publishedURL
        }

        try await repository.save(product)
    }

    /// 콘텐츠를 반려하고, pending 번들을 정리한다.
    func reject(_ productId: UUID, reason: String) async throws {
        let product = try await findOrThrow(productId)
        product.status = .rejected
        product.rejectionReason = reason
        try await repository.save(product)
        try await bundleService.cleanupPending(productId: productId)
    }

    /// 승인된 콘텐츠를 비활성화한다 (kill switch).
    func disable(_ productId: UUID) async throws {
        let product = try await findOrThrow(productId)
        product.status = .disabled
        try await repository.save(product)
    }

    private func findOrThrow(_ id: UUID) async throws -> Product {
        guard let product = try await repository.find(id) else {
            throw APIError.notFound("콘텐츠를 찾을 수 없습니다.")
        }
        return product
    }
}
