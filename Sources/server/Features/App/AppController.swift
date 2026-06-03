import Fluent
import Vapor

struct AppController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let app = routes.grouped("app")
        app.get("version", use: self.version)
    }

    @Sendable
    func version(req: Request) async throws -> AppVersionResponse {
        let platform = req.query[String.self, at: "platform"] ?? "ios"
        if let cached = try await req.cache.get(AppVersionResponse.self, id: platform) {
            return cached
        }

        guard let version = try await AppVersion.query(on: req.db)
            .filter(\.$platform == platform)
            .first() else {
            throw APIError.notFound("해당 플랫폼의 버전 정보가 없습니다.")
        }
        let response = AppVersionResponse(
            minVersion: version.minVersion,
            latestVersion: version.latestVersion,
            releaseNotes: version.releaseNotes
        )
        try await req.cache.set(response, id: platform, expiresIn: .seconds(300))
        return response
    }
}

struct AppAdminController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let app = routes.grouped("admin", "app")
        app.post("version", use: self.upsertVersion)
    }

    /// POST /admin/app/version — 버전 정보 생성/수정.
    @Sendable
    func upsertVersion(req: Request) async throws -> AppVersionResponse {
        let body = try req.content.decode(AppVersionUpdateRequest.self)
        let version: AppVersion
        if let existing = try await AppVersion.query(on: req.db)
            .filter(\.$platform == body.platform)
            .first() {
            existing.minVersion = body.minVersion
            existing.latestVersion = body.latestVersion
            existing.releaseNotes = body.releaseNotes
            version = existing
        } else {
            version = AppVersion(
                platform: body.platform,
                minVersion: body.minVersion,
                latestVersion: body.latestVersion,
                releaseNotes: body.releaseNotes
            )
        }
        try await version.save(on: req.db)
        try await req.cache.delete(AppVersionResponse.self, id: body.platform)
        return AppVersionResponse(
            minVersion: version.minVersion,
            latestVersion: version.latestVersion,
            releaseNotes: version.releaseNotes
        )
    }
}
