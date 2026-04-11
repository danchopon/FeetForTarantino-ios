import Foundation
import Observation

@Observable
final class PresenceManager {
    private(set) var onlineUserIds: Set<Int> = []

    private var heartbeatTask: Task<Void, Never>?

    func start(chatId: Int64, userId: Int, sessionToken: String) {
        stop()
        let service = MovieService(sessionToken: sessionToken)
        heartbeatTask = Task {
            while !Task.isCancelled {
                try? await service.sendHeartbeat(chatId: chatId, userId: userId)
                if let ids = try? await service.fetchOnlineUsers(chatId: chatId) {
                    onlineUserIds = Set(ids)
                }
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    func stop() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
        onlineUserIds = []
    }
}
