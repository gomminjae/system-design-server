# system-design-server

모바일 시스템 디자인 공부용 백엔드 (Swift / Vapor 4).

모바일 앱을 클라이언트로 가정하고, 백엔드 시스템 디자인 주제를 하나씩 실제 코드로 구현해보는 실험장.

## 스택

- Swift 6 / Vapor 4 / Fluent (Postgres, 테스트는 인메모리 SQLite)
- JWT 인증 (Apple Sign In 검증 + 자체 토큰 발급)
- OpenAPI 자동 생성 (`/swagger`)

## 현재 구현된 것

| 영역 | 내용 |
|---|---|
| Auth | Apple Sign In → 자체 JWT 발급, `JWTAuthMiddleware` |
| App | 앱 버전 체크 API (`GET /app/version`) — 강제 업데이트 판단용 min/latest 버전, 인메모리 캐시 |
| Admin | Basic Auth로 보호되는 `/admin/*` (버전 정보 upsert) |
| Core | 표준 API 응답/에러 봉투, 에러 미들웨어, 타입 기반 캐시 키 헬퍼 |

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
