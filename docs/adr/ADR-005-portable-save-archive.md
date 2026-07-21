# ADR-005: Portable Save Archive와 백업 복구

- 상태: 승인
- 결정일: 2026-07-21

## 맥락

Windows와 후속 iOS 앱이 같은 커리어 저장을 읽어야 한다. 저장 중 강제 종료나 일부 파일 손상으로 최신 진행이 깨져도 이전 정상 revision을 잃지 않아야 하며, 개발 중에는 저장 내용을 사람이 직접 검사할 수 있어야 한다.

## 결정

- 저장 확장자는 `.dscareer`, 컨테이너는 표준 ZIP32를 사용한다.
- 초기 구현은 외부 런타임 의존성을 피하기 위해 압축하지 않은 ZIP entry를 직접 읽고 쓴다.
- `manifest.json`, 세 종류 snapshot, `rng.json`, `events.ndjson`, `content-lock.json`, `checksums.json`을 기본 항목으로 둔다.
- 각 payload entry는 `checksums.json`의 SHA-256으로 검증하고 ZIP 계층에서도 CRC32를 검증한다.
- 저장은 같은 폴더의 임시 파일에 완성하고 다시 읽어 검증한 뒤 현재 파일을 교체한다.
- 최근 정상 저장 세 개를 `.bak1`부터 `.bak3`까지 순환 보존한다.
- 최신 파일이 손상되면 이를 자동 덮어쓰지 않고 첫 번째 정상 백업을 로드한다.
- 손상 상태에서 새 저장을 만들 때 기존 손상본은 `.corrupt-<UUID>` 파일로 보존한다.
- ZIP entry 이름은 상대 안전 경로만 허용하며 ZIP64, 암호화, data descriptor, 다중 디스크는 P0에서 지원하지 않는다.

## 결과

- 저장 파일을 일반 ZIP 도구로 검사할 수 있고 플랫폼별 DB에 결합되지 않는다.
- 압축률은 낮지만 P0의 작은 JSON 저장에서는 단순성과 복구 가능성을 우선한다.
- 저장 크기가 실제 문제가 되면 동일 컨테이너 계약을 유지하며 deflate 지원 여부를 별도 ADR로 결정한다.

## 검증

- archive 쓰기·읽기 왕복
- SHA-256과 CRC32 표준 벡터
- payload 변조 및 경로 traversal 거부
- 백업 세 개 순환
- 최신 저장 truncation 뒤 백업 복구
- 교체 중 primary 누락과 임시 파일 잔존 뒤 복구
- 손상 원본과 기존 정상 백업 보존
