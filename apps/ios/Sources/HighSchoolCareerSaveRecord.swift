import Foundation
import SimulationCore

/// 고교 커리어의 디스크 스키마. 진행이 없어도(회차 사이) 계승분을 담을 수 있게
/// `result`가 옵셔널이다. 테스트에서 인코딩 호환을 검증하므로 스토어 중첩 타입이 아니다.
struct HighSchoolCareerSaveRecord: Codable {
    let result: HighSchoolCareerResult?
    let inheritance: HighSchoolCareerStore.Inheritance
    /// 옵셔널이라 이 필드가 없는 옛 저장본도 그대로 열린다.
    var archive: [HighSchoolCareerStore.LifeRecord]? = nil
    /// 이미 프로로 보낸 회차. 없는 옛 저장본은 nil이다.
    var enteredProCareerID: String? = nil
    /// 이번 회차의 별명. 없는 옛 저장본은 빈 목록으로 시작한다.
    var nicknames: [Nickname]? = nil
    /// 이번 회차의 연대기. 없는 옛 저장본은 빈 목록으로 시작한다.
    var chronicle: [HighSchoolCareerStore.ChronicleEntry]? = nil
    /// 챕터 목표 진행 기준점·축하 여부. 없는 옛 저장본은 현재 값으로 초기화된다.
    var chapterStartStrikeouts: Int? = nil
    var goalCelebratedChapter: Int? = nil
    /// 성격을 만든 선택들. 없는 옛 저장본은 0에서 시작한다.
    var responseTally: HighSchoolCareerStore.ResponseTally? = nil
    /// Structured relationship memories. Missing old saves continue with an empty list.
    var bondMemories: [HighSchoolCareerStore.PlayerBondMemory]? = nil
    /// Stable IDs of rebirth scenes already consumed in the live run.
    var rebirthEventIDs: [String]? = nil
    /// 이번 챕터의 훈련 성장 정산. 없으면 챕터 리뷰가 "훈련 없이 지나간 챕터"라고
    /// 방금 한 플레이를 부정한다(3차 패널 P1) — 옛 저장본은 빈 값으로 시작한다.
    var chapterGains: [String: Int]? = nil
    var chapterTrainingCount: Int? = nil
    /// 이번 회차의 직접 성장량 기준과 아직 확정하지 않은 대표 유산 선택.
    /// 모두 optional이라 기능 도입 전 저장본은 그대로 열린다.
    var careerStartingPitcher: PitcherSnapshot? = nil
    var signatureLegacyRulesVersion: Int? = nil
    var frozenSignatureLegacyCandidates: [CareerSignatureLegacy]? = nil
    var selectedSignatureLegacyID: CareerSignatureLegacyID? = nil
    /// 진행 중 등판의 타석 경계 스냅샷. 없는 옛 저장본은 nil이다.
    var gameResume: PitchSession.ResumeState? = nil
    /// 진행 중 challenge 모드의 careerID. 없는 옛 저장본은 nil = 비도전이다.
    var challengeCareerID: String? = nil
    /// 지난 회차에서 직접 저장한 재도전 목표. 없는 옛 저장본은 추천 없음이다.
    var nextRunIntent: NextRunIntent? = nil
    /// 외부 보상 중복 지급 방지 영수증. 없는 옛 저장본은 빈 집합이다.
    var creditedExternalRewardIDs: Set<String>? = nil
    /// 현재 회차의 약속 결정·숙적 원장. 없는 옛 저장본은 기존 UserDefaults를 migration
    /// source로 사용하고, 다음 저장부터 이 필드에 함께 싣는다.
    var currentCareerRetention: HighSchoolCareerStore.CurrentCareerRetention? = nil
    /// 경기 코어 결과는 저장됐지만 주간·분석·업적 후속 작업이 남은 영수증.
    /// 없는 옛 저장본은 미처리 작업이 없는 것으로 읽는다.
    var pendingGameCompletion: HighSchoolCareerStore.PendingGameCompletion? = nil
    /// 계승-전용 레코드의 충돌 판정용. 없는 옛 저장본은 진행의 리비전으로 판정한다.
    var revision: UInt64? = nil
    /// nil은 버전 필드 도입 전 저장이다. 미래 버전은 덮지 않고 업데이트를 기다린다.
    var schemaVersion: Int? = nil

    var effectiveRevision: UInt64 {
        max(revision ?? 0, result?.snapshot.revision ?? 0)
    }
}

enum HighSchoolCareerRestoreOutcome: Equatable {
    case live(recoveredFromBackup: Bool)
    case needsSetup
    case unavailable
}

extension HighSchoolCareerStore {
    typealias SaveRecord = HighSchoolCareerSaveRecord
    typealias RestoreOutcome = HighSchoolCareerRestoreOutcome
}
