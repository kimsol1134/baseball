import Foundation

// 이 주석의 "설명을 진행할 수 있습니다"는 화면 문구가 아니므로 검사하지 않는다.
let scene = Scene(
    quote: "\u{201C}{player}, 오늘 공은 끝이 좋다. 높은 쪽으로 한 번 붙어 보자.\u{201D}",
    choices: [
        listen("포수가 본 타이밍을 묻는다", "타자가 늦었던 공부터 함께 짚는다"),
        explain("손끝 감각을 말한다", "오늘 유난히 잘 걸린 공을 알려 준다"),
        challenge("같은 높이로 다시 붙는다", "고개를 끄덕이고 승부를 받아들인다"),
    ]
)

let intentionalQuote = "기자가 ‘결과로 답하겠다는 말인가요?’라고 되물었다. 나는 웃으며 공을 집었다."
let variable = "\(pitcher.name), \(report.strikeouts)탈삼진으로 마지막 이닝을 닫았다."
