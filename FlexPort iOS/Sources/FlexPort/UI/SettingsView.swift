import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var gameManager: GameManager
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Audio")) {
                    Toggle("Sound Effects", isOn: $soundEnabled)
                }
                
                Section(header: Text("Haptics")) {
                    Toggle("Haptic Feedback", isOn: $hapticEnabled)
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Done") {
                gameManager.navigateTo(.mainMenu)
            })
        }
    }
}