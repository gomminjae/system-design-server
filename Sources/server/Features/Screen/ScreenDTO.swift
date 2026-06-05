import Vapor

/// SDUI 페이로드 스키마 버전. 섹션 구조가 바뀌면 올린다(클라 forward-compat 판단용).
enum SDUISchema {
    static let version = 1
}

/// SDUI 화면 응답.
struct ScreenResponse: Content {
    let screenId: String
    let title: String
    let sections: [Section]
    /// 페이로드 스키마 버전. 클라가 이 버전을 보고 호환 여부를 판단한다.
    var schemaVersion: Int = SDUISchema.version
}

/// SDUI 섹션 — 화면을 구성하는 독립적 목적 단위.
struct Section: Content {
    let id: String
    let type: SectionType
    let data: SectionData
    let action: SectionAction?
}

/// 섹션 타입 — 토스 방식 (섹션 4종 + 공통 컴포넌트 4종).
enum SectionType: String, Content {
    // 섹션 (비즈니스 단위)
    case carousel               // 슬라이드 배너
    case tongList = "tong_list" // 통 카드 목록
    case categoryChips = "category_chips" // 카테고리 필터
    case tongDetail = "tong_detail"       // 통 상세

    // 카드뉴스
    case cardNewsList = "card_news_list"  // 카드뉴스 목록 (가로 스크롤/그리드)
    case cardNewsCard = "card_news_card"  // 단일 카드뉴스 카드 (추천 등)

    // 공통 컴포넌트
    case sectionHeader = "section_header" // 제목 + 부제 + 더보기
    case divider                          // 구분선
    case ctaButton = "cta_button"         // 행동 유도 버튼
    case tongCard = "tong_card"           // 단일 통 카드 (추천 등)
}

/// 섹션 데이터 — 타입별로 필요한 필드만 채운다.
struct SectionData: Content {
    // carousel
    var slides: [CarouselSlide]?
    var duration: Int?              // 자동 슬라이드 간격 (ms)

    // tong_list
    var headerTitle: String?
    var headerSubtitle: String?
    var layout: String?             // "horizontal_scroll" | "grid"
    var showMoreText: String?
    var items: [TongItem]?
    /// 동적 바인딩: 지정 시 서버가 이 카테고리의 승인 통으로 items를 실시간 채운다.
    var categorySlug: String?
    /// 동적 바인딩 최대 개수 (기본 10).
    var limit: Int?

    // card_news_list (tong_list와 동일 패턴: categorySlug/limit 동적 바인딩)
    var cardNewsItems: [CardNewsItem]?
    // card_news_card
    var cardNewsId: String?

    // category_chips
    // chips는 서버가 항상 Category 테이블로 채운다(어드민 수동 입력 없음).
    var chips: [CategoryChip]?
    var selectedId: String?         // 기본 선택 칩 (없으면 "all")

    // tong_detail
    var tongId: String?
    var title: String?
    var subtitle: String?
    var thumbnailURL: String?
    var stats: String?
    var buttonText: String?
    var shareText: String?
    var bundleURL: String?

    // section_header
    // headerTitle, headerSubtitle, showMoreText 공유

    // divider
    var height: Int?                // 구분선 높이 (px)
    var color: String?              // 구분선 색상

    // cta_button
    var buttonLabel: String?
    var buttonStyle: String?        // "primary" | "secondary"

    // tong_card (단일)
    var badge: String?
}

struct CarouselSlide: Content {
    let imageURL: String
    let title: String?
    let subtitle: String?
    let action: SectionAction?
}

struct TongItem: Content {
    let tongId: String
    let title: String
    let subtitle: String?
    let thumbnailURL: String?
    let badge: String?
}

struct CardNewsItem: Content {
    let cardNewsId: String
    let title: String
    let subtitle: String?
    let thumbnailURL: String?
    let pageCount: Int
}

struct CategoryChip: Content {
    let id: String
    let label: String
}

/// 액션 — 사용자 인터랙션 처리.
struct SectionAction: Content {
    let type: ActionType
    var tongId: String?
    var route: String?
    var url: String?
    var text: String?
    var bundleURL: String?
    var categoryId: String?
}

enum ActionType: String, Content {
    case openTong = "open_tong"
    case openWebview = "open_webview"
    case navigate
    case openURL = "open_url"
    case share
}
