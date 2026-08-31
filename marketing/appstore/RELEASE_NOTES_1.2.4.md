# App Store 1.2.4 업데이트 문안

이 문서는 1.2.4의 사용자 노출용 `What's New` 원문이다. App Store Connect의 기존 1.2.4
버전에서 설명(`description`)과 새로운 기능(`whatsNew`)만 갱신하며, 빌드 연결·미디어·심사
제출은 별도 절차로 진행한다. 재현 가능한 metadata-only 명령은
`node tools/asc-metadata-1-2-4.mjs`를 사용한다.

## ko

이번 업데이트에서는 플레이 중 막히는 순간을 더 쉽게 읽을 수 있게 다듬었습니다.

· 부상이 생기면 원인·회복 기간·다음 행동을 결과 화면에서 바로 확인할 수 있습니다.
· 한 번 본 스토리와 설명은 반복해서 볼 때 간결한 요약으로 접어 두고, 필요할 때 다시 펼칠 수 있습니다.
· 능력 수치를 익숙한 1–100으로 표시합니다. 100 이후에는 능력치 숫자가 끝없이 커지는 대신 별도의 숙련 레벨과 효과로 성장을 이어 갑니다.

한 구씩 직접 던지는 손맛과, 다음 커리어를 만들어 가는 선택은 그대로입니다.

## ja

今回のアップデートでは、プレイ中の判断をもっと読みやすくしました。

・負傷の原因・回復期間・次に取る行動を、結果画面ですぐ確認できます。
・一度読んだストーリーと説明は、次からコンパクトな要約に折りたためます。必要ならいつでも詳しく開けます。
・能力値をなじみのある1〜100で表示。100の基本上限の後は、数値が無限に増えるのではなく、別枠の熟練レベルと効果で成長を続けます。

一球ずつ自分で投げる手触りと、次のキャリアを選ぶ面白さはそのままです。

## en-US · en-GB · en-CA · en-AU

This update makes every decision easier to read.

• See an injury’s cause, recovery time, and next step right away.
• Repeated story moments and explanations collapse into a compact summary after the first read, and can be expanded whenever you want the detail.
• Ability ratings now use a familiar 1–100 scale. After the base cap, separate mastery levels and effects keep development moving without turning ratings into endless numbers.

Your next pitch—and your next career—are easier to follow.

The same English copy is applied to `en-US`, `en-GB`, `en-AU`, and `en-CA`.

## Description source

The full player-facing descriptions for all six existing locales are kept in the metadata-only
tool so the exact ASC payload can be checked before and after the update. The descriptions call
out the same three 1.2.4 improvements: injury cause/recovery/next-step guidance, compact repeated
story explanations, and a readable 1–100 rating scale with separate mastery beyond the base cap.
They explicitly avoid claiming that ability numbers grow forever.
