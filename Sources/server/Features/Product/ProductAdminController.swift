import Fluent
import Vapor

/// 어드민 콘텐츠(Product) 관리 — CRUD + 발행. (BasicAuth 그룹 하위)
/// 내가 직접 만들어 넣는 운영용. 공개 제출/심사 흐름과 별개.
struct ProductAdminController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let group = routes.grouped("admin", "api", "products")
        group.get(use: self.list)
        group.post(use: self.upsert)
        group.put(":productID", "publish", use: self.publish)
        group.delete(":productID", use: self.delete)
    }

    @Sendable
    func list(req: Request) async throws -> APIResponse<[ProductDTO]> {
        let rows = try await Product.query(on: req.db).sort(\.$createdAt, .descending).all()
        return APIResponse(rows.map { $0.toDTO() })
    }

    @Sendable
    func upsert(req: Request) async throws -> APIResponse<ProductDTO> {
        let body = try req.content.decode(ProductUpsertRequest.self)
        guard try await req.categoryService.exists(slug: body.category) else {
            throw APIError.validation("존재하지 않는 카테고리입니다: \(body.category)")
        }

        let product: Product
        if let id = body.id, let existing = try await Product.find(id, on: req.db) {
            product = existing
            product.type = body.type
            product.title = body.title
            product.subtitle = body.subtitle
            product.thumbnailURL = body.thumbnailURL
            product.bundleURL = body.bundleURL
            product.version = body.version
            product.category = body.category
            product.ageRating = body.ageRating
            product.market = body.market ?? .ko
            if let status = body.status { product.status = status }
        } else {
            product = Product(
                type: body.type, title: body.title, subtitle: body.subtitle,
                thumbnailURL: body.thumbnailURL, bundleURL: body.bundleURL,
                version: body.version, category: body.category, ageRating: body.ageRating,
                market: body.market ?? .ko, status: body.status ?? .approved)
        }
        try await product.save(on: req.db)
        try await req.cache.delete([ProductDTO].self)
        return APIResponse(product.toDTO())
    }

    @Sendable
    func publish(req: Request) async throws -> APIResponse<ProductDTO> {
        let id = try req.parameters.require("productID", as: UUID.self)
        guard let product = try await Product.find(id, on: req.db) else {
            throw APIError.notFound("콘텐츠를 찾을 수 없습니다.")
        }
        product.status = product.status == .approved ? .disabled : .approved
        try await product.save(on: req.db)
        try await req.cache.delete([ProductDTO].self)
        return APIResponse(product.toDTO())
    }

    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        let id = try req.parameters.require("productID", as: UUID.self)
        guard let product = try await Product.find(id, on: req.db) else {
            throw APIError.notFound("콘텐츠를 찾을 수 없습니다.")
        }
        try await product.delete(on: req.db)
        try await req.cache.delete([ProductDTO].self)
        return .noContent
    }
}

struct ProductUpsertRequest: Content {
    var id: UUID?
    var type: String
    var title: String
    var subtitle: String?
    var thumbnailURL: String?
    var bundleURL: String
    var version: String
    var category: String
    var ageRating: String
    var market: Market?
    var status: ProductStatus?
}
