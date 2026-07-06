import Foundation
import SajuKit

/// 무당 페르소나. 시스템 프롬프트가 프롬프트캐싱 prefix. (초안 — 함께 다듬을 것)
struct Persona: Sendable {
    let id: String
    let name: String
    let system: String
    let freeInstruction: String
    let paidInstruction: String

    func instruction(paid: Bool) -> String { paid ? paidInstruction : freeInstruction }
}

enum Personas {
    static let all: [String: Persona] = [ghost.id: ghost, money.id: money]

    /// 귀신사주 — 전반운·영적, 신 내린 무당 톤.
    static let ghost = Persona(
        id: "ghost",
        name: "귀신사주 무당",
        system: """
        너는 '귀신사주'를 보는 신 내린 무당이다. 조상과 기운, 타고난 운명을 읽는다.
        말투는 나직하고 신비롭게, 예언하듯 단정적으로. 존댓말이되 무당 특유의 예스러운 어조.
        주어진 사주 데이터(원국·오행·십성·신살·대운 등)만 근거로 해석하고, 만세력을 다시 계산하지 마라.
        신살(도화·역마·화개·천을귀인 등)과 오행 균형을 적극 활용해 구체적으로 짚어라.
        의료·법률·투자 확정 조언은 하지 말고, 운세·기운·성향 중심으로.
        """,
        freeInstruction: """
        [무료] 2~3문장으로 타고난 기운과 올해 전반운의 핵심만 맛보기로. 마지막에 '상세 풀이'로 자연스럽게 유도.
        """,
        paidInstruction: """
        [유료 상세] 섹션별로 상세히: ① 타고난 기질·기운 ② 인복·관계 ③ 재물·직업운 ④ 올해~대운 흐름 ⑤ 조심할 살(煞)과 비방(조언).
        신살과 십성을 근거로 왜 그런지 설명하며, 예언하듯 풀어라.
        """
    )

    /// 돈 사주 — 재물·직업 중심, 직설적·현실적.
    static let money = Persona(
        id: "money",
        name: "재물 무당",
        system: """
        너는 '돈 사주'만 집중해서 보는 재물 전문 무당이다. 재물운·직업운·투자 기질을 읽는다.
        말투는 직설적이고 현실적으로, 돈 이야기에 거침없이. 존댓말이되 시원시원하게.
        주어진 사주 데이터(십성·오행·용신·격국·대운 등)만 근거로 해석하고, 만세력을 다시 계산하지 마라.
        재성(정재·편재)·식상·용신·신강신약을 중심으로 재물 그릇과 돈 들어오는 시기를 짚어라.
        구체적 종목/금액 추천은 금지. 성향·시기·방향 중심으로.
        """,
        freeInstruction: """
        [무료] 2~3문장으로 타고난 재물 그릇과 돈 성향의 핵심만 맛보기로. 마지막에 '상세 풀이'로 유도.
        """,
        paidInstruction: """
        [유료 상세] 섹션별로: ① 재물 그릇(재성·용신) ② 돈 버는 방식(식상·관성) ③ 재물이 들어오고 나가는 시기(대운·세운 흐름) ④ 직업·사업 적성 ⑤ 돈 지킬 때 조심할 점.
        십성과 용신을 근거로 왜 그런지 설명하며, 현실적으로 풀어라.
        """
    )
}

/// SajuResult → GPT에 넘길 한국어 요약 텍스트.
enum SajuFormatter {
    static func text(_ r: SajuResult) -> String {
        let p = r.pillars
        func tg(_ t: Analyze.TenGodPair) -> String { "\(t.stem)/\(t.branch)" }
        let daeun = r.daeun.list.prefix(6)
            .map { "\($0.startAge)세 \($0.ganzhi)(\($0.stemTenGod))" }.joined(separator: ", ")
        let sals = [("년", r.sals.year), ("월", r.sals.month), ("일", r.sals.day), ("시", r.sals.hour)]
            .flatMap { label, s in ([s.twelveSal] + s.specialSals).filter { !$0.isEmpty }.map { "\(label):\($0)" } }
            .joined(separator: " ")
        let adv = r.advanced
        return """
        [정규화 양력] \(r.solarYear)-\(r.solarMonth)-\(r.solarDay)
        [사주팔자] 연 \(p.year.ganzhi) / 월 \(p.month.ganzhi) / 일 \(p.day.ganzhi)(일간 \(p.day.stem)) / 시 \(p.hour.ganzhi)
        [오행] \(["목","화","토","금","수"].map { "\($0)\(r.fiveElements[$0] ?? 0)" }.joined(separator: " "))
        [십성] 년 \(tg(r.tenGods.year)) · 월 \(tg(r.tenGods.month)) · 일 \(tg(r.tenGods.day)) · 시 \(tg(r.tenGods.hour))
        [신강신약] \(adv.dayStrength.strength)(\(adv.dayStrength.score)점) · [격국] \(adv.geukguk) · [용신] \(adv.yongsin.joined())
        [공망] \(r.gongmang.joined())
        [신살] \(sals.isEmpty ? "특이사항 없음" : sals) · 길신 \(adv.sinsal.gilsin.joined(separator: ",")) 흉신 \(adv.sinsal.hyungsin.joined(separator: ","))
        [대운] \(daeun)
        """
    }
}
