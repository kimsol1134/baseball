import Foundation

/// 날아오는 공이 **돌아 보이게** 하는 값(Phase 4 장식).
///
/// 흰 원 하나는 아무리 빨라도 도는 것으로 읽히지 않는다. 실밥 두 줄이 돌아야 회전이
/// 보이고, 회전이 보여야 커브와 포심이 눈으로 구별된다.
///
/// 커널 결과에서만 값을 뽑는다 — 난수도, 시간도 쓰지 않는다. 같은 공은 언제나 같은
/// 회전으로 그려진다.
public enum PitchSpinPresentation {
    /// 비행 동안 도는 바퀴 수.
    ///
    /// 실제 회전수(분당 2000회 남짓)를 그대로 그리면 60fps에서는 그냥 깜빡임이다.
    /// 눈이 회전으로 읽는 범위에 눌러 담되, 빠른 공이 더 도는 순서만 지킨다.
    public static func revolutions(velocityTenthsKPH: Int) -> Double {
        let kph = Double(max(0, velocityTenthsKPH)) / 10
        // 100km/h ≈ 1.5바퀴, 160km/h ≈ 3바퀴.
        return min(3.4, max(0.8, 0.6 + kph / 60))
    }

    /// 지금 이 순간 실밥이 놓인 각도(라디안).
    ///
    /// 브레이크가 방향을 정한다. 떠오르는 공(양의 수직 브레이크)은 백스핀이라 한쪽으로,
    /// 떨어지는 공은 반대로 돈다. 가로 브레이크가 크면 축이 기울어 옆으로 도는 느낌이 된다.
    public static func seamAngle(
        horizontalBreakTenthsCM: Int,
        verticalBreakTenthsCM: Int,
        velocityTenthsKPH: Int,
        flightProgress: Double
    ) -> Double {
        let progress = min(1, max(0, flightProgress))
        let direction: Double = verticalBreakTenthsCM >= 0 ? 1 : -1
        let turns = revolutions(velocityTenthsKPH: velocityTenthsKPH) * progress
        return direction * turns * 2 * .pi + axisTilt(horizontalBreakTenthsCM: horizontalBreakTenthsCM)
    }

    /// 회전축의 기울기. 슬라이더처럼 옆으로 휘는 공은 실밥도 옆으로 눕는다.
    public static func axisTilt(horizontalBreakTenthsCM: Int) -> Double {
        let centimetres = Double(horizontalBreakTenthsCM) / 10
        // ±30cm에서 최대 ±0.6rad. 그 밖은 눕히지 않는다 — 더 기울여도 읽히지 않는다.
        return max(-0.6, min(0.6, centimetres / 50))
    }
}
