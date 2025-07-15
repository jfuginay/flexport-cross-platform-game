import Foundation
import Combine

// MARK: - Asset Management System
class AssetManagementSystem: ObservableObject {
    @Published var ships: [ManagedShip] = []
    @Published var planes: [ManagedPlane] = []
    @Published var warehouses: [ManagedWarehouse] = []
    @Published var totalAssetValue: Double = 0
    @Published var maintenanceBacklog: [MaintenanceTask] = []
    
    private var cancellables = Set<AnyCancellable>()
    private let depreciationRate = 0.1 // 10% per year
    
    init() {
        setupValueCalculation()
    }
    
    private func setupValueCalculation() {
        Publishers.CombineLatest3($ships, $planes, $warehouses)
            .sink { [weak self] ships, planes, warehouses in
                self?.calculateTotalAssetValue(ships: ships, planes: planes, warehouses: warehouses)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Asset Acquisition
    func purchaseShip(_ ship: ShipModel, financingOption: FinancingOption) -> Result<ManagedShip, AssetError> {
        let totalCost = ship.basePrice * (1 + financingOption.interestRate)
        
        guard validatePurchase(cost: totalCost) else {
            return .failure(.insufficientFunds)
        }
        
        let managedShip = ManagedShip(
            model: ship,
            purchaseDate: Date(),
            purchasePrice: ship.basePrice,
            financingDetails: financingOption,
            currentCondition: 1.0
        )
        
        ships.append(managedShip)
        scheduleMaintenanceTasks(for: managedShip)
        
        return .success(managedShip)
    }
    
    func purchasePlane(_ plane: PlaneModel, financingOption: FinancingOption) -> Result<ManagedPlane, AssetError> {
        let totalCost = plane.basePrice * (1 + financingOption.interestRate)
        
        guard validatePurchase(cost: totalCost) else {
            return .failure(.insufficientFunds)
        }
        
        let managedPlane = ManagedPlane(
            model: plane,
            purchaseDate: Date(),
            purchasePrice: plane.basePrice,
            financingDetails: financingOption,
            currentCondition: 1.0
        )
        
        planes.append(managedPlane)
        scheduleMaintenanceTasks(for: managedPlane)
        
        return .success(managedPlane)
    }
    
    func leaseWarehouse(_ warehouse: WarehouseModel, term: LeaseTerm) -> Result<ManagedWarehouse, AssetError> {
        let managedWarehouse = ManagedWarehouse(
            model: warehouse,
            leaseStartDate: Date(),
            leaseTerm: term,
            monthlyLease: warehouse.monthlyLease,
            currentOccupancy: 0.0
        )
        
        warehouses.append(managedWarehouse)
        
        return .success(managedWarehouse)
    }
    
    // MARK: - Asset Upgrades
    func upgradeAsset<T: ManagedAsset>(_ asset: T, upgrade: AssetUpgrade) -> Result<T, AssetError> {
        guard asset.canApplyUpgrade(upgrade) else {
            return .failure(.incompatibleUpgrade)
        }
        
        guard validatePurchase(cost: upgrade.cost) else {
            return .failure(.insufficientFunds)
        }
        
        asset.applyUpgrade(upgrade)
        
        // Recalculate maintenance schedule
        if let ship = asset as? ManagedShip {
            scheduleMaintenanceTasks(for: ship)
        } else if let plane = asset as? ManagedPlane {
            scheduleMaintenanceTasks(for: plane)
        }
        
        return .success(asset)
    }
    
    // MARK: - Maintenance System
    func performMaintenance(_ task: MaintenanceTask) -> Result<Void, AssetError> {
        guard let index = maintenanceBacklog.firstIndex(where: { $0.id == task.id }) else {
            return .failure(.taskNotFound)
        }
        
        guard validatePurchase(cost: task.estimatedCost) else {
            return .failure(.insufficientFunds)
        }
        
        // Apply maintenance effects
        task.asset.currentCondition = min(1.0, task.asset.currentCondition + task.conditionImprovement)
        task.asset.lastMaintenanceDate = Date()
        
        // Remove from backlog
        maintenanceBacklog.remove(at: index)
        
        // Schedule next maintenance
        scheduleNextMaintenance(for: task.asset)
        
        return .success(())
    }
    
    private func scheduleMaintenanceTasks<T: ManagedAsset>(for asset: T) {
        let baseInterval: TimeInterval = 30 * 24 * 60 * 60 // 30 days
        
        let task = MaintenanceTask(
            id: UUID(),
            asset: asset,
            type: .routine,
            scheduledDate: Date().addingTimeInterval(baseInterval),
            estimatedCost: asset.model.maintenanceCost,
            conditionImprovement: 0.1,
            priority: .medium
        )
        
        maintenanceBacklog.append(task)
    }
    
    private func scheduleNextMaintenance<T: ManagedAsset>(for asset: T) {
        let intervalMultiplier = 1.0 / max(0.1, asset.currentCondition)
        let baseInterval: TimeInterval = 30 * 24 * 60 * 60 * intervalMultiplier
        
        let task = MaintenanceTask(
            id: UUID(),
            asset: asset,
            type: asset.currentCondition < 0.5 ? .critical : .routine,
            scheduledDate: Date().addingTimeInterval(baseInterval),
            estimatedCost: asset.model.maintenanceCost * (asset.currentCondition < 0.5 ? 2.0 : 1.0),
            conditionImprovement: asset.currentCondition < 0.5 ? 0.3 : 0.1,
            priority: asset.currentCondition < 0.5 ? .high : .medium
        )
        
        maintenanceBacklog.append(task)
    }
    
    // MARK: - Asset Disposal
    func sellAsset<T: ManagedAsset>(_ asset: T) -> Double {
        let depreciation = calculateDepreciation(for: asset)
        let conditionFactor = asset.currentCondition
        let marketValue = asset.purchasePrice * (1 - depreciation) * conditionFactor
        
        // Remove from appropriate array
        if let ship = asset as? ManagedShip {
            ships.removeAll { $0.id == ship.id }
        } else if let plane = asset as? ManagedPlane {
            planes.removeAll { $0.id == plane.id }
        }
        
        // Remove associated maintenance tasks
        maintenanceBacklog.removeAll { $0.asset.id == asset.id }
        
        return marketValue
    }
    
    // MARK: - Utilization Tracking
    func updateUtilization<T: ManagedAsset>(_ asset: T, utilization: Double) {
        asset.utilizationHistory.append(
            UtilizationRecord(
                date: Date(),
                utilizationRate: utilization,
                revenue: calculateRevenue(for: asset, utilization: utilization)
            )
        )
        
        // Condition degrades faster with higher utilization
        let degradation = utilization * 0.001
        asset.currentCondition = max(0, asset.currentCondition - degradation)
    }
    
    // MARK: - Analytics
    func getAssetPerformanceMetrics<T: ManagedAsset>(_ asset: T) -> AssetPerformanceMetrics {
        let totalRevenue = asset.utilizationHistory.reduce(0) { $0 + $1.revenue }
        let avgUtilization = asset.utilizationHistory.reduce(0) { $0 + $1.utilizationRate } / Double(max(1, asset.utilizationHistory.count))
        let totalMaintenanceCost = calculateTotalMaintenanceCost(for: asset)
        let roi = (totalRevenue - totalMaintenanceCost - asset.purchasePrice) / asset.purchasePrice
        
        return AssetPerformanceMetrics(
            assetId: asset.id,
            totalRevenue: totalRevenue,
            averageUtilization: avgUtilization,
            totalMaintenanceCost: totalMaintenanceCost,
            currentValue: calculateCurrentValue(for: asset),
            roi: roi,
            conditionTrend: analyzeConditionTrend(for: asset)
        )
    }
    
    // MARK: - Helper Methods
    private func validatePurchase(cost: Double) -> Bool {
        // This would integrate with the financial system
        return true // Placeholder
    }
    
    private func calculateTotalAssetValue(ships: [ManagedShip], planes: [ManagedPlane], warehouses: [ManagedWarehouse]) {
        let shipValue = ships.reduce(0) { $0 + calculateCurrentValue(for: $1) }
        let planeValue = planes.reduce(0) { $0 + calculateCurrentValue(for: $1) }
        let warehouseValue = warehouses.reduce(0) { $0 + $1.model.estimatedValue }
        
        totalAssetValue = shipValue + planeValue + warehouseValue
    }
    
    private func calculateCurrentValue<T: ManagedAsset>(for asset: T) -> Double {
        let depreciation = calculateDepreciation(for: asset)
        return asset.purchasePrice * (1 - depreciation) * asset.currentCondition
    }
    
    private func calculateDepreciation<T: ManagedAsset>(for asset: T) -> Double {
        let age = Date().timeIntervalSince(asset.purchaseDate) / (365 * 24 * 60 * 60)
        return min(0.8, depreciationRate * age)
    }
    
    private func calculateRevenue<T: ManagedAsset>(for asset: T, utilization: Double) -> Double {
        // Simplified revenue calculation
        return asset.model.revenuePerHour * utilization * 24
    }
    
    private func calculateTotalMaintenanceCost<T: ManagedAsset>(for asset: T) -> Double {
        // Calculate historical maintenance costs
        return asset.purchaseDate.timeIntervalSinceNow / (30 * 24 * 60 * 60) * asset.model.maintenanceCost
    }
    
    private func analyzeConditionTrend<T: ManagedAsset>(for asset: T) -> ConditionTrend {
        // Analyze condition degradation rate
        if asset.currentCondition > 0.8 {
            return .excellent
        } else if asset.currentCondition > 0.6 {
            return .good
        } else if asset.currentCondition > 0.4 {
            return .fair
        } else {
            return .poor
        }
    }
}

// MARK: - Asset Models
protocol AssetModel {
    var id: UUID { get }
    var name: String { get }
    var basePrice: Double { get }
    var maintenanceCost: Double { get }
    var revenuePerHour: Double { get }
}

struct ShipModel: AssetModel {
    let id = UUID()
    let name: String
    let basePrice: Double
    let maintenanceCost: Double
    let revenuePerHour: Double
    let capacity: Int
    let speed: Double
    let fuelEfficiency: Double
    let compatibleUpgrades: Set<UpgradeType>
}

struct PlaneModel: AssetModel {
    let id = UUID()
    let name: String
    let basePrice: Double
    let maintenanceCost: Double
    let revenuePerHour: Double
    let cargoCapacity: Int
    let range: Double
    let fuelEfficiency: Double
    let compatibleUpgrades: Set<UpgradeType>
}

struct WarehouseModel: AssetModel {
    let id = UUID()
    let name: String
    let basePrice: Double
    let maintenanceCost: Double
    let revenuePerHour: Double
    let location: Location
    let capacity: Int
    let monthlyLease: Double
    let estimatedValue: Double
}

// MARK: - Managed Assets
protocol ManagedAsset: AnyObject {
    associatedtype Model: AssetModel
    
    var id: UUID { get }
    var model: Model { get }
    var purchaseDate: Date { get }
    var purchasePrice: Double { get }
    var currentCondition: Double { get set }
    var lastMaintenanceDate: Date? { get set }
    var utilizationHistory: [UtilizationRecord] { get set }
    var appliedUpgrades: [AssetUpgrade] { get set }
    
    func canApplyUpgrade(_ upgrade: AssetUpgrade) -> Bool
    func applyUpgrade(_ upgrade: AssetUpgrade)
}

class ManagedShip: ManagedAsset {
    let id = UUID()
    let model: ShipModel
    let purchaseDate: Date
    let purchasePrice: Double
    let financingDetails: FinancingOption
    var currentCondition: Double
    var lastMaintenanceDate: Date?
    var utilizationHistory: [UtilizationRecord] = []
    var appliedUpgrades: [AssetUpgrade] = []
    var currentRoute: TradeRoute?
    
    init(model: ShipModel, purchaseDate: Date, purchasePrice: Double, financingDetails: FinancingOption, currentCondition: Double) {
        self.model = model
        self.purchaseDate = purchaseDate
        self.purchasePrice = purchasePrice
        self.financingDetails = financingDetails
        self.currentCondition = currentCondition
    }
    
    func canApplyUpgrade(_ upgrade: AssetUpgrade) -> Bool {
        return model.compatibleUpgrades.contains(upgrade.type) && !appliedUpgrades.contains(where: { $0.id == upgrade.id })
    }
    
    func applyUpgrade(_ upgrade: AssetUpgrade) {
        appliedUpgrades.append(upgrade)
    }
}

class ManagedPlane: ManagedAsset {
    let id = UUID()
    let model: PlaneModel
    let purchaseDate: Date
    let purchasePrice: Double
    let financingDetails: FinancingOption
    var currentCondition: Double
    var lastMaintenanceDate: Date?
    var utilizationHistory: [UtilizationRecord] = []
    var appliedUpgrades: [AssetUpgrade] = []
    var currentRoute: TradeRoute?
    
    init(model: PlaneModel, purchaseDate: Date, purchasePrice: Double, financingDetails: FinancingOption, currentCondition: Double) {
        self.model = model
        self.purchaseDate = purchaseDate
        self.purchasePrice = purchasePrice
        self.financingDetails = financingDetails
        self.currentCondition = currentCondition
    }
    
    func canApplyUpgrade(_ upgrade: AssetUpgrade) -> Bool {
        return model.compatibleUpgrades.contains(upgrade.type) && !appliedUpgrades.contains(where: { $0.id == upgrade.id })
    }
    
    func applyUpgrade(_ upgrade: AssetUpgrade) {
        appliedUpgrades.append(upgrade)
    }
}

class ManagedWarehouse: ManagedAsset {
    let id = UUID()
    let model: WarehouseModel
    let purchaseDate: Date
    var purchasePrice: Double { model.estimatedValue }
    let leaseStartDate: Date
    let leaseTerm: LeaseTerm
    let monthlyLease: Double
    var currentCondition: Double = 1.0
    var lastMaintenanceDate: Date?
    var utilizationHistory: [UtilizationRecord] = []
    var appliedUpgrades: [AssetUpgrade] = []
    var currentOccupancy: Double
    var storedCargo: [StoredCargo] = []
    
    init(model: WarehouseModel, leaseStartDate: Date, leaseTerm: LeaseTerm, monthlyLease: Double, currentOccupancy: Double) {
        self.model = model
        self.purchaseDate = leaseStartDate
        self.leaseStartDate = leaseStartDate
        self.leaseTerm = leaseTerm
        self.monthlyLease = monthlyLease
        self.currentOccupancy = currentOccupancy
    }
    
    func canApplyUpgrade(_ upgrade: AssetUpgrade) -> Bool {
        return upgrade.type == .warehouseAutomation || upgrade.type == .securitySystem
    }
    
    func applyUpgrade(_ upgrade: AssetUpgrade) {
        appliedUpgrades.append(upgrade)
    }
}

// MARK: - Supporting Types
struct FinancingOption {
    let type: FinancingType
    let interestRate: Double
    let term: Int // months
    let downPayment: Double
}

enum FinancingType {
    case cash
    case loan
    case lease
}

struct LeaseTerm {
    let months: Int
    let earlyTerminationPenalty: Double
}

struct AssetUpgrade {
    let id = UUID()
    let type: UpgradeType
    let name: String
    let cost: Double
    let benefitDescription: String
    let performanceImprovement: PerformanceImprovement
}

enum UpgradeType {
    case engineEfficiency
    case cargoExpansion
    case navigationSystem
    case fuelTank
    case refrigeration
    case warehouseAutomation
    case securitySystem
}

struct PerformanceImprovement {
    let speedIncrease: Double?
    let capacityIncrease: Double?
    let efficiencyIncrease: Double?
    let maintenanceReduction: Double?
}

struct MaintenanceTask {
    let id: UUID
    let asset: any ManagedAsset
    let type: MaintenanceType
    let scheduledDate: Date
    let estimatedCost: Double
    let conditionImprovement: Double
    let priority: Priority
}

enum MaintenanceType {
    case routine
    case preventive
    case critical
    case upgrade
}

enum Priority {
    case low
    case medium
    case high
    case critical
}

struct UtilizationRecord {
    let date: Date
    let utilizationRate: Double
    let revenue: Double
}

struct StoredCargo {
    let cargo: Cargo
    let arrivalDate: Date
    let scheduledDeparture: Date?
    let storageLocation: String
}

struct AssetPerformanceMetrics {
    let assetId: UUID
    let totalRevenue: Double
    let averageUtilization: Double
    let totalMaintenanceCost: Double
    let currentValue: Double
    let roi: Double
    let conditionTrend: ConditionTrend
}

enum ConditionTrend {
    case excellent
    case good
    case fair
    case poor
}

enum AssetError: Error {
    case insufficientFunds
    case incompatibleUpgrade
    case taskNotFound
    case assetNotFound
}