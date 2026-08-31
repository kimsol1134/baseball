import SimulationCore

/// 화면·프레젠테이션이 엔진 중첩 타입을 시그니처로 물지 않게 하는 별칭.
public typealias TrainingGrowthOutlook = HighSchoolCareerEngine.TrainingGrowthOutlook
public typealias DraftForecastSnapshot = HighSchoolCareerEngine.DraftForecastSnapshot

/// 고교·프로 스토어가 같은 로딩 단계를 쓴다. 화면은 이 이름만 본다.
public enum CareerLoadState: Equatable, Sendable {
    case loading
    /// 저장된 커리어가 없다. 선수 유형을 고르는 화면으로 간다.
    case needsSetup
    case ready
    case failed(String)
}

/// 직전 회차와 이번 시작 능력의 차이를 설명하는 표시 전용 비교.
public struct InheritedStartComparison: Equatable {
    public struct Source: Equatable, Identifiable {
        public let id: String
        public let ratingDelta: Int
        public let signatureLegacyID: CareerSignatureLegacyID?

        public init(
            id: String,
            ratingDelta: Int,
            signatureLegacyID: CareerSignatureLegacyID?
        ) {
            self.id = id
            self.ratingDelta = ratingDelta
            self.signatureLegacyID = signatureLegacyID
        }
    }

    public let previousName: String
    public let careerID: String
    public let previous: LifeRecord.AbilityLine
    public let current: LifeRecord.AbilityLine
    public let sources: [Source]

    public var totalDelta: Int { current.total - previous.total }
    public var inheritedRatingDelta: Int { sources.reduce(0) { $0 + $1.ratingDelta } }

    public init(
        previousName: String,
        careerID: String,
        previous: LifeRecord.AbilityLine,
        current: LifeRecord.AbilityLine,
        sources: [Source]
    ) {
        self.previousName = previousName
        self.careerID = careerID
        self.previous = previous
        self.current = current
        self.sources = sources
    }
}
