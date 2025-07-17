import SwiftUI
import Charts

// MARK: - Progression View

struct ProgressionView: View {
    @StateObject private var progressionSystem = ProgressionSystem()
    @StateObject private var gameCenterManager = GameCenterManager.shared
    @State private var selectedTab = 0
    @State private var showingAchievementDetail: Achievement?
    @State private var showingLevelUpAnimation = false
    @State private var levelUpRewards: [String] = []
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with level progress
                ProgressionHeaderView(progressionSystem: progressionSystem)
                    .padding()
                    .background(Color(.systemBackground))
                
                // Tab selector
                Picker("View", selection: $selectedTab) {
                    Text("Progress").tag(0)
                    Text("Achievements").tag(1)
                    Text("Unlocks").tag(2)
                    Text("Leaderboards").tag(3)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content
                TabView(selection: $selectedTab) {
                    ProgressView(progressionSystem: progressionSystem)
                        .tag(0)
                    
                    AchievementsView(
                        achievements: progressionSystem.achievements,
                        onAchievementTap: { achievement in
                            showingAchievementDetail = achievement
                        }
                    )
                    .tag(1)
                    
                    UnlocksView(
                        unlockedFeatures: progressionSystem.unlockedFeatures,
                        currentLevel: progressionSystem.currentLevel
                    )
                    .tag(2)
                    
                    LeaderboardsView()
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("Progression")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $showingAchievementDetail) { achievement in
                AchievementDetailView(achievement: achievement)
            }
            .overlay(
                LevelUpAnimationView(
                    isShowing: $showingLevelUpAnimation,
                    level: progressionSystem.currentLevel,
                    rewards: levelUpRewards
                )
            )
            .onReceive(NotificationCenter.default.publisher(for: .levelUpRewards)) { notification in
                if let rewards = notification.userInfo?["rewards"] as? [String] {
                    levelUpRewards = rewards
                    showingLevelUpAnimation = true
                }
            }
        }
    }
}

// MARK: - Progression Header

struct ProgressionHeaderView: View {
    @ObservedObject var progressionSystem: ProgressionSystem
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Level \(progressionSystem.currentLevel)")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("\(progressionSystem.currentExperience) / \(progressionSystem.experienceToNextLevel) XP")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Level badge
                ZStack {
                    Circle()
                        .fill(levelGradient(for: progressionSystem.currentLevel))
                        .frame(width: 60, height: 60)
                    
                    Text("\(progressionSystem.currentLevel)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
            
            // XP Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(height: 12)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(progressionSystem.levelProgress), height: 12)
                        .animation(.spring(), value: progressionSystem.levelProgress)
                }
            }
            .frame(height: 12)
        }
    }
    
    private func levelGradient(for level: Int) -> LinearGradient {
        let colors: [Color]
        
        switch level {
        case 1...10:
            colors = [.green, .mint]
        case 11...25:
            colors = [.blue, .cyan]
        case 26...40:
            colors = [.purple, .pink]
        case 41...50:
            colors = [.orange, .red]
        default:
            colors = [.yellow, .orange]
        }
        
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Progress View

struct ProgressView: View {
    @ObservedObject var progressionSystem: ProgressionSystem
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // XP History Chart
                XPHistoryChart()
                    .frame(height: 200)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                
                // Stats Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    StatCard(
                        title: "Total XP",
                        value: "\(progressionSystem.currentExperience + calculateTotalXPEarned())",
                        icon: "star.fill",
                        color: .yellow
                    )
                    
                    StatCard(
                        title: "Achievements",
                        value: "\(progressionSystem.achievements.filter { $0.isUnlocked }.count)",
                        icon: "trophy.fill",
                        color: .orange
                    )
                    
                    StatCard(
                        title: "Features Unlocked",
                        value: "\(progressionSystem.unlockedFeatures.count)",
                        icon: "lock.open.fill",
                        color: .green
                    )
                    
                    StatCard(
                        title: "Next Unlock",
                        value: "Level \(progressionSystem.currentLevel + 1)",
                        icon: "arrow.up.circle.fill",
                        color: .blue
                    )
                }
                
                // Recent Activity
                RecentActivityView()
                    .padding(.vertical)
            }
            .padding()
        }
    }
    
    private func calculateTotalXPEarned() -> Int {
        // Calculate total XP from all previous levels
        var total = 0
        for level in 1..<progressionSystem.currentLevel {
            total += Int(Float(100) * pow(1.15, Float(level - 1)))
        }
        return total
    }
}

// MARK: - XP History Chart

struct XPHistoryChart: View {
    @State private var xpHistory: [XPDataPoint] = []
    
    var body: some View {
        Chart(xpHistory) { dataPoint in
            LineMark(
                x: .value("Time", dataPoint.date),
                y: .value("XP", dataPoint.xp)
            )
            .foregroundStyle(.blue)
            .interpolationMethod(.catmullRom)
            
            AreaMark(
                x: .value("Time", dataPoint.date),
                y: .value("XP", dataPoint.xp)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [.blue.opacity(0.3), .blue.opacity(0.1)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.hour())
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel()
            }
        }
        .onAppear {
            generateMockXPHistory()
        }
    }
    
    private func generateMockXPHistory() {
        let calendar = Calendar.current
        let now = Date()
        
        xpHistory = (0..<24).map { hour in
            let date = calendar.date(byAdding: .hour, value: -hour, to: now)!
            let xp = Int.random(in: 100...500) * (24 - hour)
            return XPDataPoint(date: date, xp: xp)
        }.reversed()
    }
}

struct XPDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let xp: Int
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                
                Spacer()
            }
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Recent Activity View

struct RecentActivityView: View {
    @State private var activities: [Activity] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
            
            ForEach(activities) { activity in
                HStack(spacing: 12) {
                    Image(systemName: activity.icon)
                        .foregroundColor(activity.color)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(activity.title)
                            .font(.subheadline)
                        
                        Text(activity.timestamp, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("+\(activity.xpGained) XP")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
                .padding(.vertical, 4)
            }
        }
        .onAppear {
            generateMockActivities()
        }
    }
    
    private func generateMockActivities() {
        let actions = [
            ("Complete Trade", "dollarsign.circle.fill", Color.green, 50),
            ("Ship Purchase", "ferry.fill", Color.blue, 300),
            ("Route Optimized", "map.fill", Color.orange, 150),
            ("Market Analysis", "chart.line.uptrend.xyaxis", Color.purple, 30),
            ("Achievement Unlocked", "trophy.fill", Color.yellow, 500)
        ]
        
        activities = actions.map { action in
            Activity(
                title: action.0,
                icon: action.1,
                color: action.2,
                xpGained: action.3,
                timestamp: Date().addingTimeInterval(-Double.random(in: 0...3600))
            )
        }
    }
}

struct Activity: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
    let xpGained: Int
    let timestamp: Date
}

// MARK: - Achievements View

struct AchievementsView: View {
    let achievements: [Achievement]
    let onAchievementTap: (Achievement) -> Void
    
    @State private var filter: AchievementFilter = .all
    
    enum AchievementFilter: String, CaseIterable {
        case all = "All"
        case unlocked = "Unlocked"
        case locked = "Locked"
        case nearCompletion = "Near Completion"
    }
    
    var filteredAchievements: [Achievement] {
        switch filter {
        case .all:
            return achievements
        case .unlocked:
            return achievements.filter { $0.isUnlocked }
        case .locked:
            return achievements.filter { !$0.isUnlocked }
        case .nearCompletion:
            return achievements.filter { !$0.isUnlocked && $0.progress / $0.maxProgress > 0.75 }
        }
    }
    
    var body: some View {
        VStack {
            // Filter
            Picker("Filter", selection: $filter) {
                ForEach(AchievementFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(filteredAchievements, id: \.id) { achievement in
                        AchievementCard(achievement: achievement)
                            .onTapGesture {
                                onAchievementTap(achievement)
                            }
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Achievement Card

struct AchievementCard: View {
    let achievement: Achievement
    
    var body: some View {
        VStack(spacing: 8) {
            // Icon
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ? Color.yellow : Color(.systemGray5))
                    .frame(width: 50, height: 50)
                
                Image(systemName: achievement.isUnlocked ? "trophy.fill" : "lock.fill")
                    .foregroundColor(achievement.isUnlocked ? .white : .gray)
                    .font(.title2)
            }
            
            // Title
            Text(achievement.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            // Progress
            if !achievement.isUnlocked {
                ProgressView(value: achievement.progress, total: achievement.maxProgress)
                    .progressViewStyle(.linear)
                    .tint(.blue)
                
                Text("\(Int(achievement.progress)) / \(Int(achievement.maxProgress))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else if let unlockedDate = achievement.unlockedDate {
                Text(unlockedDate, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(achievement.isUnlocked ? Color.yellow : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Achievement Detail View

struct AchievementDetailView: View {
    let achievement: Achievement
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Large icon
                ZStack {
                    Circle()
                        .fill(achievement.isUnlocked ? Color.yellow : Color(.systemGray5))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: achievement.isUnlocked ? "trophy.fill" : "lock.fill")
                        .foregroundColor(achievement.isUnlocked ? .white : .gray)
                        .font(.system(size: 60))
                }
                
                // Title and description
                VStack(spacing: 8) {
                    Text(achievement.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(achievement.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Progress
                if !achievement.isUnlocked {
                    VStack(spacing: 8) {
                        ProgressView(value: achievement.progress, total: achievement.maxProgress)
                            .progressViewStyle(.linear)
                            .scaleEffect(x: 1, y: 2)
                            .tint(.blue)
                        
                        Text("\(Int(achievement.progress)) / \(Int(achievement.maxProgress))")
                            .font(.headline)
                    }
                    .padding()
                }
                
                // Unlock date
                if let unlockedDate = achievement.unlockedDate {
                    Label("Unlocked \(unlockedDate, style: .date)", systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Achievement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Unlocks View

struct UnlocksView: View {
    let unlockedFeatures: Set<String>
    let currentLevel: Int
    
    let allFeatures: [(level: Int, features: [String])] = [
        (2, ["Basic Trade Routes"]),
        (3, ["Bulk Carrier Ships"]),
        (5, ["Container Ships", "Advanced Navigation"]),
        (8, ["Tanker Ships", "Fuel Efficiency Upgrade"]),
        (10, ["Market Analytics", "Crew Management"]),
        (15, ["Trade Route Optimization", "RoRo Ships"]),
        (20, ["Fleet Management", "Automated Trading"]),
        (25, ["AI-Assisted Navigation", "Predictive Maintenance"]),
        (30, ["Global Trade Network", "Market Manipulation"]),
        (35, ["Quantum Logistics", "Hyperloop Integration"]),
        (40, ["Autonomous Fleet Operations", "Supply Chain AI"]),
        (45, ["Singularity Resistance", "Market Dominance"]),
        (50, ["Logistics Mastery", "Infinite Scalability"])
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(allFeatures, id: \.level) { levelData in
                    UnlockRow(
                        level: levelData.level,
                        features: levelData.features,
                        isUnlocked: levelData.level <= currentLevel
                    )
                }
            }
            .padding()
        }
    }
}

struct UnlockRow: View {
    let level: Int
    let features: [String]
    let isUnlocked: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Level badge
            ZStack {
                Circle()
                    .fill(isUnlocked ? Color.blue : Color(.systemGray5))
                    .frame(width: 40, height: 40)
                
                Text("\(level)")
                    .font(.headline)
                    .foregroundColor(isUnlocked ? .white : .gray)
            }
            
            // Features
            VStack(alignment: .leading, spacing: 4) {
                Text("Level \(level)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ForEach(features, id: \.self) { feature in
                    HStack(spacing: 8) {
                        Image(systemName: isUnlocked ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isUnlocked ? .green : .gray)
                            .font(.caption)
                        
                        Text(feature)
                            .font(.subheadline)
                            .foregroundColor(isUnlocked ? .primary : .secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Leaderboards View

struct LeaderboardsView: View {
    @StateObject private var gameCenterManager = GameCenterManager.shared
    @State private var selectedLeaderboard: GameCenterManager.LeaderboardID = .playerLevel
    
    var body: some View {
        VStack {
            // Leaderboard selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(GameCenterManager.LeaderboardID.allCases, id: \.self) { leaderboard in
                        LeaderboardTab(
                            title: leaderboard.displayName,
                            isSelected: selectedLeaderboard == leaderboard
                        )
                        .onTapGesture {
                            selectedLeaderboard = leaderboard
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            
            // Leaderboard content
            if gameCenterManager.isAuthenticated {
                Button(action: {
                    let viewController = gameCenterManager.showLeaderboard(selectedLeaderboard)
                    // Present view controller
                }) {
                    Label("View in Game Center", systemImage: "gamecontroller.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding()
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "gamecontroller")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("Sign in to Game Center to view leaderboards")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    
                    Button("Sign In") {
                        Task {
                            await gameCenterManager.authenticatePlayer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            
            Spacer()
        }
    }
}

struct LeaderboardTab: View {
    let title: String
    let isSelected: Bool
    
    var body: some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(isSelected ? .medium : .regular)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
    }
}

extension GameCenterManager.LeaderboardID {
    var displayName: String {
        switch self {
        case .totalExperience: return "Total XP"
        case .playerLevel: return "Level"
        case .totalProfit: return "Profit"
        case .fleetSize: return "Fleet Size"
        case .tradesCompleted: return "Trades"
        case .singularitySurvival: return "Singularity"
        }
    }
}

// MARK: - Level Up Animation

struct LevelUpAnimationView: View {
    @Binding var isShowing: Bool
    let level: Int
    let rewards: [String]
    
    @State private var scale: CGFloat = 0
    @State private var opacity: Double = 0
    @State private var particleAnimation = false
    
    var body: some View {
        ZStack {
            if isShowing {
                // Background
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isShowing = false
                    }
                
                // Content
                VStack(spacing: 20) {
                    // Level badge
                    ZStack {
                        // Particle effect
                        ForEach(0..<20, id: \.self) { index in
                            Circle()
                                .fill(Color.yellow)
                                .frame(width: 4, height: 4)
                                .offset(particleOffset(for: index))
                                .opacity(particleAnimation ? 0 : 1)
                                .animation(
                                    .easeOut(duration: 1.5)
                                    .delay(Double(index) * 0.05),
                                    value: particleAnimation
                                )
                        }
                        
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                            .overlay(
                                Text("\(level)")
                                    .font(.system(size: 60, weight: .bold))
                                    .foregroundColor(.white)
                            )
                    }
                    .scaleEffect(scale)
                    
                    Text("LEVEL UP!")
                        .font(.largeTitle)
                        .fontWeight(.black)
                        .foregroundColor(.yellow)
                    
                    // Rewards
                    if !rewards.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Rewards:")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            ForEach(rewards, id: \.self) { reward in
                                Text(reward)
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                            }
                        }
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(12)
                    }
                }
                .opacity(opacity)
                .onAppear {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                        scale = 1
                        opacity = 1
                    }
                    
                    withAnimation {
                        particleAnimation = true
                    }
                    
                    // Auto dismiss after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        isShowing = false
                    }
                }
            }
        }
    }
    
    private func particleOffset(for index: Int) -> CGSize {
        let angle = Double(index) / 20.0 * 2 * .pi
        let distance: CGFloat = particleAnimation ? 150 : 0
        
        return CGSize(
            width: cos(angle) * distance,
            height: sin(angle) * distance
        )
    }
}

// MARK: - Preview

struct ProgressionView_Previews: PreviewProvider {
    static var previews: some View {
        ProgressionView()
    }
}