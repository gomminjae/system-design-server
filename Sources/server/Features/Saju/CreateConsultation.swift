import Fluent

/// 상담(Consultation) + 문답(ConsultationTurn) 테이블 생성.
/// 두 테이블은 함께 도입되므로 한 마이그레이션으로 묶는다.
struct CreateConsultation: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("consultations")
            .id()
            .field("year", .int, .required)
            .field("month", .int, .required)
            .field("day", .int, .required)
            .field("hour", .int)
            .field("minute", .int)
            .field("gender", .string)
            .field("calendar", .string)
            .field("leap", .bool)
            .field("longitude", .double)
            .field("apply_local_mean_time", .bool)
            .field("persona", .string, .required)
            .field("questions_allowed", .int, .required)
            .field("questions_used", .int, .required)
            .field("order_ref", .string)
            .field("created_at", .datetime)
            .create()

        try await database.schema("consultation_turns")
            .id()
            .field("consultation_id", .uuid, .required,
                   .references("consultations", "id", onDelete: .cascade))
            .field("question", .string, .required)
            .field("answer", .string, .required)
            .field("mode", .string, .required)
            .field("option_a", .string)
            .field("option_b", .string)
            .field("created_at", .datetime)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("consultation_turns").delete()
        try await database.schema("consultations").delete()
    }
}
