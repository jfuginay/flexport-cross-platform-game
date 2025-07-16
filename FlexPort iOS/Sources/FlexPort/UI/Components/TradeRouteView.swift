import SwiftUI

public struct TradeRouteView: View {
    @EnvironmentObject var gameManager: GameManager
    @State private var selectedRoute: TradeRoute?
    @State private var showingRouteCreator = false
    @State private var showingRouteDetails = false
    
    let sampleRoutes: [TradeRoute] = [
        TradeRoute(
            id: UUID(),
            name: "Asia-Pacific Express",
            origin: Port(name: "Shanghai", coordinates: Coordinates(latitude: 31.2304, longitude: 121.4737)),
            destination: Port(name: "Los Angeles", coordinates: Coordinates(latitude: 33.7490, longitude: -118.2923)),
            distance: 6500,
            estimatedDays: 14,
            profitMargin: 0.18,
            cargo: [
                Cargo(type: "Electronics", quantity: 500, value: 1225000),
                Cargo(type: "Machinery", quantity: 300, value: 960000)
            ],
            isActive: true
        ),
        TradeRoute(
            id: UUID(),
            name: "European Circuit",
            origin: Port(name: "Rotterdam", coordinates: Coordinates(latitude: 51.8985, longitude: 4.4813)),
            destination: Port(name: "Hamburg", coordinates: Coordinates(latitude: 53.5511, longitude: 9.9937)),
            distance: 280,
            estimatedDays: 2,
            profitMargin: 0.12,
            cargo: [
                Cargo(type: "Automotive Parts", quantity: 200, value: 800000)
            ],
            isActive: true
        ),
        TradeRoute(
            id: UUID(),
            name: "Trans-Atlantic",
            origin: Port(name: "New York", coordinates: Coordinates(latitude: 40.7128, longitude: -74.0060)),
            destination: Port(name: "London", coordinates: Coordinates(latitude: 51.5074, longitude: -0.0278)),
            distance: 3500,
            estimatedDays: 8,
            profitMargin: 0.15,
            cargo: [
                Cargo(type: "Textiles", quantity: 400, value: 356000),
                Cargo(type: "Food Products", quantity: 600, value: 660000)
            ],
            isActive: false
        )
    ]
    
    public var body: some View {
        NavigationView {
            VStack {
                // Route Map Overview (simplified)
                ZStack {
                    Rectangle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(height: 300)
                        .cornerRadius(12)
                    
                    VStack {
                        Text("World Trade Routes")
                            .font(.headline)
                            .foregroundColor(.blue)
                        
                        HStack {
                            ForEach(sampleRoutes.indices, id: \.self) { index in
                                VStack {
                                    Circle()
                                        .fill(sampleRoutes[index].isActive ? Color.green : Color.orange)
                                        .frame(width: 12, height: 12)
                                    Text(sampleRoutes[index].origin.name)
                                        .font(.caption2)
                                }
                                
                                if index < sampleRoutes.count - 1 {
                                    Rectangle()
                                        .fill(Color.blue)
                                        .frame(width: 30, height: 2)
                                }
                            }
                        }
                    }
                }
                .padding()
                
                // Route List
                VStack(alignment: .leading) {
                    HStack {
                        Text("Trade Routes")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        VStack(spacing: 8) {
                            Button(action: {
                                showingRouteCreator = true
                            }) {
                                Label("New Route", systemImage: "plus.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button(action: {
                                gameManager.navigateTo(.game)
                            }) {
                                Label("Back", systemImage: "chevron.left")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.horizontal)
                    
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(sampleRoutes) { route in
                                RouteCard(route: route, isSelected: selectedRoute?.id == route.id)
                                    .onTapGesture {
                                        selectedRoute = route
                                        showingRouteDetails = true
                                    }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .background(Color(.systemBackground))
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingRouteCreator) {
                RouteCreatorView()
            }
            .sheet(isPresented: $showingRouteDetails) {
                if let route = selectedRoute {
                    RouteDetailView(route: route)
                }
            }
        }
    }
}

struct TradeRoute: Identifiable {
    let id: UUID
    let name: String
    let origin: Port
    let destination: Port
    let distance: Double // nautical miles
    let estimatedDays: Int
    let profitMargin: Double
    let cargo: [Cargo]
    var isActive: Bool
    var assignedShip: Ship?
    
    var totalValue: Double {
        cargo.reduce(0) { $0 + $1.value }
    }
    
    var estimatedProfit: Double {
        totalValue * profitMargin
    }
}

struct Port: Identifiable {
    let id = UUID()
    let name: String
    let coordinates: Coordinates
}

struct Cargo {
    let type: String
    let quantity: Int
    let value: Double
}


struct RouteCard: View {
    let route: TradeRoute
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(route.name)
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    HStack {
                        Text(route.origin.name)
                        Image(systemName: "arrow.right")
                            .foregroundColor(.blue)
                        Text(route.destination.name)
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    HStack {
                        Circle()
                            .fill(route.isActive ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Text(route.isActive ? "Active" : "Inactive")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("$\(Int(route.estimatedProfit))")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
            
            HStack {
                RouteMetric(icon: "location.circle", label: "\(Int(route.distance)) nm")
                RouteMetric(icon: "clock", label: "\(route.estimatedDays) days")
                RouteMetric(icon: "percent", label: "\(Int(route.profitMargin * 100))%")
                
                Spacer()
                
                if let ship = route.assignedShip {
                    HStack {
                        Image(systemName: "ferry.fill")
                            .foregroundColor(.blue)
                        Text(ship.name)
                            .font(.caption)
                    }
                }
            }
            
            // Cargo summary
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(route.cargo.indices, id: \.self) { index in
                        let cargo = route.cargo[index]
                        CargoTag(cargo: cargo)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
}

struct RouteMetric: View {
    let icon: String
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct CargoTag: View {
    let cargo: Cargo
    
    var body: some View {
        HStack(spacing: 4) {
            Text(cargo.type)
            Text("(\(cargo.quantity))")
                .foregroundColor(.secondary)
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(6)
    }
}

struct RouteDetailView: View {
    let route: TradeRoute
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Route header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(route.name)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        HStack {
                            Text(route.origin.name)
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundColor(.blue)
                            Text(route.destination.name)
                        }
                        .font(.title2)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    
                    // Route metrics
                    GroupBox("Route Information") {
                        VStack(spacing: 12) {
                            MetricRow(label: "Distance", value: "\(Int(route.distance)) nautical miles")
                            MetricRow(label: "Duration", value: "\(route.estimatedDays) days")
                            MetricRow(label: "Profit Margin", value: "\(Int(route.profitMargin * 100))%")
                            MetricRow(label: "Total Value", value: "$\(Int(route.totalValue))")
                            MetricRow(label: "Expected Profit", value: "$\(Int(route.estimatedProfit))")
                        }
                    }
                    .padding(.horizontal)
                    
                    // Cargo details
                    GroupBox("Cargo Manifest") {
                        VStack(spacing: 8) {
                            ForEach(route.cargo.indices, id: \.self) { index in
                                let cargo = route.cargo[index]
                                HStack {
                                    Text(cargo.type)
                                    Spacer()
                                    Text("\(cargo.quantity) units")
                                        .foregroundColor(.secondary)
                                    Text("$\(Int(cargo.value))")
                                        .fontWeight(.medium)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Actions
                    VStack(spacing: 12) {
                        if route.isActive {
                            Button(action: {
                                // Pause route
                            }) {
                                Label("Pause Route", systemImage: "pause.circle.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.orange)
                        } else {
                            Button(action: {
                                // Activate route
                            }) {
                                Label("Activate Route", systemImage: "play.circle.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        
                        Button(action: {
                            // Edit route
                        }) {
                            Label("Edit Route", systemImage: "pencil.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                }
            }
            .navigationTitle("Route Details")
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

struct MetricRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

struct RouteCreatorView: View {
    @Environment(\.dismiss) var dismiss
    @State private var routeName = ""
    @State private var selectedOrigin: String = "Shanghai"
    @State private var selectedDestination: String = "Los Angeles"
    @State private var selectedCargo: [String] = []
    
    let availablePorts = ["Shanghai", "Los Angeles", "Singapore", "Rotterdam", "Hong Kong", "New York", "London", "Hamburg"]
    let availableCargo = ["Electronics", "Machinery", "Textiles", "Food Products", "Automotive Parts", "Chemicals"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Route Information") {
                    TextField("Route Name", text: $routeName)
                    
                    Picker("Origin Port", selection: $selectedOrigin) {
                        ForEach(availablePorts, id: \.self) { port in
                            Text(port).tag(port)
                        }
                    }
                    
                    Picker("Destination Port", selection: $selectedDestination) {
                        ForEach(availablePorts, id: \.self) { port in
                            Text(port).tag(port)
                        }
                    }
                }
                
                Section("Cargo Selection") {
                    ForEach(availableCargo, id: \.self) { cargo in
                        HStack {
                            Text(cargo)
                            Spacer()
                            if selectedCargo.contains(cargo) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.gray)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedCargo.contains(cargo) {
                                selectedCargo.removeAll { $0 == cargo }
                            } else {
                                selectedCargo.append(cargo)
                            }
                        }
                    }
                }
                
                Section {
                    Button("Create Route") {
                        // Create new route
                        dismiss()
                    }
                    .disabled(routeName.isEmpty || selectedOrigin == selectedDestination || selectedCargo.isEmpty)
                }
            }
            .navigationTitle("New Trade Route")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}