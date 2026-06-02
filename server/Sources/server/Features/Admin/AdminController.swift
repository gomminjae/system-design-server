import Fluent
import Vapor

/// 백오피스(심사) — Leaf SSR 페이지. Basic Auth 보호 그룹 하위에 등록 → 최종 경로 /admin/...
struct AdminController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let admin = routes.grouped("admin")
        admin.get(use: self.queue)                          // GET  /admin            심사 큐 페이지
        admin.group("tongs", ":tongID") { tong in
            tong.post("approve", use: self.approve)         // POST /admin/tongs/:id/approve
            tong.post("reject", use: self.reject)           // POST /admin/tongs/:id/reject
            tong.post("disable", use: self.disable)         // POST /admin/tongs/:id/disable (kill switch)
        }
    }

    /// 심사 큐 페이지 — submitted / inReview 상태의 통 목록을 렌더.
    @Sendable
    func queue(req: Request) async throws -> View {
        let tongs = try await Tong.query(on: req.db)
            .group(.or) { or in
                or.filter(\.$status == .submitted)
                or.filter(\.$status == .inReview)
            }
            .sort(\.$createdAt, .ascending)
            .all()
            .map { $0.toDTO() }
        return try await req.view.render("queue", AdminQueueContext(tongs: tongs)).get()
    }

    @Sendable
    func approve(req: Request) async throws -> Response {
        let tong = try await find(req)
        tong.status = .approved
        tong.rejectionReason = nil
        try await tong.save(on: req.db)
        return req.redirect(to: "/admin")
    }

    @Sendable
    func reject(req: Request) async throws -> Response {
        let reason = try req.content.decode(RejectRequest.self).reason
        let tong = try await find(req)
        tong.status = .rejected
        tong.rejectionReason = reason
        try await tong.save(on: req.db)
        return req.redirect(to: "/admin")
    }

    @Sendable
    func disable(req: Request) async throws -> Response {
        let tong = try await find(req)
        tong.status = .disabled
        try await tong.save(on: req.db)
        return req.redirect(to: "/admin")
    }

    /// 경로의 :tongID로 통을 찾는다. 없으면 404.
    private func find(_ req: Request) async throws -> Tong {
        guard let tong = try await Tong.find(req.parameters.get("tongID"), on: req.db) else {
            throw Abort(.notFound, reason: "통을 찾을 수 없습니다.")
        }
        return tong
    }
}
