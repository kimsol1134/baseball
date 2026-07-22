# Steamworks 연결

이 디렉터리에는 App ID가 발급된 뒤 필요한 로컬 설정만 둔다. 실제 암호와 Steam Guard 코드는 저장소에 기록하지 않는다.

## App ID를 받은 뒤

1. `steamworks.example.json`을 `steamworks.local.json`으로 복사한다.
2. 정식판·데모 App ID와 운영체제별 Depot ID를 입력한다.
3. `npm run steam:config:full`과 `npm run steam:config:demo`를 실행한다.
4. 생성된 `artifacts/steamworks/<edition>/scripts/app_build.vdf`를 Steamworks SDK의 `steamcmd`에 전달한다.

생성기는 실제로 존재하고 체크섬 검사를 통과한 `artifacts/steam/<edition>/` 폴더만 데포 입력으로 사용한다. `SetLive`를 지정하지 않으므로 업로드 직후 공개 브랜치로 전환되지 않는다.

## Steam Auto-Cloud

게임은 같은 내용을 `steam-cloud-a.json`과 `steam-cloud-b.json` 두 파일에 번갈아 기록한다. 최신 파일이 손상되면 이전 파일을 자동 복구한다.

Steamworks Auto-Cloud에서 다음 경로를 연결한다.

| OS | Root | Subdirectory | Pattern |
|---|---|---|---|
| Windows | `WinAppDataRoaming` | `com.solkim.diamondsoul/steam-cloud` | `steam-cloud-*.json` |
| macOS | `MacAppSupport` | `com.solkim.diamondsoul/steam-cloud` | `steam-cloud-*.json` |

정식판과 데모는 같은 저장을 승계해야 하므로 Steamworks의 `Shared cloud APP ID`에 정식판 App ID를 사용한다. Windows Root에 macOS Root Override를 연결해 두 OS가 같은 파일을 동기화하도록 설정한다.

## Windows 선행 조건

첫 Steam 버전의 최소 사양은 Windows 11 x64다. WebView2 Evergreen Runtime은 Windows 11에 기본 포함되므로 데포에 고정 런타임을 중복 포함하지 않는다. 깨끗한 Windows 11 VM에서 누락 사례가 확인되면 공개 전에 Steam 설치 스크립트로 Evergreen bootstrapper를 추가한다.

## macOS

Steam에 올리는 파일은 DMG가 아니라 `.app`이다. 공개 데포는 Developer ID 서명과 Apple 공증을 통과해야 한다. 현재 CI의 ad-hoc 서명 산출물은 내부 QA용이다.
