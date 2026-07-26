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

    @Test("Suggest: prefix 매칭 + 관객수 내림차순")
    func suggestPrefixOrdering() async throws {
        try await withApp { app in
            try await [
                Movie(title: "아이언 맨", releaseYear: 2008, audienceCount: 4_000_000),
                Movie(title: "아이언 맨 3", releaseYear: 2013, audienceCount: 9_000_000),
                Movie(title: "어벤져스", releaseYear: 2012, audienceCount: 7_000_000),
            ].create(on: app.db)

            try await app.testing().test(.GET, "search/suggest?q=아이언", afterResponse: { res async throws in
                #expect(res.status == .ok)
                let body = try res.content.decode(APIResponse<SuggestResponse>.self).data
                #expect(body.suggestions.map(\.title) == ["아이언 맨 3", "아이언 맨"])
            })
        }
    }

    @Test("Suggest: q 없으면 validation 에러")
    func suggestRequiresQuery() async throws {
        try await withApp { app in
            try await app.testing().test(.GET, "search/suggest", afterResponse: { res async in
                #expect(res.status == .badRequest)
            })
        }
    }

    @Test("Search log 적재")
    func searchLogCreate() async throws {
        try await withApp { app in
            try await app.testing().test(.POST, "search/logs", beforeRequest: { req in
                try req.content.encode(SearchLogRequest(query: "아이언맨", sessionID: "s1", clickedMovieID: nil))
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
                let count = try await SearchLog.query(on: app.db).count()
                #expect(count == 1)
            })
        }
    }
}
