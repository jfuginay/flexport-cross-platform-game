import SwiftUI

public enum GameScreen {
    case mainMenu
    case game
    case settings
    case financialDashboard
    case fleetManagement
    case researchTree
    case tradeRoutes
}

struct ContentView: View {
    @EnvironmentObject var gameManager: GameManager
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            switch gameManager.currentScreen {
            case .mainMenu:
                MainMenuView()
            case .game:
                GameView()
            case .settings:
                SettingsView()
            case .financialDashboard:
                // FinancialDashboardView()
                FinancialDashboardPlaceholder()
            case .fleetManagement:
                // FleetManagementView()
                FleetManagementPlaceholder()
            case .researchTree:
                // ResearchTreeView()
                ResearchTreePlaceholder()
            case .tradeRoutes:
                // TradeRouteView()
                TradeRoutePlaceholder()
            }
        }
    }
}

// MARK: - Temporary Placeholder Views

struct FinancialDashboardPlaceholder: View {
    @EnvironmentObject var gameManager: GameManager
    
    var body: some View {
        VStack {
            Text("Financial Dashboard")
                .font(.largeTitle)
                .padding()
            
            Text("Financial overview coming soon!")
                .foregroundColor(.gray)
            
            Spacer()
            
            Button("Back to Game") {
                gameManager.navigateTo(.game)
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
    }
}

struct FleetManagementPlaceholder: View {
    @EnvironmentObject var gameManager: GameManager
    
    var body: some View {
        VStack {
            Text("Fleet Management")
                .font(.largeTitle)
                .padding()
            
            Text("Fleet management coming soon!")
                .foregroundColor(.gray)
            
            Spacer()
            
            Button("Back to Game") {
                gameManager.navigateTo(.game)
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
    }
}

struct ResearchTreePlaceholder: View {
    @EnvironmentObject var gameManager: GameManager
    
    var body: some View {
        VStack {
            Text("Research Tree")
                .font(.largeTitle)
                .padding()
            
            Text("Research tree coming soon!")
                .foregroundColor(.gray)
            
            Spacer()
            
            Button("Back to Game") {
                gameManager.navigateTo(.game)
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
    }
}

struct TradeRoutePlaceholder: View {
    @EnvironmentObject var gameManager: GameManager
    
    var body: some View {
        VStack {
            Text("Trade Routes")
                .font(.largeTitle)
                .padding()
            
            Text("Trade routes coming soon!")
                .foregroundColor(.gray)
            
            Spacer()
            
            Button("Back to Game") {
                gameManager.navigateTo(.game)
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
    }
}

