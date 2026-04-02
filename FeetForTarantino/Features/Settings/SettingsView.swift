import SwiftUI

struct SettingsView: View {
    @AppStorage("username") private var username: String = ""
    @AppStorage("appearance") private var appearance: String = "system"
    @Environment(ChatStore.self) private var chatStore
    @State private var showAddGroup = false
    @State private var newGroupId: String = ""
    @State private var newGroupName: String = ""

    private var chats: [SavedChat] { chatStore.chats }

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Appearance")) {
                    Picker("Theme", selection: $appearance) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)
                }

                Section(
                    header: Text("Your Name"),
                    footer: Text("Used when adding or marking movies as watched.")
                ) {
                    TextField("Your name", text: $username)
                        .autocorrectionDisabled()
                }

                Section(
                    header: Text("Connected Groups"),
                    footer: Text("Swipe left to remove a group. Or send /app in your Telegram group to connect automatically.")
                ) {
                    ForEach(chats) { (chat: SavedChat) in
                        HStack(spacing: 12) {
                            Image(systemName: "person.3.fill")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(chat.name)
                                    .font(.body)
                                Text(String(chat.chatId))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
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

                    Button(action: { showAddGroup = true }) {
                        Label("Add Group Manually", systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showAddGroup) {
                addGroupSheet
            }
        }
    }

    private var addGroupSheet: some View {
        NavigationStack {
            Form {
                Section(header: Text("Group Name")) {
                    TextField("e.g. Movie Night", text: $newGroupName)
                        .autocorrectionDisabled()
                }
                Section(
                    header: Text("Telegram Chat ID"),
                    footer: Text("You can find the chat ID by forwarding a message from the group to @userinfobot.")
                ) {
                    TextField("-1001234567890", text: $newGroupId)
                        .keyboardType(.numbersAndPunctuation)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Add Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showAddGroup = false
                        newGroupId = ""
                        newGroupName = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let chatId = Int64(newGroupId), !newGroupName.isEmpty {
                            chatStore.addManually(chatId: chatId, name: newGroupName)
                            showAddGroup = false
                            newGroupId = ""
                            newGroupName = ""
                        }
                    }
                    .disabled(newGroupName.isEmpty || Int64(newGroupId) == nil)
                }
            }
        }
    }
}
