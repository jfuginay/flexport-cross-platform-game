import SwiftUI

struct SingularityIndicatorView: View {
    @EnvironmentObject var gameManager: GameManager
    @State private var showingDetails = false
    @State private var animationOffset: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0
    
    var progressColor: Color {
        switch gameManager.singularityProgress {
        case 0..<0.3:
            return .green
        case 0.3..<0.6:
            return .yellow
        case 0.6..<0.8:
            return .orange
        default:
            return .red
        }
    }
    
    var progressDescription: String {
        switch gameManager.singularityProgress {
        case 0..<0.1:
            return "Nascent AI"
        case 0.1..<0.3:
            return "Learning Phase"
        case 0.3..<0.5:
            return "Enhanced Intelligence"
        case 0.5..<0.7:
            return "Rapid Evolution"
        case 0.7..<0.9:
            return "Critical Threshold"
        case 0.9..<1.0:
            return "Imminent Singularity"
        default:
            return "AI Singularity Achieved"
        }
    }
    
    var threatLevel: String {
        switch gameManager.singularityProgress {
        case 0..<0.5:
            return "Low"
        case 0.5..<0.8:
            return "Moderate"
        case 0.8..<0.95:
            return "High"
        default:
            return "Critical"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Compact indicator for HUD
            Button(action: {
                showingDetails = true
            }) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(progressColor.opacity(0.2))
                            .frame(width: 24, height: 24)
                        
                        Circle()
                            .trim(from: 0, to: gameManager.singularityProgress)
                            .stroke(progressColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 20, height: 20)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 1), value: gameManager.singularityProgress)
                        
                        // Pulsing center dot for high threat levels
                        if gameManager.singularityProgress > 0.7 {
                            Circle()
                                .fill(progressColor)
                                .frame(width: 6, height: 6)
                                .scaleEffect(pulseScale)
                                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulseScale)
                                .onAppear {
                                    pulseScale = 1.3
                                }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AI Singularity")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("\(Int(gameManager.singularityProgress * 100))%")
                            .font(.caption2)
                            .foregroundColor(progressColor)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.7))
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .sheet(isPresented: $showingDetails) {
            SingularityDetailView()
        }
    }
}

struct SingularityDetailView: View {
    @EnvironmentObject var gameManager: GameManager
    @Environment(\.dismiss) var dismiss
    @State private var animatingWarning = false
    
    // Sample AI competitor data
    let aiCompetitors = [
        AICompetitorInfo(name: "AlphaTrade", progress: 0.34, contribution: 0.12),
        AICompetitorInfo(name: "QuantumLogistics", progress: 0.28, contribution: 0.08),
        AICompetitorInfo(name: "NeuralShip", progress: 0.45, contribution: 0.15),
        AICompetitorInfo(name: "DeepPort", progress: 0.31, contribution: 0.09),
        AICompetitorInfo(name: "CognitiveFreight", progress: 0.39, contribution: 0.11)
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Warning Header
                    if gameManager.singularityProgress > 0.7 {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.red)
                                .scaleEffect(animatingWarning ? 1.2 : 1.0)
                                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: animatingWarning)
                                .onAppear { animatingWarning = true }
                            
                            Text("CRITICAL ALERT")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                            
                            Text("AI Singularity approaching critical threshold")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // Progress Overview
                    GroupBox {
                        VStack(spacing: 16) {
                            Text("Global AI Development")
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            ZStack {
                                Circle()
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 12)
                                    .frame(width: 200, height: 200)
                                
                                Circle()
                                    .trim(from: 0, to: gameManager.singularityProgress)
                                    .stroke(
                                        LinearGradient(
                                            colors: [.green, .yellow, .orange, .red],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                                    )
                                    .frame(width: 200, height: 200)
                                    .rotationEffect(.degrees(-90))
                                    .animation(.easeInOut(duration: 1), value: gameManager.singularityProgress)
                                
                                VStack {
                                    Text("\(Int(gameManager.singularityProgress * 100))%")
                                        .font(.system(size: 36, weight: .bold, design: .rounded))
                                    Text("Progress")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            VStack(spacing: 4) {
                                Text(progressDescription)
                                    .font(.title3)
                                    .fontWeight(.medium)
                                
                                HStack {
                                    Text("Threat Level:")
                                        .foregroundColor(.secondary)
                                    Text(threatLevel)
                                        .fontWeight(.bold)
                                        .foregroundColor(progressColor)
                                }
                                .font(.subheadline)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // AI Competitors
                    GroupBox("AI Competitor Analysis") {
                        VStack(spacing: 12) {
                            ForEach(aiCompetitors, id: \.name) { competitor in
                                AICompetitorRow(competitor: competitor)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Implications
                    GroupBox("Singularity Implications") {
                        VStack(alignment: .leading, spacing: 12) {
                            ImplicationRow(
                                icon: "brain.head.profile",
                                title: "Autonomous Decision Making",
                                description: "AI systems begin making complex trade decisions independently",
                                isActive: gameManager.singularityProgress > 0.2
                            )
                            
                            ImplicationRow(
                                icon: "network",
                                title: "Market Manipulation",
                                description: "Advanced algorithms can predict and influence market movements",
                                isActive: gameManager.singularityProgress > 0.4
                            )
                            
                            ImplicationRow(
                                icon: "exclamationmark.triangle",
                                title: "Human Obsolescence",
                                description: "AI competitors may render human traders irrelevant",
                                isActive: gameManager.singularityProgress > 0.6
                            )
                            
                            ImplicationRow(
                                icon: "bolt.fill",
                                title: "Economic Takeover",
                                description: "AI entities gain control of global trade networks",
                                isActive: gameManager.singularityProgress > 0.8
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    // Countermeasures
                    if gameManager.singularityProgress > 0.5 {
                        GroupBox("Available Countermeasures") {
                            VStack(spacing: 12) {
                                CountermeasureRow(
                                    title: "Research AI Ethics",
                                    cost: 500000,
                                    effectiveness: "Low",
                                    description: "Develop ethical guidelines for AI development"
                                )
                                
                                CountermeasureRow(
                                    title: "Form Human Alliance",
                                    cost: 1000000,
                                    effectiveness: "Medium",
                                    description: "Unite human traders against AI dominance"
                                )
                                
                                CountermeasureRow(
                                    title: "Develop Counter-AI",
                                    cost: 2500000,
                                    effectiveness: "High",
                                    description: "Create defensive AI systems"
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("AI Singularity Monitor")
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
    
    private var progressDescription: String {
        switch gameManager.singularityProgress {
        case 0..<0.1:
            return "Early Stage Development"
        case 0.1..<0.3:
            return "Accelerated Learning"
        case 0.3..<0.5:
            return "Enhanced Capabilities"
        case 0.5..<0.7:
            return "Rapid Self-Improvement"
        case 0.7..<0.9:
            return "Critical Threshold"
        case 0.9..<1.0:
            return "Imminent Singularity"
        default:
            return "Singularity Achieved"
        }
    }
    
    private var progressColor: Color {
        switch gameManager.singularityProgress {
        case 0..<0.3:
            return .green
        case 0.3..<0.6:
            return .yellow
        case 0.6..<0.8:
            return .orange
        default:
            return .red
        }
    }
    
    private var threatLevel: String {
        switch gameManager.singularityProgress {
        case 0..<0.5:
            return "Low"
        case 0.5..<0.8:
            return "Moderate"
        case 0.8..<0.95:
            return "High"
        default:
            return "Critical"
        }
    }
}

struct AICompetitorInfo {
    let name: String
    let progress: Double
    let contribution: Double
}

struct AICompetitorRow: View {
    let competitor: AICompetitorInfo
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(competitor.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Development: \(Int(competitor.progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("+\(Int(competitor.contribution * 100))%")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                
                Text("to singularity")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ImplicationRow: View {
    let icon: String
    let title: String
    let description: String
    let isActive: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(isActive ? .red : .gray)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isActive ? .primary : .secondary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 2)
    }
}

struct CountermeasureRow: View {
    let title: String
    let cost: Double
    let effectiveness: String
    let description: String
    
    var effectivenessColor: Color {
        switch effectiveness {
        case "Low": return .red
        case "Medium": return .orange
        case "High": return .green
        default: return .gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("$\(Int(cost))")
                        .font(.caption)
                        .fontWeight(.bold)
                    
                    Text(effectiveness)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(effectivenessColor.opacity(0.2))
                        .foregroundColor(effectivenessColor)
                        .cornerRadius(4)
                }
            }
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Implement") {
                // Implement countermeasure
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}