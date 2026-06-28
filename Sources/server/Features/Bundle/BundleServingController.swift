import Vapor

/// 번들 파일 서빙. 호스트 앱(WebView)이 승인된 통의 HTML/JS/CSS를 로드한다.
struct BundleServingController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let bundles = routes.grouped("bundles")
        bundles.get(":tongID", ":version", "**", use: self.servePublished)
        bundles.get("pending", ":tongID", "**", use: self.servePending)
    }

    @Sendable
    func servePublished(req: Request) async throws -> Response {
        let tongId = try req.parameters.require("tongID", as: UUID.self)
        guard let versionParam = req.parameters.get("version"),
              versionParam.hasPrefix("v") else {
            throw APIError.validation("버전 형식은 v{version}이어야 합니다.")
        }
        let version = String(versionParam.dropFirst())
        let filePath = req.parameters.getCatchall().joined(separator: "/")
        guard !filePath.isEmpty else {
            throw APIError.validation("파일 경로가 필요합니다.")
        }

        let location = BundleLocation.published(tongId: tongId, version: version)
        let data = try await req.bundleService.readFile(location: location, path: filePath)
        return Self.fileResponse(data: data, path: filePath)
    }

    @Sendable
    func servePending(req: Request) async throws -> Response {
        let tongId = try req.parameters.require("tongID", as: UUID.self)
        let filePath = req.parameters.getCatchall().joined(separator: "/")
        guard !filePath.isEmpty else {
            throw APIError.validation("파일 경로가 필요합니다.")
        }

        let location = BundleLocation.pending(tongId: tongId)
        let data = try await req.bundleService.readFile(location: location, path: filePath)
        return Self.fileResponse(data: data, path: filePath)
    }

    private static func fileResponse(data: Data, path: String) -> Response {
        let response = Response(status: .ok, body: .init(data: data))
        response.headers.contentType = BundleContentType.mediaType(for: path)
        return response
    }
}
