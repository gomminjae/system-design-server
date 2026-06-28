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
        // 카드뉴스 CMS 페이지
        admin.get("card-news", use: self.cardNewsPage)
        admin.get("card-news", ":cardNewsId", "edit", use: self.cardNewsEditPage)
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

    // 어드민 비번은 클라이언트로 내려보내지 않는다. 페이지가 Basic Auth로 보호되므로
    // 브라우저가 같은 origin의 fetch에 자격증명을 자동 첨부한다(leaf에서 헤더 수동 구성 X).
    @Sendable
    func screensPage(req: Request) async throws -> View {
        return try await req.view.render("admin/screens").get()
    }

    @Sendable
    func screenEditPage(req: Request) async throws -> View {
        let screenId = try req.parameters.require("screenId", as: String.self)
        return try await req.view.render("admin/screen-edit", ["screenId": screenId]).get()
    }

    @Sendable
    func cardNewsPage(req: Request) async throws -> View {
        return try await req.view.render("admin/card-news").get()
    }

    @Sendable
    func cardNewsEditPage(req: Request) async throws -> View {
        let cardNewsId = try req.parameters.require("cardNewsId", as: String.self)
        return try await req.view.render("admin/card-news-edit", ["cardNewsId": cardNewsId]).get()
    }
}
