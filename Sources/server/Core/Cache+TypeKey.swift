import Vapor

extension Cache {
    func get<T: Codable & Sendable>(_ type: T.Type, id: String? = nil) async throws -> T? {
        let key = id.map { "\(T.self):\($0)" } ?? "\(T.self)"
        return try await get(key, as: T.self)
    }

    func set<T: Codable & Sendable>(_ value: T, id: String? = nil, expiresIn ttl: CacheExpirationTime) async throws {
        let key = id.map { "\(T.self):\($0)" } ?? "\(T.self)"
        try await set(key, to: value, expiresIn: ttl)
    }

    func delete<T>(_ type: T.Type, id: String? = nil) async throws {
        let key = id.map { "\(T.self):\($0)" } ?? "\(T.self)"
        try await delete(key)
    }
}
