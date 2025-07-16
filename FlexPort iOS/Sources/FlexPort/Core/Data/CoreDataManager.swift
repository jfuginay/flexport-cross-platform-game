import Foundation
import CoreData
import Combine

/// Core Data manager for game state persistence
public class CoreDataManager: ObservableObject {
    public static let shared = CoreDataManager()
    
    @Published public var isLoading = false
    @Published public var lastSaveDate: Date?
    @Published public var savedGameSlots: [SaveGameSlot] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Core Data Stack
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "FlexPortDataModel")
        container.loadPersistentStores { _, error in
            if let error = error {
                print("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()
    
    public var context: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    private init() {
        loadSavedGameSlots()
    }
    
    // MARK: - Save Operations
    
    /// Save complete game state
    public func saveGame(gameState: GameState, slotName: String, completion: @escaping (Result<SaveGameSlot, Error>) -> Void) {
        isLoading = true
        
        let backgroundContext = persistentContainer.newBackgroundContext()
        backgroundContext.perform {
            do {
                // Create or update save game slot
                let saveSlot = SavedGame(context: backgroundContext)
                saveSlot.id = UUID()
                saveSlot.name = slotName
                saveSlot.createdAt = Date()
                saveSlot.gameVersion = "1.0.0"
                saveSlot.turn = Int32(gameState.turn)
                saveSlot.singularityProgress = gameState.singularityProgress
                
                // Save player assets
                saveSlot.playerAssets = try self.encodePlayerAssets(gameState.playerAssets, context: backgroundContext)
                
                // Save economic state
                saveSlot.economicState = try self.encodeEconomicState(gameState.markets, context: backgroundContext)
                
                // Save AI competitors
                saveSlot.aiCompetitors = try self.encodeAICompetitors(gameState.aiCompetitors, context: backgroundContext)
                
                // Save world state
                saveSlot.worldState = try self.encodeWorldState(context: backgroundContext)
                
                try backgroundContext.save()
                
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.lastSaveDate = Date()
                    self.loadSavedGameSlots()
                    
                    let slot = SaveGameSlot(
                        id: saveSlot.id!,
                        name: slotName,
                        createdAt: saveSlot.createdAt!,
                        turn: Int(saveSlot.turn),
                        singularityProgress: saveSlot.singularityProgress
                    )
                    completion(.success(slot))
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Auto-save game state
    public func autoSave(gameState: GameState) {
        saveGame(gameState: gameState, slotName: "AutoSave") { result in
            switch result {
            case .success:
                print("Auto-save completed successfully")
            case .failure(let error):
                print("Auto-save failed: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Load Operations
    
    /// Load game state from save slot
    public func loadGame(slotId: UUID, completion: @escaping (Result<GameState, Error>) -> Void) {
        isLoading = true
        
        let backgroundContext = persistentContainer.newBackgroundContext()
        backgroundContext.perform {
            do {
                let request: NSFetchRequest<SavedGame> = SavedGame.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", slotId as CVarArg)
                
                guard let savedGame = try backgroundContext.fetch(request).first else {
                    throw CoreDataError.saveNotFound
                }
                
                // Decode game state components
                let playerAssets = try self.decodePlayerAssets(savedGame.playerAssets)
                let markets = try self.decodeEconomicState(savedGame.economicState)
                let aiCompetitors = try self.decodeAICompetitors(savedGame.aiCompetitors)
                
                let gameState = GameState(
                    playerAssets: playerAssets,
                    markets: markets,
                    aiCompetitors: aiCompetitors,
                    turn: Int(savedGame.turn),
                    singularityProgress: savedGame.singularityProgress
                )
                
                DispatchQueue.main.async {
                    self.isLoading = false
                    completion(.success(gameState))
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Delete save game slot
    public func deleteSave(slotId: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        let backgroundContext = persistentContainer.newBackgroundContext()
        backgroundContext.perform {
            do {
                let request: NSFetchRequest<SavedGame> = SavedGame.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", slotId as CVarArg)
                
                if let savedGame = try backgroundContext.fetch(request).first {
                    backgroundContext.delete(savedGame)
                    try backgroundContext.save()
                }
                
                DispatchQueue.main.async {
                    self.loadSavedGameSlots()
                    completion(.success(()))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Save Slot Management
    
    private func loadSavedGameSlots() {
        let request: NSFetchRequest<SavedGame> = SavedGame.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SavedGame.createdAt, ascending: false)]
        
        do {
            let savedGames = try context.fetch(request)
            savedGameSlots = savedGames.compactMap { savedGame in
                guard let id = savedGame.id,
                      let name = savedGame.name,
                      let createdAt = savedGame.createdAt else {
                    return nil
                }
                
                return SaveGameSlot(
                    id: id,
                    name: name,
                    createdAt: createdAt,
                    turn: Int(savedGame.turn),
                    singularityProgress: savedGame.singularityProgress
                )
            }
        } catch {
            print("Failed to load saved game slots: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Encoding Methods
    
    private func encodePlayerAssets(_ assets: PlayerAssets, context: NSManagedObjectContext) throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(assets)
    }
    
    private func encodeEconomicState(_ markets: Markets, context: NSManagedObjectContext) throws -> Data {
        let economicState = SerializableEconomicState(
            goodsMarket: markets.goodsMarket,
            capitalMarket: markets.capitalMarket,
            assetMarket: markets.assetMarket,
            laborMarket: markets.laborMarket
        )
        let encoder = JSONEncoder()
        return try encoder.encode(economicState)
    }
    
    private func encodeAICompetitors(_ competitors: [AICompetitor], context: NSManagedObjectContext) throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(competitors)
    }
    
    private func encodeWorldState(context: NSManagedObjectContext) throws -> Data {
        // Encode world-specific data like trade routes, market conditions, etc.
        let worldState = SerializableWorldState(
            globalEvents: [],
            weatherPatterns: [],
            tradeRoutes: []
        )
        let encoder = JSONEncoder()
        return try encoder.encode(worldState)
    }
    
    // MARK: - Decoding Methods
    
    private func decodePlayerAssets(_ data: Data?) throws -> PlayerAssets {
        guard let data = data else {
            throw CoreDataError.invalidData
        }
        let decoder = JSONDecoder()
        return try decoder.decode(PlayerAssets.self, from: data)
    }
    
    private func decodeEconomicState(_ data: Data?) throws -> Markets {
        guard let data = data else {
            throw CoreDataError.invalidData
        }
        let decoder = JSONDecoder()
        let economicState = try decoder.decode(SerializableEconomicState.self, from: data)
        
        return Markets(
            goodsMarket: economicState.goodsMarket,
            capitalMarket: economicState.capitalMarket,
            assetMarket: economicState.assetMarket,
            laborMarket: economicState.laborMarket
        )
    }
    
    private func decodeAICompetitors(_ data: Data?) throws -> [AICompetitor] {
        guard let data = data else {
            throw CoreDataError.invalidData
        }
        let decoder = JSONDecoder()
        return try decoder.decode([AICompetitor].self, from: data)
    }
    
    // MARK: - Utility Methods
    
    public func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
                lastSaveDate = Date()
            } catch {
                print("Failed to save context: \(error.localizedDescription)")
            }
        }
    }
    
    public func deleteAllData() {
        let entities = persistentContainer.managedObjectModel.entities
        
        for entity in entities {
            guard let entityName = entity.name else { continue }
            
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            
            do {
                try context.execute(deleteRequest)
            } catch {
                print("Failed to delete \(entityName): \(error.localizedDescription)")
            }
        }
        
        saveContext()
        loadSavedGameSlots()
    }
    
    /// Export save game to file
    public func exportSave(slotId: UUID, completion: @escaping (Result<URL, Error>) -> Void) {
        loadGame(slotId: slotId) { result in
            switch result {
            case .success(let gameState):
                do {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = .prettyPrinted
                    let data = try encoder.encode(gameState)
                    
                    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                    let fileName = "FlexPort_Save_\(Date().timeIntervalSince1970).json"
                    let fileURL = documentsPath.appendingPathComponent(fileName)
                    
                    try data.write(to: fileURL)
                    completion(.success(fileURL))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Import save game from file
    public func importSave(from url: URL, completion: @escaping (Result<SaveGameSlot, Error>) -> Void) {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let gameState = try decoder.decode(GameState.self, from: data)
            
            let fileName = url.deletingPathExtension().lastPathComponent
            saveGame(gameState: gameState, slotName: "Imported: \(fileName)", completion: completion)
        } catch {
            completion(.failure(error))
        }
    }
}

// MARK: - Supporting Types

public struct SaveGameSlot: Identifiable {
    public let id: UUID
    public let name: String
    public let createdAt: Date
    public let turn: Int
    public let singularityProgress: Double
    
    public var formattedDate: String {
        DateFormatter.saveSlotFormatter.string(from: createdAt)
    }
}

private extension DateFormatter {
    static let saveSlotFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

public enum CoreDataError: LocalizedError {
    case saveNotFound
    case invalidData
    case encodingFailed
    case decodingFailed
    
    public var errorDescription: String? {
        switch self {
        case .saveNotFound:
            return "Save game not found"
        case .invalidData:
            return "Invalid save data"
        case .encodingFailed:
            return "Failed to encode game data"
        case .decodingFailed:
            return "Failed to decode game data"
        }
    }
}

// MARK: - Serializable Models

private struct SerializableEconomicState: Codable {
    let goodsMarket: GoodsMarket
    let capitalMarket: CapitalMarket
    let assetMarket: AssetMarket
    let laborMarket: LaborMarket
}

private struct SerializableWorldState: Codable {
    let globalEvents: [String] // Simplified for now
    let weatherPatterns: [String]
    let tradeRoutes: [String]
}

// MARK: - GameState Extension for Codability

extension GameState: Codable {
    enum CodingKeys: String, CodingKey {
        case playerAssets
        case markets
        case aiCompetitors
        case turn
        case singularityProgress
        case isGameActive
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        playerAssets = try container.decode(PlayerAssets.self, forKey: .playerAssets)
        markets = try container.decode(Markets.self, forKey: .markets)
        aiCompetitors = try container.decode([AICompetitor].self, forKey: .aiCompetitors)
        turn = try container.decode(Int.self, forKey: .turn)
        singularityProgress = try container.decodeIfPresent(Double.self, forKey: .singularityProgress) ?? 0.0
        isGameActive = try container.decodeIfPresent(Bool.self, forKey: .isGameActive) ?? true
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(playerAssets, forKey: .playerAssets)
        try container.encode(markets, forKey: .markets)
        try container.encode(aiCompetitors, forKey: .aiCompetitors)
        try container.encode(turn, forKey: .turn)
        try container.encode(singularityProgress, forKey: .singularityProgress)
        try container.encode(isGameActive, forKey: .isGameActive)
    }
    
    public init(playerAssets: PlayerAssets, markets: Markets, aiCompetitors: [AICompetitor], turn: Int, singularityProgress: Double) {
        self.playerAssets = playerAssets
        self.markets = markets
        self.aiCompetitors = aiCompetitors
        self.turn = turn
        self.singularityProgress = singularityProgress
        self.isGameActive = true
    }
}

// MARK: - Markets Extension for Codability

extension Markets: Codable {
    enum CodingKeys: String, CodingKey {
        case goodsMarket
        case capitalMarket
        case assetMarket
        case laborMarket
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        goodsMarket = try container.decode(GoodsMarket.self, forKey: .goodsMarket)
        capitalMarket = try container.decode(CapitalMarket.self, forKey: .capitalMarket)
        assetMarket = try container.decode(AssetMarket.self, forKey: .assetMarket)
        laborMarket = try container.decode(LaborMarket.self, forKey: .laborMarket)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(goodsMarket, forKey: .goodsMarket)
        try container.encode(capitalMarket, forKey: .capitalMarket)
        try container.encode(assetMarket, forKey: .assetMarket)
        try container.encode(laborMarket, forKey: .laborMarket)
    }
    
    public init(goodsMarket: GoodsMarket, capitalMarket: CapitalMarket, assetMarket: AssetMarket, laborMarket: LaborMarket) {
        self.goodsMarket = goodsMarket
        self.capitalMarket = capitalMarket
        self.assetMarket = assetMarket
        self.laborMarket = laborMarket
    }
}

// MARK: - PlayerAssets Extension for Codability

extension PlayerAssets: Codable {
    enum CodingKeys: String, CodingKey {
        case money
        case ships
        case warehouses
        case reputation
    }
}

extension Location: Codable {}
extension Coordinates: Codable {}
extension PortType: Codable {}