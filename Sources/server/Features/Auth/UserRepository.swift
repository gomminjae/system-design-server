import Fluent
import Vapor

/// User 데이터 접근 추상화.
protocol UserRepository: Sendable {
    func find(_ id: UUID) async throws -> User?
    func findByProvider(_ provider: String, providerID: String) async throws -> User?
    func save(_ user: User) async throws
}

/// Fluent 기반 UserRepository 구현체.
struct FluentUserRepository: UserRepository {
    let db: any Database

    func find(_ id: UUID) async throws -> User? {
        try await User.find(id, on: db)
    }

    func findByProvider(_ provider: String, providerID: String) async throws -> User? {
        try await User.query(on: db)
            .filter(\.$provider == provider)
            .filter(\.$providerID == providerID)
            .first()
    }

    func save(_ user: User) async throws {
        try await user.save(on: db)
    }
}
