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
    private(set) var sessionInvalid = false

    private var wsTask: URLSessionWebSocketTask?
    private var currentChatId: Int64?
    private var currentSessionToken: String = ""

    func connect(chatId: Int64, sessionToken: String) {
        guard chatId != currentChatId || sessionToken != currentSessionToken else { return }
        disconnect()
        guard let url = MovieService.webSocketURL(chatId: chatId, sessionToken: sessionToken) else { return }
        currentChatId = chatId
        currentSessionToken = sessionToken
        let task = URLSession.shared.webSocketTask(with: url)
        wsTask = task
        task.resume()
        receiveLoop()
    }

    func disconnect() {
        wsTask?.cancel(with: .goingAway, reason: nil)
        wsTask = nil
        currentChatId = nil
        currentSessionToken = ""
        sessionInvalid = false
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
                // Close code 4001: session invalid or chat_id mismatch — do not reconnect
                if let task = self.wsTask, task.closeCode.rawValue == 4001 {
                    self.sessionInvalid = true
                    return
                }
                guard let chatId = self.currentChatId else { return }
                let token = self.currentSessionToken
                try? await Task.sleep(for: .seconds(5))
                guard self.currentChatId == chatId else { return }
                self.connect(chatId: chatId, sessionToken: token)
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
