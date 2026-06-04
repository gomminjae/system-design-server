import Vapor

/// 통 CRUD 비즈니스 로직.
struct TongService {
    let repository: any TongRepository

    func catalog(category: String?, after: UUID?, limit: Int) async throws -> CursorList<TongDTO> {
        let tongs = try await repository.getApproved(category: category, after: after, limit: limit)
        let hasMore = tongs.count > limit
        let items = hasMore ? Array(tongs.prefix(limit)) : tongs
        let nextCursor = hasMore ? items.last?.id?.uuidString : nil
        return CursorList(items: items.map { $0.toDTO() }, nextCursor: nextCursor, hasMore: hasMore)
    }

    func submit(_ submission: TongSubmission, ownerID: UUID) async throws -> Tong {
        let tong = submission.toModel()
        tong.$owner.id = ownerID
        try await repository.save(tong)
        return tong
    }

    /// 특정 유저가 제출한 통 목록 (최신순). "내 제출 목록"용.
    func mySubmissions(ownerID: UUID) async throws -> [TongDTO] {
        try await repository.ownedBy(ownerID).map { $0.toDTO() }
    }

    func find(_ id: UUID) async throws -> Tong {
        guard let tong = try await repository.find(id) else {
            throw APIError.notFound("통을 찾을 수 없습니다.")
        }
        return tong
    }
}
