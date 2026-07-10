@testable import server
import VaporTesting
import Testing
import Fluent
import SajuKit

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

    /// 스트리밍 테스트용 표본 요청.
    private static let sampleReading = ReadingRequest(
        year: 1994, month: 6, day: 11, hour: 7, minute: 0,
        gender: "male", calendar: "solar", leap: false,
        longitude: nil, applyLocalMeanTime: nil, persona: "ghost", tier: "free")

    @Test("Reading stream: SSE 헤더 + managed 스트림이 done으로 닫힌다 (dev dry-run, 키 없음)")
    func readingStreamDryRun() async throws {
        try await withApp { app in
            try await app.testing().test(.POST, "saju/reading/stream", beforeRequest: { req in
                try req.content.encode(Self.sampleReading)
            }, afterResponse: { res async in
                #expect(res.status == .ok)
                #expect(res.headers.first(name: .contentType)?.contains("text/event-stream") == true)
                let body = res.body.string
                #expect(body.contains("data:"))          // SSE 프레이밍
                #expect(body.contains("\"done\":true"))   // managed 스트림이 정상 종료
                #expect(body.contains("OPENAI_API_KEY"))  // dev dry-run 안내 이벤트
            })
        }
    }

    @Test("Reading stream: 캐시 히트면 저장된 해석을 delta로 재생하고 GPT를 안 부른다")
    func readingStreamCacheReplay() async throws {
        try await withApp { app in
            // JSON 엔드포인트와 같은 키로 해석을 미리 캐시에 심는다.
            let result = try Saju.calculate(Self.sampleReading.toInput)
            let seeded = ReadingResponse(
                persona: "귀안 할매", tier: "free", dryRun: false,
                reading: "네 사주에 서늘한 게 하나 걸리는구나.", messages: nil, saju: SajuDTO(result))
            try await app.cache.set(seeded, id: SajuReadingController.cacheID(for: Self.sampleReading),
                                    expiresIn: .seconds(60))

            try await app.testing().test(.POST, "saju/reading/stream", beforeRequest: { req in
                try req.content.encode(Self.sampleReading)
            }, afterResponse: { res async in
                #expect(res.status == .ok)
                let body = res.body.string
                #expect(body.contains("서늘한 게 하나 걸리는구나"))  // 캐시된 텍스트 재생
                #expect(body.contains("\"done\":true"))
            })
        }
    }
}
