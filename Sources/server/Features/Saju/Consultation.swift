import Fluent
import SajuKit
import struct Foundation.UUID
import struct Foundation.Date

/// 결정 상담 세션. 사주 손님이 결제하고 무당에게 콕 집어 묻는 자리.
/// 질문 카운트를 서버가 쥐고 있어야 결제 게이팅이 유지된다(클라 조작·재설치 리셋 방지).
///
/// 사주 입력값을 그대로 저장하고, 질문마다 SajuKit으로 재계산한다(순수 함수라 저렴).
final class Consultation: Model, @unchecked Sendable {
    static let schema = "consultations"

    @ID(key: .id)
    var id: UUID?

    // 사주 입력 — SajuRequest 필드와 1:1.
    @Field(key: "year") var year: Int
    @Field(key: "month") var month: Int
    @Field(key: "day") var day: Int
    @OptionalField(key: "hour") var hour: Int?
    @OptionalField(key: "minute") var minute: Int?
    @OptionalField(key: "gender") var gender: String?
    @OptionalField(key: "calendar") var calendar: String?
    @OptionalField(key: "leap") var leap: Bool?
    @OptionalField(key: "longitude") var longitude: Double?
    @OptionalField(key: "apply_local_mean_time") var applyLocalMeanTime: Bool?

    /// 어느 무당과 상담 중인지. "ghost" | "money".
    @Field(key: "persona") var persona: String

    /// 결제로 확보한 질문 수.
    @Field(key: "questions_allowed") var questionsAllowed: Int
    /// 이미 쓴 질문 수. ask 성공마다 +1.
    @Field(key: "questions_used") var questionsUsed: Int

    /// 결제 참조(주문번호 등). 결제 연동 자리 — 지금은 nil.
    @OptionalField(key: "order_ref") var orderRef: String?

    /// 이 상담의 문답 기록. 무당이 맥락(이전 질문)을 이어가는 근거.
    @Children(for: \.$consultation)
    var turns: [ConsultationTurn]

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    /// 저장된 입력 → SajuKit 입력. 매 질문마다 사주 재계산에 쓴다.
    var toInput: SajuInput {
        SajuInput(
            year: year, month: month, day: day, hour: hour, minute: minute,
            gender: gender.flatMap(Gender.init(rawValue:)),
            calendar: calendar.flatMap(CalendarType.init(rawValue:)),
            leap: leap, longitude: longitude, applyLocalMeanTime: applyLocalMeanTime)
    }

    var questionsRemaining: Int { max(0, questionsAllowed - questionsUsed) }
}
