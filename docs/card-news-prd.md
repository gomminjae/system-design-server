# PRD: 카드뉴스(CardNews) 모듈

**작성자**: gomminjae
**작성일**: 2026-06-05
**상태**: Draft
**전략 프레임**: 런칭 전 — 목표는 **유저 획득·바이럴 성장** (수익화 아님)

---

## 1. Executive Summary

통스통스에 **인스타그램 카드뉴스 형식**(이미지+텍스트 여러 장을 좌우 스와이프)의 두 번째 핵심 콘텐츠 축을 추가한다. 어드민이 CMS로 카드뉴스를 발행하고, 앱 홈(SDUI)에 노출해 **스크린샷·공유 친화적인 콘텐츠로 신규 유저 유입을 만든다.** 기존 Tong(미니앱) 인프라 패턴(커서 페이징·응답 봉투·SDUI resolver·Leaf 어드민)을 그대로 재사용한다.

## 2. Background & Context

- 통스통스는 *"봉봉 테스트 + 인스타 카드뉴스 + 토스 미니앱"* 통합 콘텐츠 플랫폼을 지향한다. 현재 콘텐츠 축은 **Tong(웹 미니앱) 하나뿐**이라 콘텐츠 다양성과 공유 표면이 부족하다.
- **성장 구조가 바이럴 의존적**이다 (콘텐츠가 퍼져야 유입). 인스타 카드뉴스 형식은 본질적으로 **캡처·공유가 잘 되는 포맷**이라, 공유/바이럴 기능(별도 과제)의 연료가 된다.
- 우선순위 분석(ICE + 전략·의존성) 결과 카드뉴스가 "지금 시작" 1순위: **설계 완료 + 기존 패턴 재사용으로 리스크 최저**, 그리고 공유 기능보다 먼저 깔아야 공유의 가치가 산다.

## 3. Objectives & Success Metrics

**Goals**
1. 어드민이 코드 배포 없이 카드뉴스를 발행하고 홈에 노출할 수 있다.
2. 앱이 카드뉴스 목록·상세를 안정적으로 받아 렌더할 수 있다 (기존 SDUI/봉투 계약 준수).
3. 카드뉴스가 **공유 친화적 콘텐츠 표면**으로 동작해 신규 유입에 기여한다.

**Non-Goals** (이번 스코프 제외)
1. **외부 창작자 카드뉴스 제출** — 우선 어드민 전용 (Tong처럼 제출/심사 흐름은 후속)
2. **공유 딥링크 + OG 메타 렌더링** — 별도 과제(공유/바이럴 #2). 본 PRD는 콘텐츠 발행·노출까지.
3. **이미지 업로드 파이프라인** — 우선 어드민이 외부/CDN 이미지 URL 입력 (업로드는 후속)
4. **조회수·좋아요·댓글** — 별도 과제(조회수 #3 / Phase 3)
5. **수익화 로직(광고/리워드/결제)** — Phase 2. 단, `is_sponsored`/`is_premium` **플래그(데이터)는 지금 심어둠**(수익화-레디). 로직·페이월·광고는 제외, API 노출(뱃지 표시용)까지만.

**Success Metrics** (런칭 ~ 4주 선행지표)
| 지표 | 현재 | 목표 | 측정 |
|---|---|---|---|
| 발행 카드뉴스 수 | 0 | 런칭 시 ≥ 20편 | DB count(status=published) |
| 홈 카드뉴스 섹션 CTR | N/A | ≥ 15% | (별도 추적 도입 후) 섹션 노출 대비 탭 |
| 카드뉴스 완독률(마지막 장 도달) | N/A | ≥ 40% | 클라 이벤트(후속 추적) |
| 공유 전환(공유/조회) | N/A | ≥ 8% | (공유 기능 도입 후) |
| 카드뉴스 경유 신규 유입 비중 | 0% | ≥ 20% | (공유 딥링크 도입 후 어트리뷰션) |

> 완독률·CTR·공유는 추적(이벤트/조회수) 기능 도입 후 측정 가능 → 본 모듈은 그 **데이터 표면을 깔되**, 측정 자체는 후속 과제와 연동.

## 4. Target Users & Segments

- **소비자(앱 유저)** — 가볍게 즐길 콘텐츠를 찾는 일반 유저. 카드뉴스를 스와이프로 소비하고 공유한다. (주 타깃)
- **운영자(어드민)** — 카드뉴스를 기획·발행하는 내부 운영. CMS로 카드 구성·발행. (이번 스코프의 직접 사용자)
- (후속) 외부 창작자 — 본 스코프 제외.

## 5. User Stories & Requirements

**P0 — Must Have (런칭 필수)**
| # | User Story | Acceptance Criteria |
|---|---|---|
| 1 | 운영자로서 카드뉴스(제목·부제·카테고리·대표이미지)와 여러 장의 카드(이미지/제목/본문/배경색)를 생성한다 | POST /admin/api/card-news 로 카드뉴스+페이지 일괄 생성, page_index 순서 보존 |
| 2 | 운영자로서 카드뉴스를 수정/삭제/발행토글한다 | PUT(수정), PUT /:id/publish(토글), DELETE. 발행본만 공개 노출 |
| 3 | 앱으로서 발행된 카드뉴스 목록을 카테고리 필터·커서 페이징으로 받는다 | GET /card-news?category=&after=&limit= → APIResponse<CursorList<...>>, 발행본만 |
| 4 | 앱으로서 카드뉴스 상세(페이지 전체)를 받는다 | GET /card-news/:id → 페이지 page_index 오름차순 포함, 발행본만(미발행 404) |
| 5 | 앱으로서 홈(SDUI)에서 카드뉴스 섹션을 본다 | card_news_list 섹션 + categorySlug 동적 바인딩 → 발행 카드뉴스로 items 채움 |
| 6 | 운영자로서 어드민 웹에서 카드뉴스를 관리한다 | Leaf CMS 페이지(목록/편집), 기존 화면관리 UX와 일관 |
| 7 | 데이터 정합성: 'cardnews'를 Tong 카테고리에서 제거 | 시드/마이그레이션 정리, 카드뉴스는 자체 category(personality 등) 재사용 |

**P1 — Should Have**
| # | User Story | Acceptance Criteria |
|---|---|---|
| 8 | 단일 카드뉴스 추천 섹션 | card_news_card 섹션 + cardNewsId 동적 hydrate |
| 9 | 대표이미지 자동 | thumbnail_url 비면 첫 페이지 image_url을 대표로 사용 |
| 10 | 카드뉴스 응답에 pageCount 노출 | 목록 항목에 페이지 수 포함(미리보기용) |

**P2 — Nice to Have / Future**
| # | User Story | Acceptance Criteria |
|---|---|---|
| 11 | 외부 창작자 카드뉴스 제출/심사 | Tong 제출 흐름 재사용 |
| 12 | 페이지별 드롭오프 분석 | page_index별 이탈 추적 |
| 13 | 통합 검색에 카드뉴스 포함 | GET /search 에 카드뉴스 합치기 |

## 6. Solution Overview

**데이터 모델** (정규화 — 우리가 막 익힌 @Parent/@Children 관계 재사용)
- `CardNews` (id, title, subtitle?, thumbnail_url?, category, status[draft/published],
  **is_sponsored**(bool, 기본 false), **sponsor_name?**, **sponsor_link?**,
  **is_premium**(bool, 기본 false), created_at, updated_at)
- `CardNewsPage` (id, `@Parent` card_news_id, page_index, image_url, title?, body?, bg_color?)
- 상세 조회 시 `.with(\.$pages)` eager load → page_index 정렬

> 💰 **수익화-레디 훅 (데이터만, 로직은 없음)**: `is_sponsored`/`sponsor_*`(스폰서 콘텐츠), `is_premium`(페이월) 컬럼을 **지금 비워두기만** 한다. Phase 2 수익화(스폰서/IAP)를 앱·DB 대수술 없이 붙이기 위함. 본 스코프에선 **API 응답에 노출**(스폰서 뱃지·프리미엄 표시용)만 하고, 광고/결제 로직은 구현하지 않는다. (통(Tong)에도 동일 플래그를 후속으로 추가) — 상세 근거: docs/monetization-strategy.md
>
> 🌐 **글로벌 옵션 (테마 원칙만, DB 변경 없음)**: 전략은 **국내(A) 우선 + 글로벌 옵션 유지.** 진짜 훅은 컬럼이 아니라 **콘텐츠 테마를 culture-light(번역 가능)하게 고르는 것** — 비용 0, DB 무관. `locale` 컬럼·i18n·영어 콘텐츠는 **영어 콘텐츠가 실제로 생길 때** 추가(마이그레이션 1줄이라 늦지 않음). 지금은 단일값이라 YAGNI. — 상세: docs/brand-strategy.md, docs/monetization-strategy.md

**API** — 기존 계약 그대로
- 공개: `GET /card-news`(커서 페이징·카테고리 필터), `GET /card-news/:id`(페이지 포함). 전부 `APIResponse` 봉투, `CursorList` 재사용(원격이 추가한 페이징 패턴)
- 어드민: `/admin/api/card-news` CRUD + `/:id/publish` (BasicAuth 그룹, 기존 ScreenAdmin과 동일 패턴)
- 발행본만 공개, 캐시는 카드뉴스 상세/목록에 짧은 TTL

**SDUI 확장**
- `SectionType`에 `card_news_list`, `card_news_card` 추가
- `SectionData`에 `cardNewsItems`, `cardNewsId` 추가
- `ScreenResolver`: card_news_list + categorySlug → 발행 카드뉴스로 items 채움 / card_news_card + cardNewsId → hydrate (기존 tong_list/tong_card 로직 그대로 복제)

**어드민 CMS**: 기존 `screens.leaf`/`screen-edit.leaf` 토스 스타일 재사용한 카드뉴스 목록/편집 Leaf 페이지

**재사용 핵심**: Fluent 모델·마이그레이션, `CursorList`·커서 페이징, `APIResponse` 봉투, `ScreenResolver` 패턴, Leaf 어드민 — **새 개념 거의 없음 → 빠르고 안전.**

## 7. Open Questions

| 질문 | 오너 | 기한 |
|---|---|---|
| 카드뉴스 이미지 호스팅: 외부 URL만 허용(런칭) vs 번들 스토리지 재사용 업로드(후속)? | minjae | 구현 전 |
| 'cardnews' 카테고리 제거가 기존 데이터/홈 목업 섹션 참조에 영향? (참조 시 처리) | minjae | 마이그레이션 설계 시 |
| 홈에서 card_news_list와 tong_list 시각 구분/배치 디자인? | minjae | SDUI 단계 |
| 카드뉴스 상세 **웹 렌더 페이지**(공유 OG용)는 본 스코프 vs 공유 과제(#2)로 분리? | minjae | 본 PRD는 분리 가정 |

## 8. Timeline & Phasing

| 마일스톤 | 내용 | 산출물 |
|---|---|---|
| M1 | 데이터 모델 + 공개 API | CardNews/CardNewsPage 모델·마이그레이션, GET /card-news(목록/상세) |
| M2 | 어드민 API | CRUD + 발행 토글 |
| M3 | SDUI 확장 | card_news_list/card 섹션 + ScreenResolver 확장 + 테스트 |
| M4 | 어드민 CMS | 카드뉴스 목록/편집 Leaf 페이지 |
| Cleanup | 카테고리 정리 | 'cardnews' Tong 카테고리 제거 마이그레이션 |

**의존성**: 없음(독립 모듈). **후속 연동**: 공유/바이럴(#2)·조회수(#3)가 이 모듈의 콘텐츠를 소비.

---

### 다음 액션 옵션
- 스코프 더 조이기 (P1 → P2 강등 검토)
- pre-mortem 돌리기 (런칭 전 리스크 사전 점검)
- 엔지니어링 user stories로 쪼개기 (M1~M4 태스크화)
