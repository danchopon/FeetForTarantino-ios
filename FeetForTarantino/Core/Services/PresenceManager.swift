import Foundation
import Observation

@Observable
final class PresenceManager {
    private(set) var onlineUserIds: Set<Int> = []

    private var heartbeatTask: Task<Void, Never>?
    private let service = MovieService()

    func start(chatId: Int64, userId: Int) {
        stop()
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
