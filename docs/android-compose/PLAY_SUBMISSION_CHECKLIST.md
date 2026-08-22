# Compose Play 제출 직전 체크리스트

기준: 2026-08-17 KST. 이 문서는 Play Console에 AAB를 올리는 사람 작업을
남기지 않는다. 업로드·트랙 출시·프로덕션 게시는 별도 승인이다.

패키지 `com.solkim.baseball.android`, 상품명 **야구 못하면 또 환생함**,
가격 4,400원, 광고/IAP 없음, 오프라인, 한국어, 스마트폰 세로. 기존 Unity
등록정보·Data Safety·아이콘·피처 그래픽을 재사용한다. 첫 Compose 후보는
Play에 있는 Unity `versionCode` 5보다 높고, 로컬 Phase 10 리허설 36보다
높은 `1.0.0` / `37`이다.

## 이미 준비된 로컬 산출물

- 제품 앱 이름, adaptive/monochrome 런처 아이콘, 중간 밀도를 차단하지 않는 휴대폰 화면 지원 선언,
  `resizeableActivity=false`, 광고 ID/위치 권한 제거, Analytics 기본 수집 off
- 업로드 키·Firebase 설정·Amplitude 키를 저장소에 넣지 않는 RC 주입 경로
- `npm run check:android:compose:release` 소스 게이트
- `npm run build:android:compose:rc` 서명 AAB + cert pin + 매니페스트 경로
- 스토어 아이콘/피처 그래픽은
  `apps/android-unity/StoreAssets/` 해시 고정본을 그대로 쓴다
- 개인정보처리방침 `https://baseball-reincarnation.vercel.app/privacy`
- 고객지원 `https://baseball-reincarnation.vercel.app/support`

## 사람이 환경에 넣어야 하는 값

값은 이 문서에 적지 않는다. RC 스크립트는 아래가 있을 때만 production
distribution을 만든다.

```bash
export BASEBALL_VERSION_NAME=1.0.0
export BASEBALL_VERSION_CODE=37
export BASEBALL_UPLOAD_KEYSTORE_PATH
export BASEBALL_UPLOAD_KEYSTORE_PASSWORD
export BASEBALL_UPLOAD_KEY_ALIAS=baseball-upload
export BASEBALL_UPLOAD_KEY_PASSWORD
export BASEBALL_UPLOAD_CERT_SHA256=D0A8EC4FDCEC6F7F74BBEBCE747CB3D2FA308DB72CCA106D30AA2A782DAA445F
export BASEBALL_GOOGLE_SERVICES_PATH
export BASEBALL_AMPLITUDE_API_KEY
```

dirty worktree에서는 `BASEBALL_ALLOW_DIRTY_RC=1`로 로컬 후보만 만들 수
있다. 그 후보는 `local-dirty-candidate`이며 Play에 올리지 않는다.

## 출시 노트 초안 (internal/closed 업데이트)

> 같은 로컬 세이브를 유지한 채 화면을 더 안정적으로 플레이할 수 있습니다.
> 고교부터 가상 프로, 은퇴와 환생까지 이어지는 투수 커리어와 직접 타이밍을
> 맞추는 투구는 그대로입니다. 로그인·광고·인앱 구매 없이 오프라인으로
> 플레이합니다.

## Play Console에서 사람이 할 일

1. clean commit에서 `npm run build:android:compose:rc`로 서명 AAB를 만든다.
2. cert pin이 `D0A8EC4FDCEC6F7F74BBEBCE747CB3D2FA308DB72CCA106D30AA2A782DAA445F`
   인지 확인한다.
3. 같은 edit에 AAB와 native 심볼을 올리고 internal → closed만 갱신한다.
4. 가격 4,400원, 60분 체험, 대한민국, 기존 테스터 트랙을 유지한다.
5. Data Safety는 광고 ID 없음·대략적 위치(Analytics IP 파생) 공개를 다시 본다.
6. 기존 세로 스크린샷 6장을 재사용하되, Compose 셸이 보이는 새 캡처가 있으면
   서명 빌드·실기기에서만 교체한다.
7. 프로덕션 게시는 internal/closed 업데이트와 14일 기준을 통과한 뒤에만 한다.

## 2026-08-17 로컬 실행 결과

통과: `check:android:compose`, `check:android:compose:release`(소스만),
copy/IP, Korean-copy, dialogue, Unity assets 150, Unity static 447/447,
Android JVM 모듈 테스트 6개.

의도적 실패(우회하지 않음): `check:android:phase9`는 pitch Unity export 부재,
`gradlew test lint`의 `:app` 태스크는 같은 이유로 lockfile의
`games-frame-pacing` 미해석, instrumentation은 기기 없음, RC는 서명 환경
변수 없음.

## 이 작업에서 제출하지 않는 이유

- 워크트리가 dirty다. production RC는 clean commit만 허용한다.
- 이 머신에 Unity 6000.3.19f1이 없어 pitch export를 다시 만들 수 없다.
- 업로드 키 암호와 Amplitude 키가 프로세스 환경에 없다.
- API 29 / API 35 16KB / API 36 에뮬레이터와 실기기 Low/Mid/High가 없다.
- Firebase/Amplitude/Crashlytics 실수신과 Play pre-launch는 여기 없다.
- 한국 개발자 공개 전화 SMS와 통신판매업 신고는 유료 프로덕션 게시 전 과제로
  남아 있다.

이 목록을 우회하거나 임의 키로 서명한 AAB를 Play 후보로 바꾸지 않는다.
