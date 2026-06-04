import Fluent
import Vapor

/// Tong 데이터 접근 추상화. 서비스는 이 프로토콜에만 의존한다.
protocol TongRepository: Sendable {
    func find(_ id: UUID) async throws -> Tong?
    func save(_ tong: Tong) async throws
    func approved() async throws -> [Tong]
    func pendingReview() async throws -> [Tong]
    /// 특정 카테고리의 승인 통 (최신순, 최대 limit개). SDUI 동적 바인딩용.
    func approved(category: String, limit: Int) async throws -> [Tong]
    /// id 목록에 해당하는 승인 통을 id로 색인해 반환. SDUI hydrate용 배치 조회.
    func approvedByIDs(_ ids: [UUID]) async throws -> [UUID: Tong]
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

    func approved() async throws -> [Tong] {
        try await Tong.query(on: db)
            .filter(\.$status == .approved)
            .sort(\.$createdAt, .descending)
            .all()
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

    func approved(category: String, limit: Int) async throws -> [Tong] {
        try await Tong.query(on: db)
            .filter(\.$status == .approved)
            .filter(\.$category == category)
            .sort(\.$createdAt, .descending)
            .limit(limit)
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
}
