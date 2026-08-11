# Unity 6000.3 참조 컴파일 게이트

```bash
bash tools/unity-reference-compile.sh
```

Unity Editor를 실행하지 않고 설치된 6000.3.19f1 참조 DLL로 경고를 오류로 취급해 다음 gate를 컴파일합니다.

1. production player closure: 내부 QA 전처리 코드는 제외
2. internal-QA Android player closure: `DEVELOPMENT_BUILD`, `BASEBALL_INTERNAL_QA`로 개발 전용
   Android intent/crash 코드와 테스트까지 포함 (`UNITY_EDITOR`는 넣지 않아 player 분기를 실제대로 검사)
3. Core, Platform, Platform tests: 별도 assembly로 컴파일해 friend/internal과 asmdef 의존 경계 확인
4. Presentation EditMode test closure: 실제 Unity Editor/NUnit/Input System/URP 참조로 전체
   `Assets/Tests/EditMode/Presentation/**/*.cs` 소스를 경고 0 계약으로 컴파일
5. Android Editor closure: `Assets/Game/Editor/**/*.cs` 전체와 Android Editor/URP 참조 포함

이 gate는 서로 다른 asmdef를 한 csproj로 합쳐 경계를 숨기지 않습니다. 빠른 C# API·문법과
Core/Platform/test friend assembly 경계를 함께 검사하는 회귀 gate이며, Unity batch compile과
EditMode/PlayMode 결과를 대체하지 않습니다. 특히 라이선스 없이
프로젝트를 열 수 없는 환경에서는 UPM Addressables assembly가 생성되지 않으므로 Editor closure는
Addressables에 한해 최소 compile-only shape를 사용합니다. 실제 패키지 API와 asmdef/import 상태는
라이선스가 있는 Unity 실행에서 다시 검증해야 합니다.

모든 `obj`/`bin` 출력은 `mktemp`로 만든 저장소 밖 경로에 쓰고 종료 시 제거합니다.
