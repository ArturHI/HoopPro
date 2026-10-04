import Foundation
import WatchConnectivity

final class ConnectivityManager: NSObject, ObservableObject {
    static let shared = ConnectivityManager()

    @Published private(set) var isReachable = false
    #if os(iOS)
    @Published private(set) var isWatchAppInstalled = false
    #endif

    /// Set before `activate()`; called on the main actor for each event from the peer.
    var onEvent: (@MainActor (SessionEvent) -> Void)?

    private var queuedPayloads: [[String: Any]] = []

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Call from the main thread. Delivers immediately when the peer is
    /// reachable, otherwise queues with the system for in-order delivery later.
    func send(_ event: SessionEvent) {
        guard WCSession.isSupported(), let payload = event.payload else { return }
        let session = WCSession.default
        guard session.activationState == .activated else {
            queuedPayloads.append(payload)
            return
        }
        deliver(payload, over: session)
    }

    private func deliver(_ payload: [String: Any], over session: WCSession) {
        // Always try the live channel first: `isReachable` can lag behind
        // reality, and an unreachable send just fails into the queued path.
        session.sendMessage(payload, replyHandler: nil) { [weak self] _ in
            self?.enqueue(payload, over: session)
        }
    }

    private func enqueue(_ payload: [String: Any], over session: WCSession) {
        #if os(iOS)
        guard session.isPaired, session.isWatchAppInstalled else { return }
        #endif
        session.transferUserInfo(payload)
    }

    private func receive(_ payload: [String: Any]) {
        guard let event = SessionEvent(payload: payload) else { return }
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                self.onEvent?(event)
            }
        }
    }
}

extension ConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            #if os(iOS)
            self.isWatchAppInstalled = session.isWatchAppInstalled
            #endif
            guard activationState == .activated else { return }
            let queued = self.queuedPayloads
            self.queuedPayloads = []
            queued.forEach { self.deliver($0, over: session) }
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchAppInstalled = session.isWatchAppInstalled
        }
    }
    #endif

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        receive(message)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        receive(userInfo)
    }
}
