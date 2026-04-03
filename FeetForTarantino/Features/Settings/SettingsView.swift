import SwiftUI

struct SettingsView: View {
    @Environment(ChatStore.self) private var chatStore

    private var chats: [SavedChat] { chatStore.chats }

    var body: some View {
        NavigationStack {
            List {
                Section(
                    header: Text("Connected Groups"),
                    footer: Text("Swipe left to remove a group. Send /app in your Telegram group to add a new one.")
                ) {
                    ForEach(chats) { (chat: SavedChat) in
                        HStack(spacing: 12) {
                            Image(systemName: "person.3.fill")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(chat.name)
                                    .font(.body)
                                if let user = chatStore.selectedUser(for: chat.chatId) {
                                    Text(user.firstName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if chat.id == chatStore.selectedChat?.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                                    .font(.subheadline)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { chatStore.select(chat) }
                    }
                    .onDelete { offsets in
                        chatStore.remove(at: offsets)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
