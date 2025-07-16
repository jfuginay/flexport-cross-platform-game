import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject var gameManager: GameManager
    
    var body: some View {
        VStack(spacing: 30) {
            Text("FLEXPORT")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text("The Video Game")
                .font(.system(size: 24, weight: .light))
                .foregroundColor(.gray)
            
            Spacer()
            
            VStack(spacing: 20) {
                Button(action: {
                    gameManager.startNewGame()
                }) {
                    Text("New Game")
                        .frame(width: 200, height: 50)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .font(.headline)
                }
                
                Button(action: {
                    // Continue game logic
                }) {
                    Text("Continue")
                        .frame(width: 200, height: 50)
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .font(.headline)
                }
                
                Button(action: {
                    gameManager.navigateTo(.settings)
                }) {
                    Text("Settings")
                        .frame(width: 200, height: 50)
                        .background(Color.gray.opacity(0.5))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .font(.headline)
                }
            }
            
            Spacer()
        }
        .padding()
    }
}