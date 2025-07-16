import SwiftUI

public struct ResearchTreeView: View {
    @EnvironmentObject var gameManager: GameManager
    @State private var selectedResearch: ResearchNode?
    @State private var showingResearchDetails = false
    @State private var scrollOffset = CGSize.zero
    
    let researchNodes: [ResearchNode] = [
        // Logistics Branch
        ResearchNode(
            id: "container_optimization",
            name: "Container Optimization",
            description: "Improve container loading efficiency by 15%",
            cost: 50000,
            duration: 7,
            position: CGPoint(x: 100, y: 200),
            prerequisites: [],
            category: .logistics,
            isUnlocked: true
        ),
        ResearchNode(
            id: "route_planning",
            name: "Advanced Route Planning",
            description: "AI-assisted route optimization",
            cost: 75000,
            duration: 10,
            position: CGPoint(x: 250, y: 200),
            prerequisites: ["container_optimization"],
            category: .logistics
        ),
        ResearchNode(
            id: "predictive_maintenance",
            name: "Predictive Maintenance",
            description: "Reduce maintenance costs by 20%",
            cost: 100000,
            duration: 14,
            position: CGPoint(x: 400, y: 200),
            prerequisites: ["route_planning"],
            category: .logistics
        ),
        
        // Technology Branch
        ResearchNode(
            id: "automation_basic",
            name: "Basic Automation",
            description: "Automate simple warehouse operations",
            cost: 80000,
            duration: 12,
            position: CGPoint(x: 100, y: 350),
            prerequisites: [],
            category: .technology,
            isUnlocked: true
        ),
        ResearchNode(
            id: "ai_trading",
            name: "AI Trading Algorithms",
            description: "Automated market analysis and trading",
            cost: 150000,
            duration: 21,
            position: CGPoint(x: 250, y: 350),
            prerequisites: ["automation_basic"],
            category: .technology
        ),
        ResearchNode(
            id: "quantum_computing",
            name: "Quantum Computing",
            description: "Revolutionary computing power for optimization",
            cost: 500000,
            duration: 60,
            position: CGPoint(x: 400, y: 350),
            prerequisites: ["ai_trading"],
            category: .technology
        ),
        
        // Sustainability Branch
        ResearchNode(
            id: "green_fuel",
            name: "Green Fuel Technology",
            description: "Reduce emissions and fuel costs",
            cost: 120000,
            duration: 18,
            position: CGPoint(x: 100, y: 500),
            prerequisites: [],
            category: .sustainability,
            isUnlocked: true
        ),
        ResearchNode(
            id: "carbon_neutral",
            name: "Carbon Neutral Operations",
            description: "Achieve net-zero emissions",
            cost: 200000,
            duration: 30,
            position: CGPoint(x: 250, y: 500),
            prerequisites: ["green_fuel"],
            category: .sustainability
        ),
        
        // Economics Branch
        ResearchNode(
            id: "market_analysis",
            name: "Advanced Market Analysis",
            description: "Better prediction of commodity prices",
            cost: 60000,
            duration: 8,
            position: CGPoint(x: 100, y: 650),
            prerequisites: [],
            category: .economics,
            isUnlocked: true
        ),
        ResearchNode(
            id: "dynamic_pricing",
            name: "Dynamic Pricing",
            description: "Real-time pricing optimization",
            cost: 90000,
            duration: 12,
            position: CGPoint(x: 250, y: 650),
            prerequisites: ["market_analysis"],
            category: .economics
        )
    ]
    
    public var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    ZStack {
                        // Background grid
                        Canvas { context, size in
                            let gridSize: CGFloat = 50
                            context.stroke(
                                Path { path in
                                    for x in stride(from: 0, to: size.width, by: gridSize) {
                                        path.move(to: CGPoint(x: x, y: 0))
                                        path.addLine(to: CGPoint(x: x, y: size.height))
                                    }
                                    for y in stride(from: 0, to: size.height, by: gridSize) {
                                        path.move(to: CGPoint(x: 0, y: y))
                                        path.addLine(to: CGPoint(x: size.width, y: y))
                                    }
                                },
                                with: .color(.gray.opacity(0.1)),
                                lineWidth: 1
                            )
                        }
                        .frame(width: 800, height: 800)
                        
                        // Connection lines
                        ForEach(researchNodes, id: \.id) { node in
                            ForEach(node.prerequisites, id: \.self) { prerequisiteId in
                                if let prerequisite = researchNodes.first(where: { $0.id == prerequisiteId }) {
                                    ConnectionLine(from: prerequisite.position, to: node.position, isUnlocked: node.isUnlocked)
                                }
                            }
                        }
                        
                        // Research nodes
                        ForEach(researchNodes, id: \.id) { node in
                            ResearchNodeView(node: node)
                                .position(node.position)
                                .onTapGesture {
                                    selectedResearch = node
                                    showingResearchDetails = true
                                }
                        }
                    }
                    .frame(width: 800, height: 800)
                }
                .scrollPosition(id: "research_tree", anchor: .center)
            }
            .navigationTitle("Research Tree")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        gameManager.navigateTo(.game)
                    }) {
                        Label("Back", systemImage: "chevron.left")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Logistics") { /* Filter by logistics */ }
                        Button("Technology") { /* Filter by technology */ }
                        Button("Sustainability") { /* Filter by sustainability */ }
                        Button("Economics") { /* Filter by economics */ }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showingResearchDetails) {
                if let research = selectedResearch {
                    ResearchDetailView(research: research)
                }
            }
        }
    }
}

struct ResearchNode: Identifiable {
    let id: String
    let name: String
    let description: String
    let cost: Double
    let duration: Int // days
    let position: CGPoint
    let prerequisites: [String]
    let category: ResearchCategory
    var isUnlocked: Bool = false
    var isResearched: Bool = false
    var isInProgress: Bool = false
    var progress: Double = 0.0
}

enum ResearchCategory {
    case logistics
    case technology
    case sustainability
    case economics
    
    var color: Color {
        switch self {
        case .logistics: return .blue
        case .technology: return .purple
        case .sustainability: return .green
        case .economics: return .orange
        }
    }
    
    var icon: String {
        switch self {
        case .logistics: return "shippingbox.fill"
        case .technology: return "cpu.fill"
        case .sustainability: return "leaf.fill"
        case .economics: return "chart.line.uptrend.xyaxis"
        }
    }
}

struct ResearchNodeView: View {
    let node: ResearchNode
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(backgroundGradient)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .stroke(borderColor, lineWidth: 3)
                    )
                
                Image(systemName: node.category.icon)
                    .font(.title2)
                    .foregroundColor(iconColor)
                
                if node.isInProgress {
                    Circle()
                        .trim(from: 0, to: node.progress)
                        .stroke(Color.yellow, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 65, height: 65)
                        .rotationEffect(.degrees(-90))
                }
            }
            
            Text(node.name)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .frame(width: 80)
                .foregroundColor(textColor)
        }
    }
    
    private var backgroundGradient: LinearGradient {
        if node.isResearched {
            return LinearGradient(
                colors: [node.category.color.opacity(0.8), node.category.color.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if node.isUnlocked {
            return LinearGradient(
                colors: [node.category.color.opacity(0.3), node.category.color.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var borderColor: Color {
        if node.isResearched {
            return node.category.color
        } else if node.isUnlocked {
            return node.category.color.opacity(0.6)
        } else {
            return Color.gray.opacity(0.5)
        }
    }
    
    private var iconColor: Color {
        if node.isResearched {
            return .white
        } else if node.isUnlocked {
            return node.category.color
        } else {
            return .gray
        }
    }
    
    private var textColor: Color {
        node.isUnlocked ? .primary : .secondary
    }
}

struct ConnectionLine: View {
    let from: CGPoint
    let to: CGPoint
    let isUnlocked: Bool
    
    var body: some View {
        Path { path in
            path.move(to: from)
            path.addLine(to: to)
        }
        .stroke(
            isUnlocked ? Color.blue.opacity(0.6) : Color.gray.opacity(0.3),
            style: StrokeStyle(lineWidth: 2, dash: isUnlocked ? [] : [5, 5])
        )
    }
}

struct ResearchDetailView: View {
    let research: ResearchNode
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var gameManager: GameManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack {
                        ZStack {
                            Circle()
                                .fill(research.category.color.opacity(0.2))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: research.category.icon)
                                .font(.largeTitle)
                                .foregroundColor(research.category.color)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(research.name)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text(research.category.description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    
                    // Description
                    GroupBox("Description") {
                        Text(research.description)
                            .font(.body)
                    }
                    .padding(.horizontal)
                    
                    // Requirements
                    GroupBox("Requirements") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "dollarsign.circle.fill")
                                    .foregroundColor(.green)
                                Text("Cost: $\(Int(research.cost))")
                            }
                            
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(.blue)
                                Text("Duration: \(research.duration) days")
                            }
                            
                            if !research.prerequisites.isEmpty {
                                HStack {
                                    Image(systemName: "link")
                                        .foregroundColor(.orange)
                                    Text("Prerequisites: \(research.prerequisites.joined(separator: ", "))")
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Benefits
                    GroupBox("Benefits") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("• Unlock advanced capabilities")
                            Text("• Improve operational efficiency")
                            Text("• Gain competitive advantage")
                            Text("• Access to new technologies")
                        }
                    }
                    .padding(.horizontal)
                    
                    // Action Button
                    VStack(spacing: 12) {
                        if research.isResearched {
                            Label("Research Completed", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.headline)
                        } else if research.isInProgress {
                            VStack {
                                ProgressView(value: research.progress)
                                    .progressViewStyle(LinearProgressViewStyle())
                                Text("Research in progress: \(Int(research.progress * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else if research.isUnlocked {
                            Button(action: {
                                // Start research
                            }) {
                                Label("Start Research", systemImage: "play.circle.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(gameManager.gameState.playerAssets.money < research.cost)
                        } else {
                            Label("Prerequisites Required", systemImage: "lock.fill")
                                .foregroundColor(.secondary)
                                .font(.headline)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Research Details")
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

extension ResearchCategory {
    var description: String {
        switch self {
        case .logistics: return "Operational Efficiency"
        case .technology: return "Advanced Computing"
        case .sustainability: return "Environmental Impact"
        case .economics: return "Market Intelligence"
        }
    }
}