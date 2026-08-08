# system-design-server

모바일 시스템 디자인 공부용 백엔드 (Swift / Vapor 4).

모바일 앱을 클라이언트로 가정하고, 백엔드 시스템 디자인 주제를 하나씩 실제 코드로 구현해보는 실험장.

전체 학습 순서와 주제 후보는 [System Design 학습 로드맵](ROADMAP.md)에 정리되어 있다.

## 스택

- Swift 6 / Vapor 4 / Fluent (Postgres, 테스트는 인메모리 SQLite)
- JWT 인증 (Apple Sign In 검증 + 자체 토큰 발급)
- OpenAPI 자동 생성 (`/swagger`)

## 현재 구현된 것

| 영역 | 내용 |
|---|---|
| Auth | Apple Sign In → 자체 JWT 발급, `JWTAuthMiddleware` |
| App | 앱 버전 체크 API (`GET /app/version`) — 강제 업데이트 판단용 min/latest 버전, 인메모리 캐시 |
| Admin | Basic Auth로 보호되는 `/admin/*` (버전 정보 upsert, SDUI Studio CMS) |
| Core | 표준 API 응답/에러 봉투, 에러 미들웨어, 타입 기반 캐시 키 헬퍼 |
| SDUI | 프로젝트별 화면·SEED 기반 브랜드 테마 조회, 컴포넌트 카탈로그 호환성 및 문서 검증 |

## SDUI v1

SDUI 코어는 서비스 도메인과 실제 색상값을 화면에서 분리한다. 현재는 계약을 안정화하기 위해
`demo` 프로젝트의 화면과 테마를 코드로 관리한다.

```bash
# 프로젝트의 현재 테마
curl http://localhost:8080/v1/projects/demo/theme

# 앱이 실제로 그릴 화면 문서
curl -H 'X-SDUI-Catalog-Version: seed-mobile-v1' \
  http://localhost:8080/v1/projects/demo/screens/home
```

v1 컴포넌트 카탈로그는 `vStack`, `hStack`, `text`, `image`, `button`을 지원한다.
화면은 semantic token만 참조하고, 프로젝트별 Light/Dark 브랜드 색상은 Theme 문서에서 제공한다.

## SDUI Studio CMS

`/admin/sdui`에서 화면을 컴포넌트 단위로 조합하고 미리보기할 수 있다. 관리자 Basic Auth로 보호되며,
저장 시 `draft` revision을 만들고 `발행` 시 검증을 통과한 revision만 공개 SDUI API에 반영한다.
이전 revision은 rollback API로 즉시 복구할 수 있다.

```bash
# 브라우저에서 관리자 화면 열기
open http://localhost:8080/admin/sdui

# 프로젝트 생성/수정
curl -u "$ADMIN_USER:$ADMIN_PASSWORD" -X PUT \
  -H 'Content-Type: application/json' \
  -d '{"catalogVersion":"seed-mobile-v1"}' \
  http://localhost:8080/admin/sdui/projects/demo
```

화면 revision API는 다음 순서로 사용한다.

```text
PUT  /admin/sdui/projects/:project/screens/:screen/draft
POST /admin/sdui/projects/:project/screens/:screen/validate
POST /admin/sdui/projects/:project/screens/:screen/publish
POST /admin/sdui/projects/:project/screens/:screen/rollback
```

CMS 데이터는 `sdui_projects`, `sdui_screen_revisions`, `sdui_theme_revisions` 테이블에 저장된다.

## 실행

```bash
# 로컬 Postgres 포함 전체 실행
docker compose up

# 또는 로컬 빌드로 실행 (Postgres는 docker compose up db)
make serve      # swift run server serve --port 8080
make swagger    # Swagger UI 열기
```

테스트:

```bash
swift test
```

## 환경변수

| 변수 | 설명 |
|---|---|
| `DATABASE_URL` | Postgres URL (없으면 localhost 기본값) |
| `JWT_SECRET` | 32바이트 이상, production 필수 |
| `ADMIN_USER` / `ADMIN_PASSWORD` | 어드민 Basic Auth, production 필수 |
