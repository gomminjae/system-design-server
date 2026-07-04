# cosmi-server

코스미(Cosmi) 백엔드 API — 큐레이션형 웹 미니앱(통) 플랫폼의 서버.
유저가 통을 제출하면 심사 후 공개하고, 호스트 앱(RN)이 카탈로그를 소비한다.

> 폴리레포: 호스트 앱·어드민 웹 등은 별도 레포(`cosmi-mobile` 등).

## 스택
- **Vapor 4** (Swift 6) + **Fluent** ORM
- DB: **SQLite**(로컬) → Postgres(운영 예정)
- 어드민: **Leaf** SSR + Basic Auth
- 번들 스토리지(예정): 로컬 디스크 → Cloudflare R2

## 폴더링 (기능별)
```
Sources/server/
├── Features/
│   ├── Tong/      # 모델·DTO·마이그레이션·공개 API(Catalog/Submission)
│   └── Admin/     # 심사 백오피스(Leaf) + Basic Auth
├── Core/          # 공통 인프라: APIResponse / APIError 봉투·미들웨어
├── configure.swift · routes.swift · entrypoint.swift
Resources/Views/   # Leaf 템플릿
```

## API
**공개 (JSON, 응답 봉투 `{data}` / `{error}`)**
- `GET  /catalog` — 승인된 통 목록
- `POST /submissions` — 통 제출 (status=submitted)

**어드민 (Leaf, Basic Auth)**
- `GET  /admin` — 심사 대시보드
- `POST /admin/tongs/:id/approve|reject|disable`

## 실행
```bash
swift run                 # localhost:8080
curl localhost:8080/health
```
어드민 자격증명은 환경변수로: `ADMIN_USER` / `ADMIN_PASSWORD` (미설정 시 개발 기본값).

## 상태
초기 골격(Tong 도메인 + 어드민 + 응답 봉투). 어드민 대시보드(index)·파일 업로드·테스트 정리 진행 중.
