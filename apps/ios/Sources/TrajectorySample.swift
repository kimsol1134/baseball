import Foundation

/// 코어가 내보내는 3D 좌표 한 점. 평면 배열 [시간ms, 좌우, 전후, 높이]를 4개씩 끊어 만든다.
/// 단위는 모두 0.1cm이므로 1,000으로 나누면 미터가 된다.
struct TrajectorySample {
    let timeMilliseconds: Double
    let lateralMeters: Double
    let forwardMeters: Double
    let heightMeters: Double

    static func decode(_ series: [Int]?) -> [TrajectorySample] {
        guard let series, series.count >= 8 else { return [] }
        var samples: [TrajectorySample] = []
        var index = 0
        while index + 3 < series.count {
            let time = Double(series[index])
            let lateral = Double(series[index + 1]) / 1_000
            let forward = Double(series[index + 2]) / 1_000
            let height = Double(series[index + 3]) / 1_000
            samples.append(
                TrajectorySample(
                    timeMilliseconds: time,
                    lateralMeters: lateral,
                    forwardMeters: forward,
                    heightMeters: height
                )
            )
            index += 4
        }
        return samples
    }
}
