import Vapor
import VaporToOpenAPI

/// 공개 카탈로그. 승인된 통만 JSON으로 노출한다.
struct CatalogController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.get("catalog", use: self.catalog)
            .openAPI(
                summary: "카탈로그 조회",
                description: "승인된 통(미니앱) 목록을 반환한다.",
                response: .type(APIResponse<[TongDTO]>.self)
            )
    }

    @Sendable
    func catalog(req: Request) async throws -> APIResponse<[TongDTO]> {
        if let cached = try await req.cache.get([TongDTO].self) {
            return APIResponse(cached)
        }
        let tongs = try await req.tongService.catalog()
        try await req.cache.set(tongs, expiresIn: .seconds(60))
        return APIResponse(tongs)
    }
}
