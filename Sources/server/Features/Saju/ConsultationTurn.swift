import Fluent
import struct Foundation.UUID
import struct Foundation.Date

/// 상담 문답 한 턴. 손님 질문 + 무당 답변을 한 행으로 저장한다.
/// 다음 질문 때 이걸 순서대로 다시 넣어 무당이 맥락을 이어가게 한다.
final class ConsultationTurn: Model, @unchecked Sendable {
    static let schema = "consultation_turns"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "consultation_id")
    var consultation: Consultation

    /// 손님이 물은 고민(원문).
    @Field(key: "question")
    var question: String

    /// 무당의 답변(GPT 결과).
    @Field(key: "answer")
    var answer: String

    /// 상담 방식. 지금은 "decision"(결정 도우미)만. 이후 "free" 등 확장 자리.
    @Field(key: "mode")
    var mode: String

    /// 두 갈래 고민일 때의 선택지. 한 갈래면 nil.
    @OptionalField(key: "option_a") var optionA: String?
    @OptionalField(key: "option_b") var optionB: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}
}
