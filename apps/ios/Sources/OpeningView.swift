import SwiftUI

/// 게임이 시작됐다는 것을 알리는 첫 화면.
///
/// 실기기에서 처음 켠 사람이 **"게임을 시작했는지 잘 모르겠다"**고 했다. 앱을 열면 곧바로
/// 이름 입력·투수 유형·난이도·핸디캡이 늘어선 폼이 나왔기 때문이다. 그건 게임이 아니라
/// 앱 설정처럼 읽힌다.
///
/// 여기서 하는 일은 셋뿐이다 — 무슨 게임인지, 목표가 뭔지, 다음에 뭘 눌러야 하는지.
/// 조작 설명은 하지 않는다. 던지는 법은 던지는 자리에서 알려 주는 편이 언제나 낫다.
///
/// **첫 회차에만 나온다.** 별도 플래그를 저장하지 않고 `needsSetup && 1회차` 조건에서
/// 파생시킨다. 그래서 커리어를 지우면(`deleteCareer`) 다시 나오고, 다음 회차로 넘어갈 때는
/// (`beginNextLife`, 계승분이 남아 있다) 나오지 않는다. 상태가 곧 조건이라 어긋날 자리가 없다.
struct OpeningView: View {
    let onStart: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                BaseballTheme.canvas.ignoresSafeArea()

                // 그림이 화면의 절반을 차지한다. `KeyArtHeader`의 190pt는 목록 안에 얹는
                // 머리글용이라, 첫 화면에 그대로 쓰면 위쪽만 그림이고 가운데가 텅 빈다.
                Image(KeyArt.careerIntro.rawValue)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: proxy.size.width, height: proxy.size.height * 0.62)
                    .clipped()
                    .overlay {
                        LinearGradient(
                            colors: [
                                BaseballTheme.canvas.opacity(0.05),
                                BaseballTheme.canvas.opacity(0.55),
                                BaseballTheme.canvas,
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                    .ignoresSafeArea(edges: .top)

                VStack(alignment: .leading, spacing: 16) {
                Text("고교 3년, 한 번의 드래프트").eyebrowStyle(BaseballTheme.action)

                Text("야구 못하면 또 환생함")
                    .font(BaseballType.display)
                    .foregroundStyle(BaseballTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("당신은 고교 투수입니다.\n3년 안에 프로 지명을 받아야 합니다.")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(BaseballTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("모든 경기를 던지지 않습니다. 결과를 바꿀 수 있는 순간에만 마운드에 오릅니다.")
                    .font(.subheadline)
                    .foregroundStyle(BaseballTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                PrimaryPill(title: "시작하기", identifier: "hs.opening.start", action: onStart)
            }
                .padding(BaseballMetrics.gutter)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(BaseballTheme.canvas)
        .accessibilityElement(children: .contain)
    }
}
