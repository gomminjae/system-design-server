import Fluent
import Vapor

/// Tong 데이터 접근 추상화. 서비스는 이 프로토콜에만 의존한다.
protocol TongRepository: Sendable {
    func find(_ id: UUID) async throws -> Tong?
    func save(_ tong: Tong) async throws
    func approved() async throws -> [Tong]
    func pendingReview() async throws -> [Tong]
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
}
