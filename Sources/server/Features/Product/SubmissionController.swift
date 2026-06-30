import Vapor
import VaporToOpenAPI

/// 창작자 제출 + 번들 업로드. 인증(JWT) 필수 — 본인 콘텐츠만 제출·업로드할 수 있다.
struct SubmissionController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let protected = routes.grouped(JWTAuthMiddleware())
        protected.get("submissions", use: self.mySubmissions)
            .openAPI(
                summary: "내 제출 목록",
                description: "로그인한 유저가 제출한 콘텐츠 목록(심사 상태·반려 사유 포함)을 최신순으로 반환한다.",
                response: .type(APIResponse<[ProductDTO]>.self),
                auth: .bearer()
            )
        protected.post("submissions", use: self.submit)
            .openAPI(
                summary: "콘텐츠 제출",
                description: "새 콘텐츠(미니앱) 메타데이터를 제출한다. (인증 필요)",
                body: .type(ProductSubmission.self),
                response: .type(APIResponse<ProductDTO>.self),
                auth: .bearer()
            )
        protected.on(.POST, "submissions", ":productID", "bundle",
                  body: .collect(maxSize: "50mb"),
                  use: self.uploadBundle)
            .openAPI(
                summary: "번들 업로드",
                description: "제출된 콘텐츠에 ZIP 번들 파일을 업로드한다. (본인 콘텐츠만)",
                body: .type(BundleUpload.self),
                response: .type(APIResponse<ProductDTO>.self),
                auth: .bearer()
            )
    }

    /// GET /submissions — 내가 제출한 콘텐츠 목록.
    @Sendable
    func mySubmissions(req: Request) async throws -> APIResponse<[ProductDTO]> {
        let ownerID = try req.authenticatedUserID
        let products = try await req.productService.mySubmissions(ownerID: ownerID)
        return APIResponse(products)
    }

    /// POST /submissions — 콘텐츠 메타데이터 제출.
    @Sendable
    func submit(req: Request) async throws -> APIResponse<ProductDTO> {
        let ownerID = try req.authenticatedUserID
        let submission = try req.content.decode(ProductSubmission.self)
        guard try await req.categoryService.exists(slug: submission.category) else {
            throw APIError.validation("존재하지 않는 카테고리입니다: \(submission.category)")
        }
        let product = try await req.productService.submit(submission, ownerID: ownerID)
        return APIResponse(product.toDTO())
    }

    /// POST /submissions/:id/bundle — zip 번들 업로드.
    @Sendable
    func uploadBundle(req: Request) async throws -> APIResponse<ProductDTO> {
        let userID = try req.authenticatedUserID
        guard let productId = req.parameters.get("productID", as: UUID.self) else {
            throw APIError.validation("잘못된 콘텐츠 ID입니다.")
        }
        let product = try await req.productService.find(productId)
        guard product.$owner.id == userID else {
            throw APIError.forbidden("본인이 제출한 콘텐츠만 번들을 업로드할 수 있습니다.")
        }
        guard product.status == .submitted || product.status == .rejected else {
            throw APIError.validation("제출/반려 상태의 콘텐츠만 번들을 업로드할 수 있습니다.")
        }

        let upload = try req.content.decode(BundleUpload.self)
        let zipData = Data(buffer: upload.file.data)
        let bundleURL = try await req.bundleService.upload(productId: productId, zipData: zipData)

        product.bundleURL = bundleURL
        try await req.productRepository.save(product)

        return APIResponse(product.toDTO())
    }
}
