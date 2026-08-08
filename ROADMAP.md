# System Design Server 학습 로드맵

모바일 앱 개발자가 자주 마주치는 백엔드 문제를 작은 기능 단위로 직접 구현하고,
데이터 정합성·장애 처리·확장 방식까지 학습하기 위한 로드맵이다.

이 저장소의 목표는 거대한 서비스를 완성하는 것이 아니다. 각 주제를 하나의 작은 vertical slice로
구현하고, 단일 서버에서 충분히 이해한 뒤 필요할 때만 분산 구조로 확장한다.

## 학습 원칙

각 주제는 다음 순서로 진행한다.

1. 가장 단순하게 동작하는 API를 만든다.
2. 모바일 클라이언트 관점의 실패 상황을 정의한다.
3. 데이터 정합성과 중복 요청을 처리한다.
4. 테스트와 관측 지표를 추가한다.
5. 트래픽이 증가했을 때의 다음 구조를 문서화한다.

새로운 기술을 사용하는 것보다 "왜 필요한지" 설명할 수 있는 상태를 완료 기준으로 삼는다.

## 현재 상태

- ✅ JWT 기반 인증 골격
- ✅ 앱 최소·최신 버전 조회
- ✅ 검색 자동완성과 검색 로그
- ✅ 공통 API 응답·에러 형식
- 🚧 범용 SDUI 계약, 프로젝트별 Theme, Screen API

인증은 학습용 골격이다. 외부 IdP의 issuer, audience, JWKS를 검증하는 운영 수준의 인증 강화가
별도 작업으로 남아 있다.

## 추천 진행 순서

### 1. 범용 SDUI

현재 진행 중인 첫 번째 큰 주제다.

만들 것:

- 프로젝트별 화면과 Light/Dark 브랜드 Theme
- 컴포넌트 카탈로그 버전
- 화면·테마 revision
- validate → publish → rollback
- ETag와 클라이언트 fallback
- 제한된 데이터 바인딩, 조건, 반복
- 등록된 action만 호출하는 Action Gateway

학습 포인트:

- 서버와 클라이언트의 버전 호환성
- 재귀적인 UI 문서 모델링
- 디자인 토큰과 Theme 상속
- 잘못된 설정을 운영에 배포하지 않는 방법
- 캐시 가능한 화면과 개인화 화면의 차이

완료 기준:

- 쇼핑 상품 목록과 커뮤니티 게시글 목록을 같은 SDUI 코어로 표현한다.
- 브랜드 색상과 화면 구성을 앱 배포 없이 변경한다.
- 지원하지 않는 카탈로그에서는 네이티브 화면으로 fallback한다.
- 이전 화면 revision으로 즉시 rollback할 수 있다.

### 2. Feature Flag와 점진적 배포

SDUI 화면이나 새로운 기능을 일부 사용자에게만 노출한다.

만들 것:

- boolean, string, number 타입 flag
- 플랫폼·앱 build·market 기반 조건
- 사용자 ID 기반의 안정적인 percentage rollout
- kill switch
- flag revision과 변경 이력

학습 포인트:

- 동일 사용자가 항상 같은 실험군에 들어가게 하는 해싱
- 설정 캐시와 즉시 무효화의 trade-off
- 익명 사용자와 로그인 사용자의 식별
- 운영 사고 시 빠르게 기능을 끄는 방법

완료 기준:

- 특정 SDUI 화면을 사용자 10%에게 안정적으로 노출한다.
- 앱 재실행 후에도 같은 사용자가 같은 그룹에 배정된다.
- flag 변경과 rollback 기록이 남는다.

### 3. Cursor Pagination과 무한 스크롤

모바일 피드와 목록 API의 기본기를 학습한다.

만들 것:

- 게시글 또는 상품 목록
- `(createdAt, id)` 기반 keyset pagination
- 불투명한 cursor
- pull-to-refresh와 다음 페이지 조회
- 삭제·추가가 발생하는 동안의 중복 제거

학습 포인트:

- offset pagination이 큰 데이터에서 느려지는 이유
- 정렬이 같은 레코드를 안정적으로 조회하는 방법
- 새 데이터가 추가될 때 페이지가 밀리는 문제
- 클라이언트의 중복 ID 병합

완료 기준:

- 페이지 사이에 중복이나 누락이 없는 테스트가 있다.
- 잘못되거나 만료된 cursor를 안전하게 거절한다.
- 필요한 복합 인덱스와 쿼리 실행 계획을 설명할 수 있다.

### 4. 캐시와 조건부 요청

자주 읽고 드물게 바뀌는 데이터를 효율적으로 제공한다.

만들 것:

- cache-aside 패턴
- TTL과 revision 기반 무효화
- `ETag`와 `If-None-Match`
- cache hit/miss 로그
- 동시에 캐시가 만료되는 상황의 보호

학습 포인트:

- 캐시 데이터가 오래된 상태로 남는 이유
- TTL, 명시적 삭제, immutable key의 차이
- cache stampede
- 사용자별 데이터의 shared cache 위험

완료 기준:

- 변경되지 않은 응답은 `304 Not Modified`를 반환한다.
- 여러 서버 인스턴스에서도 같은 캐시 정책을 사용할 수 있다.
- 캐시 장애가 원본 API 전체 장애로 이어지지 않는다.

### 5. 좋아요·북마크와 멱등성

모바일 네트워크 재시도로 발생하는 중복 요청을 다룬다.

만들 것:

- 좋아요와 북마크 API
- database unique constraint
- `Idempotency-Key`
- optimistic UI와 실패 시 rollback
- 중복 요청 결과 재사용

학습 포인트:

- at-least-once 요청 환경
- 애플리케이션 검증과 DB 제약조건의 차이
- 멱등한 PUT/DELETE와 비멱등 POST
- 동시에 같은 버튼을 누르는 race condition

완료 기준:

- 같은 요청을 여러 번 보내도 데이터가 한 번만 변경된다.
- 동시에 들어온 요청에서도 카운트가 틀어지지 않는다.
- 모바일 timeout 후 재시도 시 이전 결과를 받을 수 있다.

### 6. 이미지 업로드 파이프라인

프로필·게시글 이미지 업로드를 서버 메모리에 올리지 않고 처리한다.

만들 것:

- presigned upload URL 발급
- 업로드 완료 확인
- 이미지 metadata 저장
- thumbnail 생성 작업
- 파일 크기·MIME type·확장자 검증
- 사용되지 않는 파일 정리

학습 포인트:

- API 서버를 거치지 않는 object storage 업로드
- 악성 파일과 큰 파일 제한
- 원본과 파생 이미지의 생명주기
- 업로드는 성공했지만 DB 저장은 실패하는 문제

완료 기준:

- 큰 이미지가 API 서버 메모리를 사용하지 않고 업로드된다.
- thumbnail 실패를 재시도할 수 있다.
- 고아 파일을 찾아 정리할 수 있다.

### 7. Background Job, Retry와 Outbox

느리거나 실패할 수 있는 작업을 API 요청에서 분리한다.

만들 것:

- DB 기반 job queue
- exponential backoff와 최대 재시도 횟수
- dead-letter 상태
- idempotent worker
- transactional outbox

학습 포인트:

- API 응답 안에서 모든 일을 처리하면 안 되는 이유
- DB 저장과 이벤트 발행 사이의 dual-write 문제
- worker가 작업 중 종료됐을 때의 복구
- poison message와 무한 재시도

완료 기준:

- 프로세스가 중간에 종료돼도 작업을 잃지 않는다.
- 같은 job이 두 번 실행돼도 결과가 중복되지 않는다.
- 실패 원인과 재시도 횟수를 조회할 수 있다.

### 8. Push Notification

모바일 특유의 device token 생명주기와 알림 발송을 다룬다.

만들 것:

- 사용자별 여러 device token 등록
- 알림 발송 job
- 알림함과 읽음 상태
- 만료된 token 제거
- 알림 설정과 quiet hours

학습 포인트:

- APNs/FCM 요청 실패와 재시도
- 한 사용자가 여러 기기를 쓰는 경우
- 알림 전송 성공과 사용자 수신의 차이
- 대량 fan-out

완료 기준:

- 로그아웃한 기기로 알림이 발송되지 않는다.
- provider가 거절한 token을 비활성화한다.
- 같은 이벤트가 중복 알림으로 이어지지 않는다.

### 9. 실시간 채팅

HTTP 요청·응답을 넘어 연결 상태와 메시지 순서를 학습한다.

만들 것:

- WebSocket 연결과 인증
- 채팅방과 메시지 저장
- client message ID 기반 중복 제거
- 재연결 후 누락 메시지 조회
- 읽음 cursor
- 온라인 상태는 best-effort로 처리

학습 포인트:

- 연결 서버와 메시지 저장소의 역할 분리
- 메시지 순서와 전역 시간의 한계
- reconnect, heartbeat, backpressure
- 여러 서버 인스턴스 사이의 메시지 전달

완료 기준:

- 연결이 끊겼다가 복구돼도 메시지를 잃지 않는다.
- 같은 메시지 재전송이 중복 저장되지 않는다.
- 한 사용자의 여러 기기에서 읽음 상태가 수렴한다.

### 10. 예약·재고와 동시성 제어

남은 수량이 하나일 때 여러 사용자가 동시에 요청하는 상황을 다룬다.

만들 것:

- 상품 재고 또는 좌석 예약
- 임시 선점과 만료
- optimistic locking 또는 row lock
- 결제 성공·실패에 따른 확정과 해제
- 중복 결제 callback 처리

학습 포인트:

- race condition과 lost update
- transaction isolation
- lock contention
- 외부 결제 시스템과의 saga/보상 처리

완료 기준:

- 동시 요청에서도 재고가 음수가 되지 않는다.
- 만료된 예약은 자동으로 반환된다.
- 같은 결제 callback을 여러 번 받아도 한 번만 확정된다.

### 11. Offline Sync와 충돌 해결

네트워크가 불안정한 모바일 앱에서 로컬 변경을 서버와 동기화한다.

만들 것:

- 변경 version과 `updatedAt`
- delta sync cursor
- 클라이언트 operation ID
- 삭제 tombstone
- 충돌 정책

학습 포인트:

- last-write-wins의 장단점
- 서버 authoritative 데이터와 로컬 optimistic 데이터
- 삭제 데이터가 다시 살아나는 문제
- 오랜 시간 오프라인이었던 클라이언트 처리

완료 기준:

- 오프라인에서 만든 변경이 재연결 후 중복 없이 반영된다.
- 삭제·수정 충돌 정책이 테스트로 명시돼 있다.
- 전체 데이터를 다시 받지 않고 변경분만 동기화한다.

### 12. 이벤트 수집과 분석 파이프라인

클라이언트 이벤트를 안정적으로 수집하고 집계한다.

만들 것:

- 이벤트 batch 수집 API
- event ID 기반 중복 제거
- 이벤트 schema version
- 비동기 저장과 일별 집계
- 보관 기간과 개인정보 제거

학습 포인트:

- 모바일 batch와 압축
- 이벤트 순서가 뒤바뀌는 상황
- schema evolution
- 운영 로그와 분석 이벤트의 차이

완료 기준:

- 같은 batch를 재전송해도 중복 집계되지 않는다.
- 구버전 앱의 이벤트도 해석할 수 있다.
- 사용자별 원본 데이터를 삭제할 수 있다.

## 추가 주제 후보

핵심 로드맵 이후 관심사에 따라 선택한다.

- 위치 기반 주변 장소 검색과 geohash
- 검색 오타 교정, 인기 검색어와 ranking
- 홈 피드 fan-out-on-read와 fan-out-on-write 비교
- 댓글 대댓글과 materialized path
- 신고·차단과 콘텐츠 moderation queue
- 링크 미리보기 crawler와 SSRF 방어
- 결제 ledger와 환불 상태 머신
- API rate limiting과 abuse prevention
- 감사 로그와 관리자 권한
- 개인정보 익명화·삭제 workflow
- 여러 지역에 걸친 읽기 replica와 장애 전환
- API Gateway와 BFF

## 모든 주제의 공통 완료 체크리스트

- [ ] 사용자 시나리오와 범위를 README에 설명했다.
- [ ] API request/response와 오류 코드를 정의했다.
- [ ] 데이터 모델과 필요한 인덱스를 설명했다.
- [ ] 중복 요청과 동시 요청의 결과를 정의했다.
- [ ] timeout, 재시도, 부분 실패를 다뤘다.
- [ ] 정상·오류·경계 조건 테스트가 있다.
- [ ] 요청 ID를 포함한 구조화 로그가 있다.
- [ ] 최소한의 성능 측정 결과가 있다.
- [ ] 트래픽이 10배가 될 때의 병목을 적었다.
- [ ] 현재 구현의 한계와 다음 구조를 적었다.

## 주제별 문서 템플릿

각 기능에는 다음 형식의 짧은 설계 문서를 남긴다.

```markdown
# 주제 이름

## 문제
어떤 모바일 사용자 문제를 해결하는가?

## 요구사항
- 기능 요구사항
- 비기능 요구사항

## API
주요 endpoint와 request/response

## 데이터 모델
테이블, 관계, 인덱스

## 핵심 흐름
정상 흐름과 상태 변화

## 실패 시나리오
중복 요청, timeout, 부분 실패, 서버 재시작

## 테스트와 관측성
검증할 테스트, 로그, metric

## 확장 방향
현재 한계와 트래픽 증가 시 다음 선택
```

## 당장 진행할 순서

1. SDUI 화면·테마 revision을 DB에 저장한다.
2. SDUI validate, publish, rollback API를 만든다.
3. `ETag`와 카탈로그 fallback을 완성한다.
4. 서로 다른 도메인의 예제 화면 두 개로 범용성을 검증한다.
5. 다음 학습 주제로 Feature Flag를 SDUI 배포에 연결한다.

처음부터 Kafka, Kubernetes, 마이크로서비스를 도입하지 않는다. 단일 Vapor 서버와 Postgres로
문제를 재현하고 측정한 뒤, 실제 병목이나 일관성 요구가 생겼을 때 구성요소를 분리한다.
