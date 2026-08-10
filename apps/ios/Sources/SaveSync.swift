import Foundation

/// SaveSync의 원격 거울 경계. 운영에서는 iCloud KVS를 그대로 쓰고, 테스트에서는
/// entitlement가 필요 없는 메모리 저장소를 주입한다.
protocol SaveSyncRemoteStoring: AnyObject {
    func data(forKey key: String) -> Data?
    func set(_ value: Any?, forKey key: String)
    func removeObject(forKey key: String)
    @discardableResult func synchronize() -> Bool
}

extension NSUbiquitousKeyValueStore: SaveSyncRemoteStoring {}

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

    private let store: any SaveSyncRemoteStoring

    init(
        key: String,
        store: any SaveSyncRemoteStoring = NSUbiquitousKeyValueStore.default
    ) {
        self.key = key
        self.store = store
    }

    private var fileURL: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.appendingPathComponent(key)
    }

    // MARK: - 쓰기

    /// 로컬에 원자적으로 쓰고 iCloud에도 올린다.
    @discardableResult
    func write(_ data: Data) -> Bool {
        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            return false
        }
        store.set(data, forKey: key)
        store.synchronize()
        return true
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
    /// - Parameter conflictPriority: 같은 리비전에서 삭제 묘비처럼 반드시 이겨야 하는
    ///   의미 우선순위. 같은 우선순위끼리는 raw data의 사전순으로 결정론적으로 수렴한다.
    func read(
        revision: (Data) -> UInt64?,
        conflictPriority: (Data) -> Int = { _ in 0 }
    ) -> Data? {
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
            let winner = Self.preferredData(
                local: local,
                remote: remote,
                revision: revision,
                conflictPriority: conflictPriority
            )
            guard winner != local else {
                // A deterministic local winner must heal the cloud copy too. Otherwise two
                // devices keep seeing the same equal-revision conflict forever.
                if remote != local {
                    store.set(local, forKey: key)
                    store.synchronize()
                }
                return local
            }
            try? winner.write(to: fileURL, options: .atomic)
            return winner
        }
    }

    /// Pure conflict resolver used by tests and every SaveSync record type.
    ///
    /// A decodable revision always beats an undecodable candidate. Equal revisions first use the
    /// caller's semantic priority (tombstone > live), then choose the lexicographically greater
    /// byte sequence. The final tie-break is independent of device or read direction.
    static func preferredData(
        local: Data,
        remote: Data,
        revision: (Data) -> UInt64?,
        conflictPriority: (Data) -> Int = { _ in 0 }
    ) -> Data {
        switch (revision(local), revision(remote)) {
        case (nil, nil):
            break
        case (.some, nil):
            return local
        case (nil, .some):
            return remote
        case (let localRevision?, let remoteRevision?):
            if localRevision != remoteRevision {
                return remoteRevision > localRevision ? remote : local
            }
        }

        let localPriority = conflictPriority(local)
        let remotePriority = conflictPriority(remote)
        if localPriority != remotePriority {
            return remotePriority > localPriority ? remote : local
        }
        if local == remote { return local }
        return local.lexicographicallyPrecedes(remote) ? remote : local
    }

    /// 다른 기기에서 진행이 올라왔을 때 알림을 받는다. 화면이 이 신호로 상태를 다시 읽는다.
    static func observeRemoteChanges(
        _ handler: @escaping @MainActor @Sendable () -> Void
    ) -> NSObjectProtocol {
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { _ in
            Task { @MainActor in handler() }
        }
    }

    /// 앱 시작 때 한 번 호출해 iCloud 쪽 최신값을 끌어온다.
    static func prime() {
        NSUbiquitousKeyValueStore.default.synchronize()
    }
}
