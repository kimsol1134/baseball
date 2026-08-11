# Android Unity 패리티 예외

사전 승인된 플랫폼 차이만 기록한다.

| ID | iOS | Android v1 | 이유 |
|---|---|---|---|
| EX-001 | Game Center | 로컬 업적만 | 로그인 없는 오프라인 v1 범위 |
| EX-002 | iCloud KVS | 로컬 원자 저장 | 계정/클라우드 비범위 |
| EX-003 | iOS Share Sheet | Android Sharesheet | 플랫폼 대응 |
| EX-004 | StoreKit Review | Google Play In-App Review | 플랫폼 대응 |
| EX-005 | Apple notification API | Android 알림 채널/POST_NOTIFICATIONS | 플랫폼 대응 |
| EX-006 | Swift RNG 개별 결과 | C# 내부 결정론 결과 | 결과 미세 차이 허용, 분포 게이트 필수 |
| EX-007 | 31-sample 타구 비행 배열 | 거리·체공·정점 기반 Unity frame 보간 | 경기 결과와 무관한 시각 경로 미세 차이; 128 exact/10,000 분포 게이트 통과 필수 |
| EX-008 | 병살 pivot 야수 이름 선택 | 병살 성공·아웃만 확정, pivot 이름 미노출 | Android v1 UI/분석에 pivot 이름이 없고 경기 결과는 동일 |
| EX-009 | iOS 공유 completion callback에서 `life_card_shared`/`life_card_share_completed` 계측 | Android Sharesheet chooser를 연 직후 `life_card_share_tapped`만 계측 | Android `ACTION_SEND` chooser는 사용자가 실제 대상 앱에서 공유를 완료했는지 신뢰할 수 있는 결과를 제공하지 않음 |

EX-006은 코어 pitch kernel 불일치를 허용하는 면책이 아니다. 현재 동일 입력 seed 1...128의
outcome/location/velocity/event hash와 seed 1...10,000 outcome 집계는 Swift와 exact로 고정한다.
EX-007/008의 사용자 영향은 각각 타구 카메라 보간의 미세한 경로 차이와 사용자에게 보이지
않는 병살 중계 주체 생략뿐이며, 점수·주자·아웃·성장·저장 결과 차이는 허용하지 않는다.
EX-009는 공유 기능 자체를 줄이지 않는다. PNG와 한국어 텍스트는 동일하게 Sharesheet로 보내되,
완료를 추측해 성공 지표를 부풀리지 않는다. Android Presentation에서 `LifeCardShared`와
`LifeCardShareCompleted` 호출이 0인지 정적 계약으로 고정한다.

새 예외 형식:

```text
ID:
iOS 동작:
Android 동작:
이유:
사용자 영향:
테스트/수치:
승인:
```
