import Fluent
import Vapor

/// Tong 데이터 접근 추상화. 서비스는 이 프로토콜에만 의존한다.
protocol TongRepository: Sendable {
    func find(_ id: UUID) async throws -> Tong?
    func save(_ tong: Tong) async throws
    func getApproved(category: String?, market: Market, after: UUID?, limit: Int) async throws -> [Tong]
    func pendingReview() async throws -> [Tong]
    func approvedByIDs(_ ids: [UUID]) async throws -> [UUID: Tong]
    /// 특정 소유자가 제출한 통 전체 (최신순). 상태 무관 — "내 제출 목록"용.
    func ownedBy(_ ownerID: UUID) async throws -> [Tong]
}

/// Fluent 기반 TongRepository 구현체.
struct FluentTongRepository: TongRepository {
    let db: any Database

    func find(_ id: UUID) async throws -> Tong? {
        try await Tong.find(id, on: db)
    }

    func save(_ tong: Tong) async throws {
        try await tong.save(on: db)
    }

    func pendingReview() async throws -> [Tong] {
        try await Tong.query(on: db)
            .group(.or) { or in
                or.filter(\.$status == .submitted)
                or.filter(\.$status == .inReview)
            }
            .sort(\.$createdAt, .ascending)
            .all()
    }

    func getApproved(category: String?, market: Market, after cursor: UUID?, limit: Int) async throws -> [Tong] {
        var query = Tong.query(on: db)
            .filter(\.$status == .approved)
            .filter(\.$market ~~ Market.queryValues(for: market))

        if let category {
            query = query.filter(\.$category == category)
        }

        if let cursor {
            guard let cursorTong = try await Tong.find(cursor, on: db),
                  let cursorDate = cursorTong.createdAt else {
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

    func approvedByIDs(_ ids: [UUID]) async throws -> [UUID: Tong] {
        guard !ids.isEmpty else { return [:] }
        let tongs = try await Tong.query(on: db)
            .filter(\.$status == .approved)
            .filter(\.$id ~~ ids)
            .all()
        return Dictionary(tongs.compactMap { tong in tong.id.map { ($0, tong) } }) { first, _ in first }
    }

    func ownedBy(_ ownerID: UUID) async throws -> [Tong] {
        try await Tong.query(on: db)
            .filter(\.$owner.$id == ownerID)   // FK 컬럼(owner_id) 기준 필터
            .sort(\.$createdAt, .descending)
            .all()
    }
}
