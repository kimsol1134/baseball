import SwiftUI
import UIKit

/// 홈플레이트 위의 두 사람 — 타자와 포수.
///
/// **왜 따로 떼어 냈는가.** 예전에는 `PitchDramaView` 안에서 타원 하나와 2차 베지에 한 줄로
/// 타자를 그렸다. 그 결과는 사람이 아니라 물음표 모양의 덩어리였고, 그 옆의 포수는 그냥
/// 납작한 타원이었다 — 화면의 다른 모든 것(궤적·존·타구 낙하)이 정확한 데이터인데 유일하게
/// 사람만 대충 그려져 있으니, 장면 전체가 미완성으로 읽혔다.
///
/// 여기서는 사람을 **부위별로** 조립한다. 머리·헬멧 귀덮개·어깨·몸통·앞뒤 다리·양팔·배트가
/// 각각 자기 도형을 갖고, 전부 하나의 단위 상자(0~1) 안에서 정의된다. 상자를 원하는 크기로
/// 변환하기만 하면 어느 화면 크기에서도 비율이 같다.
///
/// **이미지 에셋이 있으면 그쪽이 이긴다.** `Assets.xcassets`에 `BatterStance`/`CatcherStance`가
/// 들어오면 자동으로 그 그림을 쓰고, 없으면 아래 벡터로 떨어진다. 아트가 준비되는 시점과
/// 코드가 준비되는 시점을 분리하기 위한 문이다 — 에셋을 넣는 것만으로 교체가 끝난다.
enum PlateFigures {
    static let batterAssetName = "BatterStance"
    static let catcherAssetName = "CatcherStance"

    /// 에셋이 번들에 있는가. 매 프레임 `UIImage(named:)`를 부르면 캐시가 있어도 낭비라 한 번만 본다.
    static let hasBatterAsset: Bool = UIImage(named: batterAssetName) != nil
    static let hasCatcherAsset: Bool = UIImage(named: catcherAssetName) != nil

    /// 단위 상자 안의 타자. 우타자가 화면 왼쪽에 서서 배트를 오른쪽 위로 들고 있는 모습.
    ///
    /// 좌표계는 (0,0)이 왼쪽 위, (1,1)이 오른쪽 아래다. 가로는 배트 끝까지 포함한 폭이고,
    /// 세로는 헬멧 꼭대기부터 앞발 바닥까지다.
    static func batterPath() -> Path {
        var path = Path()

        // 헬멧 — 머리 원에 챙과 귀덮개를 붙여야 "야구 타자"로 읽힌다. 맨머리 원은 아무나다.
        path.addEllipse(in: CGRect(x: 0.300, y: 0.010, width: 0.150, height: 0.150))
        // 귀덮개(카메라 쪽 뺨을 덮는다)
        path.addEllipse(in: CGRect(x: 0.283, y: 0.070, width: 0.085, height: 0.095))
        // 챙 — 투수 쪽(오른쪽)으로 짧게.
        var brim = Path()
        brim.move(to: CGPoint(x: 0.420, y: 0.062))
        brim.addLine(to: CGPoint(x: 0.520, y: 0.076))
        brim.addLine(to: CGPoint(x: 0.518, y: 0.100))
        brim.addLine(to: CGPoint(x: 0.420, y: 0.096))
        brim.closeSubpath()
        path.addPath(brim)

        // 몸통 — 어깨에서 허리까지 좁아지는 사다리꼴. 뒤에서 본 타자는 어깨가 가장 넓다.
        var torso = Path()
        torso.move(to: CGPoint(x: 0.238, y: 0.205))   // 뒤쪽 어깨
        torso.addQuadCurve(to: CGPoint(x: 0.262, y: 0.430),
                           control: CGPoint(x: 0.222, y: 0.330))   // 등 라인
        torso.addLine(to: CGPoint(x: 0.300, y: 0.545))             // 허리 뒤
        torso.addLine(to: CGPoint(x: 0.452, y: 0.545))             // 허리 앞
        torso.addQuadCurve(to: CGPoint(x: 0.470, y: 0.205),
                           control: CGPoint(x: 0.505, y: 0.360))   // 가슴·옆구리
        torso.closeSubpath()
        path.addPath(torso)

        // 뒷다리 — 체중이 실린 쪽. 무릎이 안으로 접히고 발이 뒤에 남는다.
        var backLeg = Path()
        backLeg.move(to: CGPoint(x: 0.300, y: 0.520))
        backLeg.addQuadCurve(to: CGPoint(x: 0.196, y: 0.760),
                             control: CGPoint(x: 0.214, y: 0.640))
        backLeg.addLine(to: CGPoint(x: 0.128, y: 0.960))
        backLeg.addLine(to: CGPoint(x: 0.222, y: 0.978))
        backLeg.addLine(to: CGPoint(x: 0.282, y: 0.782))
        backLeg.addQuadCurve(to: CGPoint(x: 0.386, y: 0.545),
                             control: CGPoint(x: 0.330, y: 0.660))
        backLeg.closeSubpath()
        path.addPath(backLeg)

        // 앞다리 — 투수 쪽으로 벌려 딛는다. 넓은 스탠스가 타격 자세의 핵심 신호다.
        var frontLeg = Path()
        frontLeg.move(to: CGPoint(x: 0.386, y: 0.530))
        frontLeg.addQuadCurve(to: CGPoint(x: 0.520, y: 0.780),
                              control: CGPoint(x: 0.492, y: 0.640))
        frontLeg.addLine(to: CGPoint(x: 0.560, y: 0.962))
        frontLeg.addLine(to: CGPoint(x: 0.462, y: 0.980))
        frontLeg.addLine(to: CGPoint(x: 0.416, y: 0.790))
        frontLeg.addQuadCurve(to: CGPoint(x: 0.300, y: 0.545),
                              control: CGPoint(x: 0.330, y: 0.660))
        frontLeg.closeSubpath()
        path.addPath(frontLeg)

        // 발 — 짧은 가로 덩어리 둘. 없으면 다리가 허공에서 끝난다.
        path.addRoundedRect(in: CGRect(x: 0.098, y: 0.948, width: 0.150, height: 0.042),
                            cornerSize: CGSize(width: 0.018, height: 0.018))
        path.addRoundedRect(in: CGRect(x: 0.450, y: 0.950, width: 0.150, height: 0.042),
                            cornerSize: CGSize(width: 0.018, height: 0.018))

        // 양팔 — 손이 뒤쪽 어깨 위에서 만난다. 팔꿈치가 들려 있어야 "노리고 있다"로 보인다.
        var arms = Path()
        arms.move(to: CGPoint(x: 0.250, y: 0.215))
        arms.addQuadCurve(to: CGPoint(x: 0.330, y: 0.118),
                          control: CGPoint(x: 0.246, y: 0.150))   // 뒤팔 위쪽
        arms.addLine(to: CGPoint(x: 0.500, y: 0.150))              // 손 쪽으로
        arms.addLine(to: CGPoint(x: 0.494, y: 0.216))
        arms.addLine(to: CGPoint(x: 0.352, y: 0.196))
        arms.addQuadCurve(to: CGPoint(x: 0.318, y: 0.262),
                          control: CGPoint(x: 0.318, y: 0.214))
        arms.closeSubpath()
        path.addPath(arms)
        // 손(글러브 없는 쪽) — 배트를 쥔 덩어리.
        path.addEllipse(in: CGRect(x: 0.474, y: 0.140, width: 0.070, height: 0.080))

        // 배트 — 손잡이가 가늘고 배럴이 굵다. 굵기가 일정하면 막대기가 된다.
        var bat = Path()
        bat.move(to: CGPoint(x: 0.500, y: 0.196))
        bat.addLine(to: CGPoint(x: 0.518, y: 0.150))
        bat.addLine(to: CGPoint(x: 0.940, y: 0.020))
        bat.addLine(to: CGPoint(x: 0.980, y: 0.062))
        bat.addLine(to: CGPoint(x: 0.548, y: 0.216))
        bat.closeSubpath()
        path.addPath(bat)
        // 손잡이 끝의 노브.
        path.addEllipse(in: CGRect(x: 0.478, y: 0.186, width: 0.056, height: 0.050))

        return path
    }

    /// 단위 상자 안의 포수. 존 아래에 등을 보이고 앉아 있다.
    ///
    /// 미트는 그리지 않는다 — 실제 미트 위치는 `PitchDramaView`가 코어의 판정 좌표에
    /// 맞춰 따로 그리며, 여기 또 하나를 그리면 화면에 미트가 두 개가 된다.
    static func catcherPath() -> Path {
        var path = Path()
        // 마스크를 쓴 뒤통수.
        path.addEllipse(in: CGRect(x: 0.395, y: 0.020, width: 0.210, height: 0.215))
        // 어깨에서 엉덩이까지 — 앉은 자세라 등이 둥글게 말린다.
        var back = Path()
        back.move(to: CGPoint(x: 0.300, y: 0.330))
        back.addQuadCurve(to: CGPoint(x: 0.500, y: 0.205),
                          control: CGPoint(x: 0.352, y: 0.228))
        back.addQuadCurve(to: CGPoint(x: 0.700, y: 0.330),
                          control: CGPoint(x: 0.648, y: 0.228))
        back.addQuadCurve(to: CGPoint(x: 0.760, y: 0.720),
                          control: CGPoint(x: 0.800, y: 0.520))
        back.addLine(to: CGPoint(x: 0.240, y: 0.720))
        back.addQuadCurve(to: CGPoint(x: 0.300, y: 0.330),
                          control: CGPoint(x: 0.200, y: 0.520))
        back.closeSubpath()
        path.addPath(back)
        // 무릎 — 양옆으로 벌어져 나온다. 이 두 덩어리가 "앉아 있다"를 만든다.
        path.addEllipse(in: CGRect(x: 0.075, y: 0.560, width: 0.290, height: 0.290))
        path.addEllipse(in: CGRect(x: 0.635, y: 0.560, width: 0.290, height: 0.290))
        // 발끝.
        path.addRoundedRect(in: CGRect(x: 0.100, y: 0.850, width: 0.230, height: 0.110),
                            cornerSize: CGSize(width: 0.045, height: 0.045))
        path.addRoundedRect(in: CGRect(x: 0.670, y: 0.850, width: 0.230, height: 0.110),
                            cornerSize: CGSize(width: 0.045, height: 0.045))
        return path
    }

    /// 단위 상자의 도형을 실제 사각형으로 옮긴다. `flipped`면 좌우를 뒤집는다(좌타자).
    static func scaled(_ unitPath: Path, into rect: CGRect, flipped: Bool = false) -> Path {
        var transform = CGAffineTransform(translationX: rect.minX, y: rect.minY)
            .scaledBy(x: rect.width, y: rect.height)
        if flipped {
            transform = transform.translatedBy(x: 1, y: 0).scaledBy(x: -1, y: 1)
        }
        return unitPath.applying(transform)
    }
}
