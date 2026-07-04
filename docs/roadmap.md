# cosmi 서버 로드맵

포지션: "봉봉 테스트 + 인스타 카드뉴스 + 토스 미니앱" 통합 종합 콘텐츠 플랫폼

## Phase 1 — 런칭 전 (필수)

### 1-1. 카드뉴스 모듈
- CardNews + CardNewsPage DB 모델
- 공개 API: 목록(커서 페이징) + 상세
- 어드민 API: CRUD + 발행
- SDUI 섹션 타입 (card_news_list, card_news_card) + ScreenResolver 확장
- 상세: docs/card-news-plan.md

### 1-2. 공유/바이럴
- 통 결과 공유용 딥링크 생성 API
- OG 메타태그 렌더링 (카카오톡/인스타 미리보기용)
- 공유 URL: /share/tongs/:id, /share/card-news/:id

### 1-3. 조회수/참여 통계
- Tong, CardNews에 view_count 컬럼 추가
- POST /tongs/:id/view — 조회 기록 (중복 방지: 유저+콘텐츠 당일 1회)
- 카탈로그 정렬 옵션: ?sort=latest | popular

### 1-4. 푸시 알림
- FCM 토큰 저장 (User에 device_token 추가)
- 어드민에서 수동 푸시 발송 API
- 신규 콘텐츠 발행 시 자동 알림 (선택)

## Phase 2 — 런칭 후 (중기)

### 2-1. 테스트 결과 저장
- UserResult 모델 (user_id, tong_id, result_data JSON, created_at)
- GET /my/results — 내 결과 모아보기

### 2-2. 검색
- GET /search?q=MBTI — 통 + 카드뉴스 통합 검색
- Postgres full-text search 또는 LIKE 기반 (초기)

### 2-3. 좋아요/북마크
- UserBookmark 모델 (user_id, content_type, content_id)
- POST/DELETE /bookmarks
- GET /my/bookmarks

### 2-4. 크리에이터 대시보드
- GET /my/submissions — 내 제출 현황 (승인/반려/조회수)
- 외부 창작자 온보딩 시 필요

### 2-5. 광고/수익화
- 배너 섹션 타입 (SDUI banner)
- 리워드 광고 연동 포인트

## Phase 3 — 장기

### 3-1. 추천 알고리즘
- 조회/참여/북마크 데이터 기반 개인화 피드
- collaborative filtering 또는 content-based

### 3-2. 댓글/커뮤니티
- Comment 모델 (content_type, content_id, user_id, body)
- 신고/차단

### 3-3. 크리에이터 수익 분배
- 조회수 기반 정산 모델
- 크리에이터 출금 API

## 현재 완료된 것

- [x] Tong 모델 + 카탈로그 (커서 페이징)
- [x] 번들 업로드/서빙 (ZIP → 로컬 디스크)
- [x] 심사 (승인/반려/비활성화)
- [x] 인증 (Apple/Kakao OIDC + JWT)
- [x] SDUI (Screen + Section + ScreenResolver 동적 바인딩)
- [x] 카테고리 (시드 8종 + API)
- [x] 앱 버전 관리
- [x] 인메모리 캐시 (타입 기반 키)
- [x] 어드민 CMS (Leaf SSR)
- [x] Docker Postgres
