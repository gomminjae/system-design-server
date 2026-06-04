import Vapor

/// 백오피스(심사) — Leaf SSR 페이지. Basic Auth 보호 그룹 하위에 등록.
struct AdminController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let admin = routes.grouped("admin")
        admin.get(use: self.pendingReviews)
        admin.group("tongs", ":tongID") { tong in
            tong.post("approve", use: self.approve)
            tong.post("reject", use: self.reject)
            tong.post("disable", use: self.disable)
        }
        // 화면 관리 CMS 페이지
        admin.get("screens", use: self.screensPage)
        admin.get("screens", ":screenId", "edit", use: self.screenEditPage)
    }

    @Sendable
    func pendingReviews(req: Request) async throws -> View {
        let tongs = try await req.reviewService.pendingReviews()
        return try await req.view.render("admin/reviews", ReviewListContext(tongs: tongs)).get()
    }

    @Sendable
    func approve(req: Request) async throws -> Response {
        let tongId = try req.parameters.require("tongID", as: UUID.self)
        try await req.reviewService.approve(tongId)
        try await req.cache.delete([TongDTO].self)
        return req.redirect(to: "/admin")
    }

    @Sendable
    func reject(req: Request) async throws -> Response {
        let tongId = try req.parameters.require("tongID", as: UUID.self)
        let reason = try req.content.decode(RejectRequest.self).reason
        try await req.reviewService.reject(tongId, reason: reason)
        try await req.cache.delete([TongDTO].self)
        return req.redirect(to: "/admin")
    }

    @Sendable
    func disable(req: Request) async throws -> Response {
        let tongId = try req.parameters.require("tongID", as: UUID.self)
        try await req.reviewService.disable(tongId)
        try await req.cache.delete([TongDTO].self)
        return req.redirect(to: "/admin")
    }

    @Sendable
    func screensPage(req: Request) async throws -> View {
        let adminUser = Environment.get("ADMIN_USER") ?? "admin"
        let adminPassword = Environment.get("ADMIN_PASSWORD") ?? "dev-password"
        return try await req.view.render("admin/screens", [
            "adminUser": adminUser,
            "adminPassword": adminPassword
        ]).get()
    }

    @Sendable
    func screenEditPage(req: Request) async throws -> View {
        let screenId = try req.parameters.require("screenId", as: String.self)
        let adminUser = Environment.get("ADMIN_USER") ?? "admin"
        let adminPassword = Environment.get("ADMIN_PASSWORD") ?? "dev-password"
        return try await req.view.render("admin/screen-edit", [
            "screenId": screenId,
            "adminUser": adminUser,
            "adminPassword": adminPassword
        ]).get()
    }
}
