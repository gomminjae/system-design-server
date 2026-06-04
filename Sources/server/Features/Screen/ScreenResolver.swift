import Vapor

/// SDUI 동적 바인딩. 저장된 섹션의 참조(categorySlug, tongId)를
/// `GET /screens` 시점에 실제 카탈로그/카테고리 데이터로 채워(hydrate) 내려준다.
///
/// - `tong_list` + `categorySlug` → 해당 카테고리 승인 통으로 items 채움
/// - `tong_card` / `tong_detail` + `tongId` → 실제 통에서 빈 필드만 채움(어드민 입력값 우선)
/// - `category_chips` → 항상 Category 테이블로 chips 생성
struct ScreenResolver {
    let tongs: any TongRepository
    let categories: CategoryService

    func resolve(_ sections: [Section]) async throws -> [Section] {
        // card/detail이 참조하는 통 id를 모아 한 번에 조회(N+1 방지).
        let referencedIDs = sections.compactMap { section -> UUID? in
            guard section.type == .tongCard || section.type == .tongDetail else { return nil }
            return section.data.tongId.flatMap(UUID.init(uuidString:))
        }
        let tongsByID = try await tongs.approvedByIDs(referencedIDs)

        var resolved: [Section] = []
        for section in sections {
            switch section.type {
            case .tongList:
                resolved.append(try await resolveTongList(section))
            case .tongCard, .tongDetail:
                resolved.append(resolveTongRef(section, tongsByID: tongsByID))
            case .categoryChips:
                resolved.append(try await resolveChips(section))
            default:
                resolved.append(section)
            }
        }
        return resolved
    }

    /// tong_list: categorySlug 지정 시 승인 통으로 items 채움. 미지정이면 정적 items 유지.
    private func resolveTongList(_ section: Section) async throws -> Section {
        guard let slug = section.data.categorySlug, !slug.isEmpty else { return section }
        let limit = section.data.limit ?? 10
        let items = try await tongs.getApproved(category: slug, after: nil, limit: limit).map { $0.toItem() }
        var data = section.data
        data.items = items
        return Section(id: section.id, type: section.type, data: data, action: section.action)
    }

    /// tong_card / tong_detail: 실제 통에서 비어 있는 필드만 채운다(어드민 오버라이드 우선).
    private func resolveTongRef(_ section: Section, tongsByID: [UUID: Tong]) -> Section {
        guard let idString = section.data.tongId,
              let id = UUID(uuidString: idString),
              let tong = tongsByID[id] else { return section }

        var data = section.data
        if isBlank(data.title) { data.title = tong.title }
        if isBlank(data.subtitle) { data.subtitle = tong.subtitle }
        if isBlank(data.thumbURL) { data.thumbURL = tong.thumbURL }
        if isBlank(data.bundleURL) { data.bundleURL = tong.bundleURL }

        var action = section.action
        if var existing = action, isBlank(existing.bundleURL) {
            existing.bundleURL = tong.bundleURL
            if isBlank(existing.tongId) { existing.tongId = idString }
            action = existing
        }
        return Section(id: section.id, type: section.type, data: data, action: action)
    }

    /// category_chips: 항상 Category 테이블로 chips 생성. 맨 앞에 "전체" 칩 추가.
    private func resolveChips(_ section: Section) async throws -> Section {
        let cats = try await categories.list()
        var chips = [CategoryChip(id: "all", label: "전체")]
        chips.append(contentsOf: cats.map { CategoryChip(id: $0.slug, label: $0.name) })

        var data = section.data
        data.chips = chips
        if isBlank(data.selectedId) { data.selectedId = "all" }
        return Section(id: section.id, type: section.type, data: data, action: section.action)
    }

    private func isBlank(_ value: String?) -> Bool {
        (value ?? "").trimmingCharacters(in: .whitespaces).isEmpty
    }
}

extension Tong {
    /// SDUI tong_list 카드 항목으로 변환.
    func toItem() -> TongItem {
        TongItem(
            tongId: self.id?.uuidString ?? "",
            title: self.title,
            subtitle: self.subtitle,
            thumbURL: self.thumbURL,
            badge: nil
        )
    }
}
