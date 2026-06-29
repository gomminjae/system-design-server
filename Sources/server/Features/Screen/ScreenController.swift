import Fluent
import Vapor

/// 공개 SDUI 엔드포인트 — 앱이 화면 구성을 요청한다.
struct ScreenController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.get("screens", ":screenId", use: self.getScreen)
    }

    /// GET /screens/:screenId — 발행된 화면 구성 반환.
    @Sendable
    func getScreen(req: Request) async throws -> APIResponse<ScreenResponse> {
        let screenId = try req.parameters.require("screenId", as: String.self)
        let market = req.market
        let cacheID = "\(screenId):\(market.rawValue)"
        if let cached = try await req.cache.get(ScreenResponse.self, id: cacheID) {
            return APIResponse(cached)
        }

        guard let screen = try await Screen.query(on: req.db)
            .filter(\.$screenId == screenId)
            .filter(\.$isPublished == true)
            .first() else {
            throw APIError.notFound("화면을 찾을 수 없습니다: \(screenId)")
        }

        let decoder = JSONDecoder()
        guard let data = screen.sectionsJSON.data(using: .utf8),
              let sections = try? decoder.decode([Section].self, from: data) else {
            req.logger.error("화면 섹션 JSON 파싱 실패: \(screenId)")
            throw APIError(status: .internalServerError, code: "screen_corrupt",
                           reason: "화면 데이터를 불러올 수 없습니다.")
        }

        // 동적 바인딩: 저장된 참조를 실제 카탈로그/카테고리 데이터로 채운다.
        let resolved = try await req.screenResolver.resolve(sections, market: market)

        let response = ScreenResponse(
            screenId: screen.screenId,
            title: screen.title,
            sections: resolved
        )
        try await req.cache.set(response, id: cacheID, expiresIn: .seconds(60))
        return APIResponse(response)
    }
}

/// 어드민 SDUI 관리 — 화면 CRUD.
struct ScreenAdminController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let screens = routes.grouped("admin", "api", "screens")
        screens.get(use: self.list)
        screens.post(use: self.upsert)
        screens.get(":screenId", use: self.get)
        screens.put(":screenId", "publish", use: self.publish)
        screens.delete(":screenId", use: self.delete)
    }

    /// GET /admin/screens — 전체 화면 목록.
    @Sendable
    func list(req: Request) async throws -> APIResponse<[ScreenListItem]> {
        let screens = try await Screen.query(on: req.db).all()
        return APIResponse(screens.map {
            ScreenListItem(
                screenId: $0.screenId,
                title: $0.title,
                isPublished: $0.isPublished,
                updatedAt: $0.updatedAt
            )
        })
    }

    /// GET /admin/screens/:screenId — 화면 상세 (섹션 JSON 포함).
    @Sendable
    func get(req: Request) async throws -> APIResponse<ScreenDetailResponse> {
        let screenId = try req.parameters.require("screenId", as: String.self)
        guard let screen = try await Screen.query(on: req.db)
            .filter(\.$screenId == screenId)
            .first() else {
            throw APIError.notFound("화면을 찾을 수 없습니다: \(screenId)")
        }

        let decoder = JSONDecoder()
        let sections: [Section]
        if let data = screen.sectionsJSON.data(using: .utf8),
           let decoded = try? decoder.decode([Section].self, from: data) {
            sections = decoded
        } else {
            sections = []
        }

        return APIResponse(ScreenDetailResponse(
            screenId: screen.screenId,
            title: screen.title,
            sections: sections,
            isPublished: screen.isPublished,
            updatedAt: screen.updatedAt
        ))
    }

    /// POST /admin/screens — 화면 생성/수정 (upsert).
    @Sendable
    func upsert(req: Request) async throws -> APIResponse<ScreenDetailResponse> {
        let body = try req.content.decode(ScreenUpsertRequest.self)
        let encoder = JSONEncoder()
        let sectionsData = try encoder.encode(body.sections)
        let sectionsString = String(data: sectionsData, encoding: .utf8) ?? "[]"

        let screen: Screen
        if let existing = try await Screen.query(on: req.db)
            .filter(\.$screenId == body.screenId)
            .first() {
            existing.title = body.title
            existing.sectionsJSON = sectionsString
            screen = existing
        } else {
            screen = Screen(
                screenId: body.screenId,
                title: body.title,
                sectionsJSON: sectionsString
            )
        }
        try await screen.save(on: req.db)
        try await invalidateCache(body.screenId, on: req)

        return APIResponse(ScreenDetailResponse(
            screenId: screen.screenId,
            title: screen.title,
            sections: body.sections,
            isPublished: screen.isPublished,
            updatedAt: screen.updatedAt
        ))
    }

    /// PUT /admin/screens/:screenId/publish — 발행/비발행 토글.
    @Sendable
    func publish(req: Request) async throws -> APIResponse<ScreenListItem> {
        let screenId = try req.parameters.require("screenId", as: String.self)
        guard let screen = try await Screen.query(on: req.db)
            .filter(\.$screenId == screenId)
            .first() else {
            throw APIError.notFound("화면을 찾을 수 없습니다: \(screenId)")
        }
        screen.isPublished.toggle()
        try await screen.save(on: req.db)
        try await invalidateCache(screen.screenId, on: req)
        return APIResponse(ScreenListItem(
            screenId: screen.screenId,
            title: screen.title,
            isPublished: screen.isPublished,
            updatedAt: screen.updatedAt
        ))
    }

    /// DELETE /admin/screens/:screenId — 화면 삭제.
    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        let screenId = try req.parameters.require("screenId", as: String.self)
        guard let screen = try await Screen.query(on: req.db)
            .filter(\.$screenId == screenId)
            .first() else {
            throw APIError.notFound("화면을 찾을 수 없습니다: \(screenId)")
        }
        try await screen.delete(on: req.db)
        try await invalidateCache(screen.screenId, on: req)
        return .noContent
    }

    /// 화면 캐시는 market별로 분리 저장되므로 모든 market 변형을 지운다.
    private func invalidateCache(_ screenId: String, on req: Request) async throws {
        for m in Market.allCases {
            try await req.cache.delete(ScreenResponse.self, id: "\(screenId):\(m.rawValue)")
        }
    }
}

// MARK: - Admin DTOs

struct ScreenUpsertRequest: Content {
    let screenId: String
    let title: String
    let sections: [Section]
}

struct ScreenListItem: Content {
    let screenId: String
    let title: String
    let isPublished: Bool
    let updatedAt: Date?
}

struct ScreenDetailResponse: Content {
    let screenId: String
    let title: String
    let sections: [Section]
    let isPublished: Bool
    let updatedAt: Date?
}
