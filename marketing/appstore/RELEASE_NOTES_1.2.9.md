# 1.2.9 릴리스 노트

선수 만들기 제목이 화면 왼쪽과 머리 아래로 잘려 한글이 읽히지 않던 실사용 버그 수정. 1.2.8은 이미 판매 중이라 이 수정은 1.2.9로 제출한다. App Store `whatsNew`는 아래 ko/en/ja 본문만 올린다.

## whatsNew (ko)

선수 만들기에서 단계 제목이 화면 왼쪽과 머리글 아래로 잘려 글씨가 읽히지 않던 문제를 고쳤습니다. 이름을 정하고 다음으로 넘어갈 때도 제목 전체가 보입니다.

직접 투구의 기본 조작은 타이밍 슬라이더입니다.

## whatsNew (en)

Fixed a bug where setup-step titles were clipped under the header and off the left edge, so the letters could not be read. The full question stays on screen when you tap Next.

The default direct-pitch control remains the timing slider.

## whatsNew (ja)

選手作成の見出しが画面の左や上部の帯に切れ、文字が読めなくなっていた不具合を修正しました。「次へ」を押しても見出し全体が表示されます。

直接投球の基本操作はタイミングスライダーのままです。

## 로케일·금지어

영문 whatsNew는 `en-US`, `en-GB`, `en-AU`, `en-CA`에 동일하게 올린다. 일본어 문안은 실존 기구·구단·금지 표현을 쓰지 않는다.

## 내부 변경 요약

- 설정 단계 전환을 스크롤 영역 전체에만 걸고 그 영역을 잘라, 새 제목이 머리 밑·화면 왼쪽으로 밀려 나가지 않게 한다.
- 큰 한글 제목에 윗획·왼쪽 획 여백 계약을 둔다(`titleAscentClearance`, `titleLeadingClearance`).
- 유닛 렌더 검사와 시뮬레이터 UI 검사가 제목이 화면 안·머리 아래에 남는지 확인한다.
- 직접 투구 기본값은 수동 슬라이더. 자동 릴리스는 접근성 설정으로만 켠다.
