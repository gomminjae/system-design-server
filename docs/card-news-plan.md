# 카드뉴스 기능 설계

인스타그램 카드뉴스 형식 참고. 여러 장의 이미지+텍스트 카드를 좌우 스와이프로 넘기는 콘텐츠.

## DB 모델

### CardNews

| 컬럼 | 타입 | 설명 |
|---|---|---|
| id | UUID | PK |
| title | String | 카드뉴스 제목 |
| subtitle | String? | 부제 |
| thumb_url | String? | 대표 이미지 (목록용) |
| category | String | 카테고리 slug (personality, love 등) |
| status | String | draft / published |
| created_at | Timestamp | |
| updated_at | Timestamp | |

### CardNewsPage (카드 한 장)

| 컬럼 | 타입 | 설명 |
|---|---|---|
| id | UUID | PK |
| card_news_id | UUID | FK → CardNews |
| page_index | Int | 순서 (0부터) |
| image_url | String | 카드 이미지 URL |
| title | String? | 카드 제목 (이미지 위 오버레이 or 하단) |
| body | String? | 본문 텍스트 |
| bg_color | String? | 배경색 (이미지 없을 때) |

## API

### 공개

| 메서드 | 경로 | 설명 |
|---|---|---|
| GET | /card-news | 카드뉴스 목록 (커서 페이징, 카테고리 필터) |
| GET | /card-news/:id | 카드뉴스 상세 (페이지 전체 포함) |

### 어드민

| 메서드 | 경로 | 설명 |
|---|---|---|
| GET | /admin/api/card-news | 전체 목록 |
| POST | /admin/api/card-news | 생성 (페이지 포함) |
| PUT | /admin/api/card-news/:id | 수정 |
| PUT | /admin/api/card-news/:id/publish | 발행 토글 |
| DELETE | /admin/api/card-news/:id | 삭제 |

## 응답 예시

### GET /card-news/:id

```json
{
  "data": {
    "id": "...",
    "title": "MBTI별 연애 스타일",
    "subtitle": "16가지 유형 분석",
    "thumbURL": "https://...",
    "category": "personality",
    "pageCount": 5,
    "pages": [
      {
        "pageIndex": 0,
        "imageURL": "https://...",
        "title": "ENFP의 연애",
        "body": "ENFP는 열정적이고 낭만적인..."
      },
      {
        "pageIndex": 1,
        "imageURL": "https://...",
        "title": "INTJ의 연애",
        "body": null
      }
    ]
  }
}
```

### GET /card-news (목록)

```json
{
  "data": {
    "items": [
      {
        "id": "...",
        "title": "MBTI별 연애 스타일",
        "subtitle": "16가지 유형 분석",
        "thumbURL": "https://...",
        "category": "personality",
        "pageCount": 5
      }
    ],
    "nextCursor": "...",
    "hasMore": false
  }
}
```

## SDUI 연동

### SectionType 추가

- `card_news_list` — 카드뉴스 목록 (가로 스크롤 or 그리드)
- `card_news_card` — 단일 카드뉴스 카드 (추천용)

### SectionData 추가 필드

- `cardNewsItems: [CardNewsListItem]?` — card_news_list용
- `cardNewsId: String?` — card_news_card용 (동적 바인딩)

### ScreenResolver 확장

- `card_news_list` + `categorySlug` → 해당 카테고리 발행 카드뉴스로 items 채움
- `card_news_card` + `cardNewsId` → 실제 카드뉴스에서 필드 hydrate

### 홈 화면 예시

```json
{
  "sections": [
    { "id": "s1", "type": "category_chips", "data": {} },
    { "id": "s2", "type": "tong_list", "data": { "headerTitle": "인기 테스트", "categorySlug": "personality", "limit": 10 } },
    { "id": "s3", "type": "card_news_list", "data": { "headerTitle": "오늘의 카드뉴스", "categorySlug": "cardnews", "limit": 5 } }
  ]
}
```

## 구현 순서

1. CardNews + CardNewsPage 모델 / 마이그레이션
2. CardNewsRepository + CardNewsService
3. 공개 API (목록 + 상세)
4. 어드민 API (CRUD + 발행)
5. SDUI 섹션 타입 + ScreenResolver 확장
6. 어드민 CMS 페이지 (Leaf)
