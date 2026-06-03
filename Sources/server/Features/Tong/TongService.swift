import Vapor

/// 통 CRUD 비즈니스 로직.
struct TongService {
    let repository: any TongRepository

    func catalog() async throws -> [TongDTO] {
        try await repository.approved().map { $0.toDTO() }
    }

    func submit(_ submission: TongSubmission) async throws -> Tong {
        let tong = submission.toModel()
        try await repository.save(tong)
        return tong
    }

    func find(_ id: UUID) async throws -> Tong {
        guard let tong = try await repository.find(id) else {
            throw APIError.notFound("통을 찾을 수 없습니다.")
        }
        return tong
    }
}
