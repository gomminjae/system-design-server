@testable import server
import VaporTesting
import Testing
import Fluent

@Suite("App Tests with DB", .serialized)
struct serverTests {
    private func withApp(_ test: (Application) async throws -> ()) async throws {
        let app = try await Application.make(.testing)
        do {
            try await configure(app)
            try await app.autoMigrate()
            try await test(app)
            try await app.autoRevert()
        } catch {
            try? await app.autoRevert()
            try await app.asyncShutdown()
            throw error
        }
        try await app.asyncShutdown()
    }

    @Test("Health check")
    func healthCheck() async throws {
        try await withApp { app in
            try await app.testing().test(.GET, "health", afterResponse: { res async in
                #expect(res.status == .ok)
                #expect(res.body.string == "ok")
            })
        }
    }

    @Test("Catalog returns empty array initially")
    func catalogEmpty() async throws {
        try await withApp { app in
            try await app.testing().test(.GET, "catalog", afterResponse: { res async throws in
                #expect(res.status == .ok)
                let body = try res.content.decode(APIResponse<[TongDTO]>.self)
                #expect(body.data.isEmpty)
            })
        }
    }

    @Test("Submit a tong")
    func submitTong() async throws {
        try await withApp { app in
            let submission = TongSubmission(
                type: "quiz",
                title: "Test Tong",
                subtitle: nil,
                thumbURL: nil,
                bundleURL: "https://example.com",
                version: "1.0.0",
                category: "personality",
                ageRating: "all",
                submitterContact: "test@example.com"
            )
            try await app.testing().test(.POST, "submissions", beforeRequest: { req in
                try req.content.encode(submission)
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
                let body = try res.content.decode(APIResponse<TongDTO>.self)
                #expect(body.data.title == "Test Tong")
                #expect(body.data.status == .submitted)
            })
        }
    }
}
