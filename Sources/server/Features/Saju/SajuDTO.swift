import Vapor
import SajuKit

/// 사주 계산 요청 (생년월일시).
struct SajuRequest: Content {
    let year: Int
    let month: Int
    let day: Int
    let hour: Int?
    let minute: Int?
    let gender: String?   // "남" | "여"
    let calendar: String? // "solar" | "lunar"
    let leap: Bool?
    let longitude: Double?
    let applyLocalMeanTime: Bool?

    var toInput: SajuInput {
        SajuInput(
            year: year, month: month, day: day, hour: hour, minute: minute,
            gender: gender.flatMap(Gender.init(rawValue:)),
            calendar: calendar.flatMap(CalendarType.init(rawValue:)),
            leap: leap, longitude: longitude, applyLocalMeanTime: applyLocalMeanTime
        )
    }
}

/// 사주 계산 결과 — GPT 무당 해석에 넘길 데이터 (신빙성 풀세트).
struct SajuDTO: Content {
    struct Solar: Content { let year: Int; let month: Int; let day: Int }
    struct PillarDTO: Content { let stem: String; let branch: String; let ganzhi: String }
    struct Pillars: Content { let year: PillarDTO; let month: PillarDTO; let day: PillarDTO; let hour: PillarDTO }
    struct TenGodDTO: Content { let stem: String; let branch: String }
    struct TenGods: Content { let year: TenGodDTO; let month: TenGodDTO; let day: TenGodDTO; let hour: TenGodDTO }
    struct DaeunItemDTO: Content { let startAge: Int; let startYear: Int; let ganzhi: String; let stemTenGod: String; let branchTenGod: String }
    struct Daeun: Content { let startAge: Int; let list: [DaeunItemDTO] }
    struct Stages12DTO: Content {
        struct Per: Content { let year: String; let month: String; let day: String; let hour: String }
        let bong: Per; let geo: Per
    }
    struct SalsDTO: Content {
        struct Per: Content { let twelveSal: String; let specialSals: [String] }
        let year: Per; let month: Per; let day: Per; let hour: Per
    }
    struct StemRelDTO: Content { let type: String; let pillars: [String]; let desc: String; let stems: [String] }
    struct AdvancedDTO: Content {
        struct DS: Content { let strength: String; let score: Int }
        struct SS: Content { let gilsin: [String]; let hyungsin: [String] }
        let dayStrength: DS; let geukguk: String; let yongsin: [String]; let sinsal: SS
    }

    let solar: Solar
    let pillars: Pillars
    let fiveElements: [String: Int]
    let tenGods: TenGods
    let daeun: Daeun
    let gongmang: [String]
    let stages12: Stages12DTO
    let sals: SalsDTO
    let stemRelations: [StemRelDTO]
    let branchRelations: [String: [String: String]]
    let advanced: AdvancedDTO

    init(_ r: SajuResult) {
        solar = Solar(year: r.solarYear, month: r.solarMonth, day: r.solarDay)
        func p(_ x: Pillar) -> PillarDTO { PillarDTO(stem: x.stem, branch: x.branch, ganzhi: x.ganzhi) }
        pillars = Pillars(year: p(r.pillars.year), month: p(r.pillars.month), day: p(r.pillars.day), hour: p(r.pillars.hour))
        fiveElements = r.fiveElements
        func t(_ x: Analyze.TenGodPair) -> TenGodDTO { TenGodDTO(stem: x.stem, branch: x.branch) }
        tenGods = TenGods(year: t(r.tenGods.year), month: t(r.tenGods.month), day: t(r.tenGods.day), hour: t(r.tenGods.hour))
        daeun = Daeun(
            startAge: r.daeun.startAge,
            list: r.daeun.list.map {
                DaeunItemDTO(startAge: $0.startAge, startYear: $0.startYear, ganzhi: $0.ganzhi,
                            stemTenGod: $0.stemTenGod, branchTenGod: $0.branchTenGod)
            }
        )
        gongmang = r.gongmang
        func st(_ x: Analyze.Stages12.PerPillar) -> Stages12DTO.Per { Stages12DTO.Per(year: x.year, month: x.month, day: x.day, hour: x.hour) }
        stages12 = Stages12DTO(bong: st(r.stages12.bong), geo: st(r.stages12.geo))
        func sa(_ x: Analyze.Sals.PerPillar) -> SalsDTO.Per { SalsDTO.Per(twelveSal: x.twelveSal, specialSals: x.specialSals) }
        sals = SalsDTO(year: sa(r.sals.year), month: sa(r.sals.month), day: sa(r.sals.day), hour: sa(r.sals.hour))
        stemRelations = r.stemRelations.map { StemRelDTO(type: $0.type, pillars: $0.pillars, desc: $0.desc, stems: $0.stems) }
        branchRelations = r.branchRelations
        advanced = AdvancedDTO(
            dayStrength: .init(strength: r.advanced.dayStrength.strength, score: r.advanced.dayStrength.score),
            geukguk: r.advanced.geukguk, yongsin: r.advanced.yongsin,
            sinsal: .init(gilsin: r.advanced.sinsal.gilsin, hyungsin: r.advanced.sinsal.hyungsin)
        )
    }
}
