import Fluent
import Vapor

/// 창작자 제출. 누구나 통을 제출하면 status=submitted 로 쌓여 심사 큐로 들어간다.
struct SubmissionController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.post("submissions", use: self.submit)
    }

    @Sendable
    func submit(req: Request) async throws -> APIResponse<TongDTO> {
        let submission = try req.content.decode(TongSubmission.self)
        let tong = submission.toModel()
        try await tong.save(on: req.db)
        return APIResponse(tong.toDTO())
    }
}
