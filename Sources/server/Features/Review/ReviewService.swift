import Vapor

/// 심사 비즈니스 로직: 제출, 승인, 반려, 비활성화.
struct ReviewService {
    let repository: any TongRepository
    let bundleService: BundleService

    /// 심사 대기 목록 조회.
    func pendingReviews() async throws -> [TongDTO] {
        try await repository.pendingReview().map { $0.toDTO() }
    }

    /// 통을 심사 목록에 제출한다.
    func submitForReview(_ tong: Tong) async throws {
        tong.status = .submitted
        try await repository.save(tong)
    }

    /// 통을 승인하고, 번들이 있으면 published로 승격한다.
    func approve(_ tongId: UUID) async throws {
        let tong = try await findOrThrow(tongId)
        tong.status = .approved
        tong.rejectionReason = nil

        let pending = BundleLocation.pending(tongId: tongId)
        let hasPending = try await bundleService.storage.list(pending)
        if !hasPending.isEmpty {
            let publishedURL = try await bundleService.promote(tongId: tongId, version: tong.version)
            tong.bundleURL = publishedURL
        }

        try await repository.save(tong)
    }

    /// 통을 반려하고, pending 번들을 정리한다.
    func reject(_ tongId: UUID, reason: String) async throws {
        let tong = try await findOrThrow(tongId)
        tong.status = .rejected
        tong.rejectionReason = reason
        try await repository.save(tong)
        try await bundleService.cleanupPending(tongId: tongId)
    }

    /// 승인된 통을 비활성화한다 (kill switch).
    func disable(_ tongId: UUID) async throws {
        let tong = try await findOrThrow(tongId)
        tong.status = .disabled
        try await repository.save(tong)
    }

    private func findOrThrow(_ id: UUID) async throws -> Tong {
        guard let tong = try await repository.find(id) else {
            throw APIError.notFound("통을 찾을 수 없습니다.")
        }
        return tong
    }
}
