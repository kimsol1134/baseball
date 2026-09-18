import Foundation
import BaseballIOSDomain
import BaseballIOSPersistence

/// 저장을 파일 한 장으로 꺼낸다(7-E).
///
/// 저장이 거듭 실패할 때 남길 수 있는 마지막 사본이므로 **읽기만 한다** — 내보내기가
/// 저장을 건드리면 그 사본마저 위험해진다.
@MainActor
enum SaveExport {
    /// 지금 디스크에 있는 두 저장본을 그대로 담는다. 담을 것이 없으면 nil.
    static func bundle(
        highSchool: HighSchoolCareerStore,
        pro: MobileCareerStore
    ) -> SaveExportBundle? {
        let bundle = SaveExportBundle.make(
            highSchool: highSchool.sync.read(
                revision: HighSchoolCareerPersistence.revision,
                conflictPriority: { _ in 0 }
            ),
            pro: pro.sync.read(
                revision: ProCareerPersistence.revision,
                conflictPriority: ProCareerPersistence.conflictPriority
            ),
            appVersion: Self.appVersion
        )
        return bundle.isEmpty ? nil : bundle
    }

    /// 공유 시트에 넘길 파일을 임시 폴더에 쓴다. 실패하면 nil — 내보내기 실패가 진행을
    /// 막지는 않는다.
    static func writeTemporaryFile(_ bundle: SaveExportBundle) -> URL? {
        guard let data = bundle.encoded() else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(SaveExportBundle.fileName())
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            return nil
        }
        return url
    }

    static var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(version) (\(build))"
    }
}
