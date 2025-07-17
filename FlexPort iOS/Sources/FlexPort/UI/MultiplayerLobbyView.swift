import SwiftUI
import Combine

// MARK: - Multiplayer Lobby View
struct MultiplayerLobbyView: View {
    @EnvironmentObject var gameManager: GameManager
    @ObservedObject var multiplayerManager = MultiplayerManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedTab = 0
    @State private var roomCode = ""
    @State private var isCreatingRoom = false
    @State private var isJoiningRoom = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var availableRooms: [GameRoom] = []
    @State private var isRefreshing = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Connection Status Header
                ConnectionStatusHeader()
                
                // Tab Selection
                Picker("Mode", selection: $selectedTab) {
                    Text("Join Game").tag(0)
                    Text("Create Game").tag(1)
                    Text("Quick Match").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Content based on tab
                switch selectedTab {
                case 0:
                    JoinGameView(
                        roomCode: $roomCode,
                        isJoiningRoom: $isJoiningRoom,
                        availableRooms: $availableRooms,
                        isRefreshing: $isRefreshing
                    )
                case 1:
                    CreateGameView(isCreatingRoom: $isCreatingRoom)
                case 2:
                    QuickMatchView()
                default:
                    EmptyView()
                }
                
                Spacer()
            }
            .navigationTitle("Multiplayer")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if multiplayerManager.connectionState == .connected {
                        Image(systemName: "wifi")
                            .foregroundColor(.green)
                    } else {
                        Button(action: {
                            Task {
                                await connectToServer()
                            }
                        }) {
                            Image(systemName: "wifi.slash")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
        .onAppear {
            Task {
                await connectToServer()
                await refreshRoomList()
            }
        }
    }
    
    private func connectToServer() async {
        guard multiplayerManager.connectionState == .disconnected else { return }
        
        do {
            // Connect to WebSocket server
            let connected = await withCheckedContinuation { continuation in
                Task {
                    do {
                        try await multiplayerManager.startMultiplayerGame(gameMode: .realtime)
                        continuation.resume(returning: true)
                    } catch {
                        continuation.resume(returning: false)
                    }
                }
            }
            
            if !connected {
                errorMessage = "Failed to connect to multiplayer server"
                showingError = true
            }
        }
    }
    
    private func refreshRoomList() async {
        isRefreshing = true
        
        // Simulate fetching room list
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Mock data for now
        availableRooms = [
            GameRoom(
                id: "web-room-1",
                name: "Web Player's Game",
                hostId: "web-player-123",
                players: ["web-player-123", "web-player-456"],
                maxPlayers: 16,
                status: .waiting,
                settings: GameRoomSettings()
            ),
            GameRoom(
                id: "web-room-2", 
                name: "Cross-Platform Battle",
                hostId: "web-player-789",
                players: ["web-player-789"],
                maxPlayers: 8,
                status: .waiting,
                settings: GameRoomSettings()
            )
        ]
        
        isRefreshing = false
    }
}

// MARK: - Connection Status Header
struct ConnectionStatusHeader: View {
    @ObservedObject var multiplayerManager = MultiplayerManager.shared
    
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if multiplayerManager.connectionState == .connected {
                        Text("ws://localhost:8080")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            if multiplayerManager.connectionState == .connected {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(multiplayerManager.networkMetrics.latency * 1000))ms")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(multiplayerManager.connectedPlayers.count) online")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }
    
    var statusColor: Color {
        switch multiplayerManager.connectionState {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .disconnected:
            return .red
        case .reconnecting:
            return .yellow
        }
    }
    
    var statusText: String {
        switch multiplayerManager.connectionState {
        case .connected:
            return "Connected to Server"
        case .connecting:
            return "Connecting..."
        case .disconnected:
            return "Disconnected"
        case .reconnecting:
            return "Reconnecting..."
        }
    }
}

// MARK: - Join Game View
struct JoinGameView: View {
    @ObservedObject var multiplayerManager = MultiplayerManager.shared
    @Binding var roomCode: String
    @Binding var isJoiningRoom: Bool
    @Binding var availableRooms: [GameRoom]
    @Binding var isRefreshing: Bool
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Room Code Entry
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enter Room Code")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    HStack {
                        TextField("Room Code", text: $roomCode)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.allCharacters)
                            .disableAutocorrection(true)
                        
                        Button(action: {
                            joinRoomWithCode()
                        }) {
                            if isJoiningRoom {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.8)
                            } else {
                                Text("Join")
                                    .fontWeight(.semibold)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(roomCode.isEmpty || isJoiningRoom)
                    }
                    .padding(.horizontal)
                }
                
                Divider()
                    .padding(.vertical)
                
                // Available Rooms
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Available Rooms")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(action: {
                            Task {
                                await refreshRooms()
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.subheadline)
                                .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                                .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                        }
                    }
                    .padding(.horizontal)
                    
                    if availableRooms.isEmpty && !isRefreshing {
                        Text("No rooms available. Create one or wait for others to host.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 40)
                            .frame(maxWidth: .infinity)
                    } else {
                        ForEach(availableRooms) { room in
                            RoomCard(room: room) {
                                joinRoom(room)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
    }
    
    private func joinRoomWithCode() {
        guard !roomCode.isEmpty else { return }
        
        isJoiningRoom = true
        
        Task {
            do {
                try await multiplayerManager.joinGameSession(
                    GameSession(id: roomCode, hostPlayerId: "unknown", maxPlayers: 16)
                )
                
                // Dismiss lobby on successful join
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    window.rootViewController?.dismiss(animated: true)
                }
            } catch {
                // Handle error
                isJoiningRoom = false
            }
        }
    }
    
    private func joinRoom(_ room: GameRoom) {
        isJoiningRoom = true
        
        Task {
            do {
                try await multiplayerManager.joinGameSession(
                    GameSession(id: room.id, hostPlayerId: room.hostId, maxPlayers: room.maxPlayers)
                )
                
                // Dismiss lobby on successful join
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    window.rootViewController?.dismiss(animated: true)
                }
            } catch {
                // Handle error
                isJoiningRoom = false
            }
        }
    }
    
    private func refreshRooms() async {
        isRefreshing = true
        // Refresh implementation
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        isRefreshing = false
    }
}

// MARK: - Room Card
struct RoomCard: View {
    let room: GameRoom
    let onJoin: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(room.name)
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        Label("\(room.players.count)/\(room.maxPlayers) players", systemImage: "person.3.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Label(room.hostId.hasPrefix("web") ? "Web Host" : "iOS Host", systemImage: "globe")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                Button("Join") {
                    onJoin()
                }
                .buttonStyle(.bordered)
                .disabled(room.players.count >= room.maxPlayers || room.status != .waiting)
            }
            
            if room.settings.privateRoom {
                Label("Private Room", systemImage: "lock.fill")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Create Game View
struct CreateGameView: View {
    @ObservedObject var multiplayerManager = MultiplayerManager.shared
    @Binding var isCreatingRoom: Bool
    
    @State private var roomName = ""
    @State private var maxPlayers = 8
    @State private var isPrivate = false
    @State private var gameMode: GameMode = .realtime
    @State private var startingCash = 1000000
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Room Settings
                VStack(alignment: .leading, spacing: 16) {
                    Text("Room Settings")
                        .font(.headline)
                    
                    // Room Name
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Room Name")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextField("Enter room name", text: $roomName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Max Players
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Max Players: \(maxPlayers)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Slider(value: Binding(
                            get: { Double(maxPlayers) },
                            set: { maxPlayers = Int($0) }
                        ), in: 2...16, step: 1)
                    }
                    
                    // Game Mode
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Game Mode")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Picker("Game Mode", selection: $gameMode) {
                            Text("Real-time").tag(GameMode.realtime)
                            Text("Turn-based").tag(GameMode.turnBased)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    // Starting Cash
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Starting Cash: $\(startingCash / 1000)K")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Slider(value: Binding(
                            get: { Double(startingCash) },
                            set: { startingCash = Int($0) }
                        ), in: 100000...5000000, step: 100000)
                    }
                    
                    // Private Room Toggle
                    Toggle("Private Room", isOn: $isPrivate)
                        .font(.subheadline)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                
                // Create Button
                Button(action: createRoom) {
                    if isCreatingRoom {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Label("Create Room", systemImage: "plus.circle.fill")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(roomName.isEmpty ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                .disabled(roomName.isEmpty || isCreatingRoom)
                
                // Info Text
                Text("Your room will be visible to all players on the network, including web players.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }
    
    private func createRoom() {
        guard !roomName.isEmpty else { return }
        
        isCreatingRoom = true
        
        Task {
            do {
                // Create room settings
                let settings = GameRoomSettings(
                    maxTurns: 100,
                    startingCash: startingCash,
                    aiDifficulty: 1,
                    enabledFeatures: ["trading", "shipping", "markets"],
                    privateRoom: isPrivate
                )
                
                // This would create the room through MultiplayerManager
                // For now, simulate success
                try await Task.sleep(nanoseconds: 1_000_000_000)
                
                // Dismiss lobby on successful creation
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    window.rootViewController?.dismiss(animated: true)
                }
            } catch {
                isCreatingRoom = false
            }
        }
    }
}

// MARK: - Quick Match View
struct QuickMatchView: View {
    @ObservedObject var multiplayerManager = MultiplayerManager.shared
    @State private var isSearching = false
    @State private var searchTime = 0
    @State private var timer: Timer?
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Animation
            ZStack {
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                        .frame(width: 100 + CGFloat(index) * 40, height: 100 + CGFloat(index) * 40)
                        .scaleEffect(isSearching ? 1.2 : 1.0)
                        .opacity(isSearching ? 0.0 : 1.0)
                        .animation(
                            isSearching ?
                            Animation.easeOut(duration: 2)
                                .repeatForever(autoreverses: false)
                                .delay(Double(index) * 0.3) :
                            .default,
                            value: isSearching
                        )
                }
                
                Image(systemName: "network")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
                    .rotationEffect(.degrees(isSearching ? 360 : 0))
                    .animation(
                        isSearching ?
                        Animation.linear(duration: 2).repeatForever(autoreverses: false) :
                        .default,
                        value: isSearching
                    )
            }
            
            VStack(spacing: 12) {
                Text(isSearching ? "Finding Match..." : "Quick Match")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                if isSearching {
                    Text("Searching for \(searchTime) seconds")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text("Join any available game instantly")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: toggleQuickMatch) {
                Text(isSearching ? "Cancel" : "Start Quick Match")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isSearching ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func toggleQuickMatch() {
        if isSearching {
            // Cancel search
            isSearching = false
            timer?.invalidate()
            searchTime = 0
        } else {
            // Start search
            isSearching = true
            searchTime = 0
            
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                searchTime += 1
                
                // Simulate finding a match after 3-8 seconds
                if searchTime >= Int.random(in: 3...8) {
                    matchFound()
                }
            }
        }
    }
    
    private func matchFound() {
        timer?.invalidate()
        isSearching = false
        
        // Join the found match
        Task {
            // Simulate joining
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            // Dismiss lobby
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController?.dismiss(animated: true)
            }
        }
    }
}

// MARK: - Game Room Model
struct GameRoom: Identifiable {
    let id: String
    let name: String
    let hostId: String
    let players: [String]
    let maxPlayers: Int
    let status: RoomStatus
    let settings: GameRoomSettings
}

enum RoomStatus {
    case waiting
    case inProgress
    case finished
}

struct GameRoomSettings {
    var maxTurns: Int = 100
    var startingCash: Int = 1000000
    var aiDifficulty: Int = 1
    var enabledFeatures: [String] = ["trading", "shipping", "markets"]
    var privateRoom: Bool = false
}