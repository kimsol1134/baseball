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
/// 충돌은 `revision`이 큰 쪽이 이긴다. 로컬에는 직전 두 세대도 함께 남겨, 현재 파일과
/// iCloud 사본을 모두 읽지 못하더라도 마지막 정상 세이브로 자동 복구한다.
struct SaveSync {
    enum ReadSource: Equatable {
        case local
        case remote
        case backup
    }

    enum RecoveryRead: Equatable {
        /// 로컬·iCloud·백업 어디에도 저장 바이트가 없다.
        case missing
        /// 리비전을 해석할 수 있는 정상 후보다.
        case value(Data, source: ReadSource)
        /// 바이트는 남아 있지만 현재 앱이 어느 후보도 해석하지 못한다.
        /// 이 경우 원본을 절대 덮어쓰지 않는다.
        case unreadable
    }

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

    private var storageRoot: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private var fileURL: URL {
        storageRoot.appendingPathComponent(key)
    }

    private var backupURLs: [URL] {
        [
            storageRoot.appendingPathComponent("\(key).backup-1"),
            storageRoot.appendingPathComponent("\(key).backup-2"),
        ]
    }

    private var unreadableLocalURL: URL {
        storageRoot.appendingPathComponent("\(key).unreadable-local")
    }

    private var unreadableRemoteURL: URL {
        storageRoot.appendingPathComponent("\(key).unreadable-remote")
    }

    // MARK: - 쓰기

    /// 현재 로컬 파일을 두 세대까지 보존한 뒤 새 값을 원자적으로 쓰고 iCloud에도 올린다.
    @discardableResult
    func write(_ data: Data) -> Bool {
        do {
            if let current = try? Data(contentsOf: fileURL), current != data {
                try preserveAsNewestBackup(current)
            }
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
        discardRecoveryCopies()
        store.removeObject(forKey: key)
        store.synchronize()
    }

    /// 명시적 전체 삭제가 성공한 뒤 옛 세대가 다시 살아나지 않게 복구용 사본만 지운다.
    func discardRecoveryCopies() {
        for url in backupURLs + [unreadableLocalURL, unreadableRemoteURL] {
            try? FileManager.default.removeItem(at: url)
        }
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
        switch readRecovering(revision: revision, conflictPriority: conflictPriority) {
        case .value(let data, _): data
        case .missing, .unreadable: nil
        }
    }

    /// 로컬·iCloud·두 백업을 한 번에 판정한다. `revision`을 뽑을 수 없는 후보는 손상 또는
    /// 미지원 스키마로 보고 승자 후보에서 제외한다. 정상 후보가 있으면 가장 높은 리비전을
    /// 현재 로컬과 iCloud에 되심되, 덮기 전 읽을 수 없던 원본은 별도 복구 사본으로 보존한다.
    func readRecovering(
        revision: (Data) -> UInt64?,
        conflictPriority: (Data) -> Int = { _ in 0 }
    ) -> RecoveryRead {
        let local = try? Data(contentsOf: fileURL)
        store.synchronize()
        let remote = store.data(forKey: key)
        let backups = backupURLs.compactMap { try? Data(contentsOf: $0) }

        let allCandidates: [(data: Data, source: ReadSource)] =
            [(local, .local), (remote, .remote)].compactMap { data, source in
                data.map { ($0, source) }
            } + backups.map { ($0, .backup) }
        guard !allCandidates.isEmpty else { return .missing }

        let valid = allCandidates.filter { revision($0.data) != nil }
        guard var winner = valid.first else { return .unreadable }
        for candidate in valid.dropFirst() {
            let preferred = Self.preferredData(
                local: winner.data,
                remote: candidate.data,
                revision: revision,
                conflictPriority: conflictPriority
            )
            if preferred != winner.data {
                winner = candidate
            }
        }

        if local != winner.data {
            if let local, revision(local) != nil {
                try? preserveAsNewestBackup(local)
            } else {
                preserveUnreadable(local, at: unreadableLocalURL, revision: revision)
            }
            try? winner.data.write(to: fileURL, options: .atomic)
        }
        if remote != winner.data {
            preserveUnreadable(remote, at: unreadableRemoteURL, revision: revision)
            store.set(winner.data, forKey: key)
            store.synchronize()
        }
        return .value(winner.data, source: winner.source)
    }

    private func preserveAsNewestBackup(_ data: Data) throws {
        if let firstBackup = try? Data(contentsOf: backupURLs[0]), firstBackup != data {
            try firstBackup.write(to: backupURLs[1], options: .atomic)
        }
        try data.write(to: backupURLs[0], options: .atomic)
    }

    private func preserveUnreadable(
        _ data: Data?,
        at url: URL,
        revision: (Data) -> UInt64?
    ) {
        guard let data, revision(data) == nil,
              !FileManager.default.fileExists(atPath: url.path) else { return }
        try? data.write(to: url, options: .atomic)
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
