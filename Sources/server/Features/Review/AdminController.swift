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
    }

    @Sendable
    func pendingReviews(req: Request) async throws -> View {
        let tongs = try await req.reviewService.pendingReviews()
        return try await req.view.render("admin/queue", ReviewQueueContext(tongs: tongs)).get()
    }

    @Sendable
    func approve(req: Request) async throws -> Response {
        let tongId = try req.parameters.require("tongID", as: UUID.self)
        try await req.reviewService.approve(tongId)
        return req.redirect(to: "/admin")
    }

    @Sendable
    func reject(req: Request) async throws -> Response {
        let tongId = try req.parameters.require("tongID", as: UUID.self)
        let reason = try req.content.decode(RejectRequest.self).reason
        try await req.reviewService.reject(tongId, reason: reason)
        return req.redirect(to: "/admin")
    }

    @Sendable
    func disable(req: Request) async throws -> Response {
        let tongId = try req.parameters.require("tongID", as: UUID.self)
        try await req.reviewService.disable(tongId)
        return req.redirect(to: "/admin")
    }
}
