import Fluent
import Vapor

/// 공개 카탈로그. 승인된 통만 JSON으로 노출한다.
struct CatalogController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.get("catalog", use: self.catalog)
    }

    @Sendable
    func catalog(req: Request) async throws -> APIResponse<[TongDTO]> {
        let tongs = try await Tong.query(on: req.db)
            .filter(\.$status == .approved)
            .sort(\.$createdAt, .descending)
            .all()
            .map { $0.toDTO() }
        return APIResponse(tongs)
    }
}
