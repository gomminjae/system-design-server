import Vapor
import VaporToOpenAPI

/// 창작자 제출 + 번들 업로드.
struct SubmissionController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.post("submissions", use: self.submit)
            .openAPI(
                summary: "통 제출",
                description: "새 통(미니앱) 메타데이터를 제출한다.",
                body: .type(TongSubmission.self),
                response: .type(APIResponse<TongDTO>.self)
            )
        routes.on(.POST, "submissions", ":tongID", "bundle",
                  body: .collect(maxSize: "50mb"),
                  use: self.uploadBundle)
            .openAPI(
                summary: "번들 업로드",
                description: "제출된 통에 ZIP 번들 파일을 업로드한다.",
                body: .type(BundleUpload.self),
                response: .type(APIResponse<TongDTO>.self)
            )
    }

    /// POST /submissions — 통 메타데이터 제출.
    @Sendable
    func submit(req: Request) async throws -> APIResponse<TongDTO> {
        let submission = try req.content.decode(TongSubmission.self)
        let tong = try await req.tongService.submit(submission)
        return APIResponse(tong.toDTO())
    }

    /// POST /submissions/:id/bundle — zip 번들 업로드.
    @Sendable
    func uploadBundle(req: Request) async throws -> APIResponse<TongDTO> {
        guard let tongId = req.parameters.get("tongID", as: UUID.self) else {
            throw APIError.validation("잘못된 통 ID입니다.")
        }
        let tong = try await req.tongService.find(tongId)
        guard tong.status == .submitted || tong.status == .rejected else {
            throw APIError.validation("제출/반려 상태의 통만 번들을 업로드할 수 있습니다.")
        }

        let upload = try req.content.decode(BundleUpload.self)
        let zipData = Data(buffer: upload.file.data)
        let bundleURL = try await req.bundleService.upload(tongId: tongId, zipData: zipData)

        tong.bundleURL = bundleURL
        try await req.tongRepository.save(tong)

        return APIResponse(tong.toDTO())
    }
}
