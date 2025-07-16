import SwiftUI

@main
struct FlexPortApp: App {
    @StateObject private var gameManager = GameManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(gameManager)
                .preferredColorScheme(.dark)
                .statusBar(hidden: true)
        }
    }
}