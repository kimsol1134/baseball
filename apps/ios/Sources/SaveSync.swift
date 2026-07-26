import Foundation

/// 기기 사이로 진행을 옮기는 계층.
///
/// 이전에는 `Application Support`의 파일 하나가 전부라, 앱을 지우면 회차·기억·업적이 모두
/// 사라지고 새 기기로 옮길 방법도 없었다. 수십 시간을 쌓는 환생 게임에서 이건 별점 1점 사유다.
///
/// iCloud 키-값 저장소를 쓴다. CloudKit보다 가볍고 계정만 있으면 동작하며, 세이브가 수십 KB라
/// 1MB 한도에 여유가 크다. **로컬 파일이 항상 원본이고 iCloud는 거울이다** — iCloud를 못 써도
/// 게임은 그대로 돌아간다.
///
/// 충돌은 `revision`이 큰 쪽이 이긴다. 스냅숏이 이미 단조 증가하는 리비전을 갖고 있어서
/// 별도 타임스탬프나 벡터 클록이 필요 없다.
struct SaveSync {
    /// 저장 파일 이름이자 iCloud 키.
    let key: String

    private var store: NSUbiquitousKeyValueStore { .default }

    private var fileURL: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.appendingPathComponent(key)
    }

    // MARK: - 쓰기

    /// 로컬에 원자적으로 쓰고 iCloud에도 올린다.
    func write(_ data: Data) {
        try? data.write(to: fileURL, options: .atomic)
        store.set(data, forKey: key)
        store.synchronize()
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
        store.removeObject(forKey: key)
        store.synchronize()
    }

    // MARK: - 읽기

    /// 로컬과 iCloud 중 리비전이 큰 쪽을 돌려준다.
    ///
    /// - Parameter revision: 저장된 데이터에서 리비전을 뽑는 함수. 뽑지 못하면 그 후보는 진다.
    func read(revision: (Data) -> UInt64?) -> Data? {
        let local = try? Data(contentsOf: fileURL)
        store.synchronize()
        let remote = store.data(forKey: key)

        switch (local, remote) {
        case (nil, nil):
            return nil
        case (let local?, nil):
            return local
        case (nil, let remote?):
            // 새 기기다. 내려받은 것을 로컬에도 심어 다음 실행부터 빠르게 연다.
            try? remote.write(to: fileURL, options: .atomic)
            return remote
        case (let local?, let remote?):
            let localRevision = revision(local) ?? 0
            let remoteRevision = revision(remote) ?? 0
            guard remoteRevision > localRevision else { return local }
            try? remote.write(to: fileURL, options: .atomic)
            return remote
        }
    }

    /// 다른 기기에서 진행이 올라왔을 때 알림을 받는다. 화면이 이 신호로 상태를 다시 읽는다.
    static func observeRemoteChanges(_ handler: @escaping () -> Void) -> NSObjectProtocol {
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { _ in handler() }
    }

    /// 앱 시작 때 한 번 호출해 iCloud 쪽 최신값을 끌어온다.
    static func prime() {
        NSUbiquitousKeyValueStore.default.synchronize()
    }
}
