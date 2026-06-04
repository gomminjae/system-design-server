import Vapor
import VaporToOpenAPI

/// 공개 카테고리 목록. SDUI 칩·필터·제출 폼이 이 값을 끌어 쓴다.
struct CategoryController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.get("categories", use: self.list)
            .openAPI(
                summary: "카테고리 목록",
                description: "통 디스커버리 카테고리를 노출 순서대로 반환한다.",
                response: .type(APIResponse<[CategoryDTO]>.self)
            )
    }

    @Sendable
    func list(req: Request) async throws -> APIResponse<[CategoryDTO]> {
        if let cached = try await req.cache.get([CategoryDTO].self) {
            return APIResponse(cached)
        }
        let categories = try await req.categoryService.list()
        try await req.cache.set(categories, expiresIn: .seconds(300))
        return APIResponse(categories)
    }
}
