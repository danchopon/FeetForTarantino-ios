import Foundation
import Observation

private struct WSEvent: Decodable {
    let event: String
    let chatId: Int64

    enum CodingKeys: String, CodingKey {
        case event
        case chatId = "chat_id"
    }
}

@Observable
@MainActor
final class WebSocketManager {
    private(set) var movieEventCount = 0
    private(set) var basketEventCount = 0

    private var wsTask: URLSessionWebSocketTask?
    private var currentChatId: Int64?

    func connect(chatId: Int64) {
        guard chatId != currentChatId else { return }
        disconnect()
        guard let url = MovieService.webSocketURL(chatId: chatId) else { return }
        currentChatId = chatId
        let task = URLSession.shared.webSocketTask(with: url)
        wsTask = task
        task.resume()
        receiveLoop()
    }

    func disconnect() {
        wsTask?.cancel(with: .goingAway, reason: nil)
        wsTask = nil
        currentChatId = nil
    }

    private func receiveLoop() {
        Task { @MainActor [weak self] in
            guard let self, let task = self.wsTask else { return }
            do {
                while true {
                    let message = try await task.receive()
                    if case .string(let text) = message,
                       let data = text.data(using: .utf8),
                       let event = try? JSONDecoder().decode(WSEvent.self, from: data) {
                        self.handle(event)
                    }
                }
            } catch {
                guard let chatId = self.currentChatId else { return }
                try? await Task.sleep(for: .seconds(5))
                guard self.currentChatId == chatId else { return }
                self.connect(chatId: chatId)
            }
        }
    }

    private func handle(_ event: WSEvent) {
        switch event.event {
        case "movie_added", "movie_watched", "movie_unwatched", "movie_removed", "movie_renamed":
            movieEventCount += 1
        case "basket_updated":
            basketEventCount += 1
        default:
            break
        }
    }
}
