import Foundation
import CryptoKit

// MARK: - Cryptocurrency Models

public struct Cryptocurrency {
    public let symbol: String
    public let name: String
    public let network: BlockchainNetwork
    public let contractAddress: String?
    public let decimals: Int
    public let isStableCoin: Bool
    public let marketCap: Double
    public let dailyVolume: Double
    public let priceHistory: [PriceDataPoint]
    public let supportedFeatures: [CryptoFeature]
    
    public init(symbol: String, name: String, network: BlockchainNetwork, 
                contractAddress: String? = nil, decimals: Int = 18, 
                isStableCoin: Bool = false, marketCap: Double = 0, 
                dailyVolume: Double = 0, priceHistory: [PriceDataPoint] = [],
                supportedFeatures: [CryptoFeature] = []) {
        self.symbol = symbol
        self.name = name
        self.network = network
        self.contractAddress = contractAddress
        self.decimals = decimals
        self.isStableCoin = isStableCoin
        self.marketCap = marketCap
        self.dailyVolume = dailyVolume
        self.priceHistory = priceHistory
        self.supportedFeatures = supportedFeatures
    }
}

public enum BlockchainNetwork: String, CaseIterable {
    case ethereum = "Ethereum"
    case polygon = "Polygon"
    case binanceSmartChain = "Binance Smart Chain"
    case bitcoin = "Bitcoin"
    case solana = "Solana"
    case avalanche = "Avalanche"
    case cardano = "Cardano"
    case polkadot = "Polkadot"
    
    public var nativeCurrency: String {
        switch self {
        case .ethereum: return "ETH"
        case .polygon: return "MATIC"
        case .binanceSmartChain: return "BNB"
        case .bitcoin: return "BTC"
        case .solana: return "SOL"
        case .avalanche: return "AVAX"
        case .cardano: return "ADA"
        case .polkadot: return "DOT"
        }
    }
    
    public var averageBlockTime: TimeInterval {
        switch self {
        case .ethereum: return 12
        case .polygon: return 2
        case .binanceSmartChain: return 3
        case .bitcoin: return 600
        case .solana: return 0.4
        case .avalanche: return 2
        case .cardano: return 20
        case .polkadot: return 6
        }
    }
}

public enum CryptoFeature: String, CaseIterable {
    case staking = "Staking"
    case governance = "Governance"
    case defi = "DeFi"
    case nft = "NFT"
    case smartContracts = "Smart Contracts"
    case crossChain = "Cross Chain"
    case privacyFocused = "Privacy Focused"
    case fastTransactions = "Fast Transactions"
    case lowFees = "Low Fees"
    case carbonNeutral = "Carbon Neutral"
}

public struct PriceDataPoint {
    public let timestamp: Date
    public let price: Double
    public let volume: Double
    public let marketCap: Double
    
    public init(timestamp: Date, price: Double, volume: Double, marketCap: Double) {
        self.timestamp = timestamp
        self.price = price
        self.volume = volume
        self.marketCap = marketCap
    }
}

// MARK: - Digital Wallet Models

public struct DigitalWallet: Codable {
    public let address: String
    public let privateKey: String // Should be encrypted in production
    public var balances: [String: Double] // Currency -> Balance
    public var nftTokens: [String] // Token IDs
    public var transactionHistory: [String] // Transaction hashes
    public let creationDate: Date
    public var lastBackup: Date?
    
    public init(address: String, privateKey: String, balances: [String: Double] = [:],
                nftTokens: [String] = [], transactionHistory: [String] = []) {
        self.address = address
        self.privateKey = privateKey
        self.balances = balances
        self.nftTokens = nftTokens
        self.transactionHistory = transactionHistory
        self.creationDate = Date()
        self.lastBackup = nil
    }
    
    public var totalValueUSD: Double {
        // Calculate total portfolio value in USD
        // This would use current exchange rates
        return balances.values.reduce(0, +) * 50000 // Placeholder calculation
    }
    
    public var isEmpty: Bool {
        return balances.values.allSatisfy { $0 == 0 }
    }
}

// MARK: - NFT Models

public struct CommodityNFT: Identifiable, Codable {
    public let id: String // Token ID
    public let contractAddress: String
    public var owner: String
    public let commodity: CommodityAsset
    public let metadata: NFTMetadata
    public let mintDate: Date
    public var currentPrice: Double?
    public var isListed: Bool
    public let blockchain: BlockchainNetwork
    public var status: NFTStatus
    public var transferHistory: [NFTTransfer] = []
    public var royalties: RoyaltyStructure?
    
    public init(id: String, contractAddress: String, owner: String, commodity: CommodityAsset,
                metadata: NFTMetadata, mintDate: Date, currentPrice: Double? = nil,
                isListed: Bool = false, blockchain: BlockchainNetwork, status: NFTStatus) {
        self.id = id
        self.contractAddress = contractAddress
        self.owner = owner
        self.commodity = commodity
        self.metadata = metadata
        self.mintDate = mintDate
        self.currentPrice = currentPrice
        self.isListed = isListed
        self.blockchain = blockchain
        self.status = status
    }
}

public struct CommodityAsset: Codable {
    public let type: String // e.g., "Crude Oil", "Gold", "Wheat"
    public let quantity: Double
    public let unit: String // e.g., "barrels", "ounces", "tons"
    public let qualityGrade: String
    public let origin: String
    public let certifications: [String]
    public let storageLocation: String?
    public let expirationDate: Date?
    public let documentationHashes: [String] // IPFS hashes of certificates
    public let physicalIdentifiers: [String] // Serial numbers, batch codes, etc.
    
    public init(type: String, quantity: Double, unit: String, qualityGrade: String,
                origin: String, certifications: [String], storageLocation: String? = nil,
                expirationDate: Date? = nil, documentationHashes: [String] = [],
                physicalIdentifiers: [String] = []) {
        self.type = type
        self.quantity = quantity
        self.unit = unit
        self.qualityGrade = qualityGrade
        self.origin = origin
        self.certifications = certifications
        self.storageLocation = storageLocation
        self.expirationDate = expirationDate
        self.documentationHashes = documentationHashes
        self.physicalIdentifiers = physicalIdentifiers
    }
    
    public var estimatedValue: Double {
        // Calculate estimated value based on current market prices
        // This would integrate with commodity pricing systems
        switch type.lowercased() {
        case "crude oil": return quantity * 75.0 // $75 per barrel
        case "gold": return quantity * 2000.0 // $2000 per ounce
        case "wheat": return quantity * 300.0 // $300 per ton
        default: return quantity * 100.0 // Default $100 per unit
        }
    }
}

public struct NFTMetadata: Codable {
    public let name: String
    public let description: String
    public let image: String // URL or IPFS hash
    public var attributes: [NFTAttribute]
    public let externalUrl: String?
    public let animationUrl: String?
    public let backgroundColor: String?
    public let youtubeUrl: String?
    
    public init(name: String, description: String, image: String, attributes: [NFTAttribute] = [],
                externalUrl: String? = nil, animationUrl: String? = nil,
                backgroundColor: String? = nil, youtubeUrl: String? = nil) {
        self.name = name
        self.description = description
        self.image = image
        self.attributes = attributes
        self.externalUrl = externalUrl
        self.animationUrl = animationUrl
        self.backgroundColor = backgroundColor
        self.youtubeUrl = youtubeUrl
    }
}

public struct NFTAttribute: Codable {
    public let traitType: String
    public let value: String
    public let displayType: String?
    public let maxValue: Double?
    
    public init(traitType: String, value: String, displayType: String? = nil, maxValue: Double? = nil) {
        self.traitType = traitType
        self.value = value
        self.displayType = displayType
        self.maxValue = maxValue
    }
}

public enum NFTStatus: String, Codable, CaseIterable {
    case minted = "Minted"
    case owned = "Owned"
    case forSale = "For Sale"
    case inEscrow = "In Escrow"
    case transferred = "Transferred"
    case burned = "Burned"
    case fractionalized = "Fractionalized"
}

public struct NFTTransfer: Codable {
    public let from: String
    public let to: String
    public let transactionHash: String
    public let timestamp: Date
    public let price: Double?
    public let currency: String?
    
    public init(from: String, to: String, transactionHash: String, timestamp: Date,
                price: Double? = nil, currency: String? = nil) {
        self.from = from
        self.to = to
        self.transactionHash = transactionHash
        self.timestamp = timestamp
        self.price = price
        self.currency = currency
    }
}

public struct RoyaltyStructure: Codable {
    public let creator: String
    public let percentage: Double // 0.0 to 1.0
    public let beneficiaries: [RoyaltyBeneficiary]
    
    public init(creator: String, percentage: Double, beneficiaries: [RoyaltyBeneficiary] = []) {
        self.creator = creator
        self.percentage = percentage
        self.beneficiaries = beneficiaries
    }
}

public struct RoyaltyBeneficiary: Codable {
    public let address: String
    public let percentage: Double
    public let description: String
    
    public init(address: String, percentage: Double, description: String) {
        self.address = address
        self.percentage = percentage
        self.description = description
    }
}

// MARK: - Transaction Models

public struct BlockchainTransaction: Identifiable, Codable {
    public let id: String
    public let type: TransactionType
    public let fromAddress: String
    public let toAddress: String
    public let amount: Double
    public let currency: String
    public let timestamp: Date
    public var status: TransactionStatus
    public let gasUsed: Int
    public let transactionFee: Double
    public let blockNumber: Int?
    public let confirmations: Int
    public let memo: String?
    
    public init(id: String, type: TransactionType, fromAddress: String, toAddress: String,
                amount: Double, currency: String, timestamp: Date, status: TransactionStatus,
                gasUsed: Int, transactionFee: Double, blockNumber: Int? = nil,
                confirmations: Int = 0, memo: String? = nil) {
        self.id = id
        self.type = type
        self.fromAddress = fromAddress
        self.toAddress = toAddress
        self.amount = amount
        self.currency = currency
        self.timestamp = timestamp
        self.status = status
        self.gasUsed = gasUsed
        self.transactionFee = transactionFee
        self.blockNumber = blockNumber
        self.confirmations = confirmations
        self.memo = memo
    }
    
    public var isConfirmed: Bool {
        return confirmations >= 6 // Standard confirmation threshold
    }
    
    public var netAmount: Double {
        return amount - transactionFee
    }
}

public enum TransactionType: String, Codable, CaseIterable {
    case transfer = "Transfer"
    case cryptoPurchase = "Crypto Purchase"
    case cryptoSale = "Crypto Sale"
    case nftMint = "NFT Mint"
    case nftPurchase = "NFT Purchase"
    case nftSale = "NFT Sale"
    case staking = "Staking"
    case unstaking = "Unstaking"
    case liquidityAdd = "Add Liquidity"
    case liquidityRemove = "Remove Liquidity"
    case swap = "Token Swap"
    case futuresContract = "Futures Contract"
    case contractCall = "Smart Contract Call"
}

public enum TransactionStatus: String, Codable, CaseIterable {
    case pending = "Pending"
    case confirmed = "Confirmed"
    case completed = "Completed"
    case failed = "Failed"
    case canceled = "Canceled"
    case expired = "Expired"
}

// MARK: - DeFi Models

public struct StakingPool {
    public let id: String
    public let name: String
    public let stakedToken: String
    public let rewardsToken: String
    public let apy: Double // Annual Percentage Yield
    public let totalStaked: Double
    public let minimumStake: Double
    public let lockupPeriod: TimeInterval
    public let earlyUnstakePenalty: Double
    public let riskLevel: RiskLevel
    public let description: String
    
    public init(id: String, name: String, stakedToken: String, rewardsToken: String,
                apy: Double, totalStaked: Double, minimumStake: Double,
                lockupPeriod: TimeInterval, earlyUnstakePenalty: Double = 0.0,
                riskLevel: RiskLevel = .medium, description: String = "") {
        self.id = id
        self.name = name
        self.stakedToken = stakedToken
        self.rewardsToken = rewardsToken
        self.apy = apy
        self.totalStaked = totalStaked
        self.minimumStake = minimumStake
        self.lockupPeriod = lockupPeriod
        self.earlyUnstakePenalty = earlyUnstakePenalty
        self.riskLevel = riskLevel
        self.description = description
    }
}

public enum RiskLevel: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case extreme = "Extreme"
    
    public var riskMultiplier: Double {
        switch self {
        case .low: return 1.0
        case .medium: return 1.5
        case .high: return 2.0
        case .extreme: return 3.0
        }
    }
}

public struct YieldFarmingPool {
    public let name: String
    public let token1: String
    public let token2: String
    public let apy: Double
    public let totalLiquidity: Double
    public let userLiquidity: Double
    public let impermanentLossRisk: Double
    public let farmingRewards: [String] // Additional reward tokens
    
    public init(name: String, token1: String = "", token2: String = "", apy: Double,
                totalLiquidity: Double, userLiquidity: Double = 0.0,
                impermanentLossRisk: Double = 0.1, farmingRewards: [String] = []) {
        self.name = name
        self.token1 = token1
        self.token2 = token2
        self.apy = apy
        self.totalLiquidity = totalLiquidity
        self.userLiquidity = userLiquidity
        self.impermanentLossRisk = impermanentLossRisk
        self.farmingRewards = farmingRewards
    }
}

public struct FractionalizedNFT {
    public let originalNFT: CommodityNFT
    public let contractAddress: String
    public let totalSupply: Int
    public var availableSupply: Int
    public var pricePerFraction: Double
    public var holders: [String: Int] // Address -> fraction count
    public var tradingHistory: [FractionTrade]
    
    public init(originalNFT: CommodityNFT, contractAddress: String, totalSupply: Int,
                availableSupply: Int, pricePerFraction: Double, holders: [String: Int],
                tradingHistory: [FractionTrade]) {
        self.originalNFT = originalNFT
        self.contractAddress = contractAddress
        self.totalSupply = totalSupply
        self.availableSupply = availableSupply
        self.pricePerFraction = pricePerFraction
        self.holders = holders
        self.tradingHistory = tradingHistory
    }
    
    public var marketCap: Double {
        return Double(totalSupply) * pricePerFraction
    }
    
    public var liquidityRatio: Double {
        return Double(availableSupply) / Double(totalSupply)
    }
}

public struct FractionTrade {
    public let buyer: String
    public let seller: String
    public let quantity: Int
    public let pricePerFraction: Double
    public let timestamp: Date
    public let transactionHash: String
    
    public init(buyer: String, seller: String, quantity: Int, pricePerFraction: Double,
                timestamp: Date, transactionHash: String) {
        self.buyer = buyer
        self.seller = seller
        self.quantity = quantity
        self.pricePerFraction = pricePerFraction
        self.timestamp = timestamp
        self.transactionHash = transactionHash
    }
    
    public var totalValue: Double {
        return Double(quantity) * pricePerFraction
    }
}

public struct FuturesContract {
    public let id: String
    public let contractAddress: String
    public let commodity: String
    public let quantity: Double
    public let deliveryDate: Date
    public let strikePrice: Double
    public let creator: String
    public var buyer: String?
    public var status: FuturesStatus
    public let collateralRequired: Double
    public let creationDate: Date
    public var currentPrice: Double?
    public var marginCalls: [MarginCall] = []
    
    public init(id: String, contractAddress: String, commodity: String, quantity: Double,
                deliveryDate: Date, strikePrice: Double, creator: String, buyer: String? = nil,
                status: FuturesStatus, collateralRequired: Double, creationDate: Date,
                currentPrice: Double? = nil) {
        self.id = id
        self.contractAddress = contractAddress
        self.commodity = commodity
        self.quantity = quantity
        self.deliveryDate = deliveryDate
        self.strikePrice = strikePrice
        self.creator = creator
        self.buyer = buyer
        self.status = status
        self.collateralRequired = collateralRequired
        self.creationDate = creationDate
        self.currentPrice = currentPrice
    }
    
    public var timeToDelivery: TimeInterval {
        return deliveryDate.timeIntervalSinceNow
    }
    
    public var isExpired: Bool {
        return Date() > deliveryDate
    }
    
    public var profitLoss: Double? {
        guard let currentPrice = currentPrice else { return nil }
        return (currentPrice - strikePrice) * quantity
    }
}

public enum FuturesStatus: String, CaseIterable {
    case open = "Open"
    case matched = "Matched"
    case executed = "Executed"
    case expired = "Expired"
    case canceled = "Canceled"
    case defaulted = "Defaulted"
}

public struct MarginCall {
    public let timestamp: Date
    public let requiredAmount: Double
    public let reason: String
    public var response: MarginCallResponse?
    
    public init(timestamp: Date, requiredAmount: Double, reason: String, response: MarginCallResponse? = nil) {
        self.timestamp = timestamp
        self.requiredAmount = requiredAmount
        self.reason = reason
        self.response = response
    }
}

public enum MarginCallResponse: String, CaseIterable {
    case funded = "Funded"
    case ignored = "Ignored"
    case positionClosed = "Position Closed"
}

// MARK: - Result Models

public struct PurchaseResult {
    public let transactionId: String
    public let amount: Double
    public let currency: String
    public let status: PurchaseStatus
    public let receipt: String
    public let estimatedDeliveryTime: TimeInterval?
    
    public init(transactionId: String, amount: Double, currency: String, status: PurchaseStatus,
                receipt: String, estimatedDeliveryTime: TimeInterval? = nil) {
        self.transactionId = transactionId
        self.amount = amount
        self.currency = currency
        self.status = status
        self.receipt = receipt
        self.estimatedDeliveryTime = estimatedDeliveryTime
    }
}

public enum PurchaseStatus: String, CaseIterable {
    case success = "Success"
    case pending = "Pending"
    case failed = "Failed"
    case requiresVerification = "Requires Verification"
}

public struct SaleResult {
    public let transactionId: String
    public let amount: Double
    public let currency: String
    public let fiatAmount: Double
    public let status: SaleStatus
    public let estimatedSettlementTime: TimeInterval?
    
    public init(transactionId: String, amount: Double, currency: String, fiatAmount: Double,
                status: SaleStatus, estimatedSettlementTime: TimeInterval? = nil) {
        self.transactionId = transactionId
        self.amount = amount
        self.currency = currency
        self.fiatAmount = fiatAmount
        self.status = status
        self.estimatedSettlementTime = estimatedSettlementTime
    }
}

public enum SaleStatus: String, CaseIterable {
    case success = "Success"
    case pending = "Pending"
    case failed = "Failed"
    case processing = "Processing"
}

public struct TransferResult {
    public let transactionHash: String
    public let amount: Double
    public let currency: String
    public let gasUsed: Int
    public let totalFee: Double
    public let estimatedConfirmationTime: TimeInterval
    
    public init(transactionHash: String, amount: Double, currency: String, gasUsed: Int,
                totalFee: Double, estimatedConfirmationTime: TimeInterval) {
        self.transactionHash = transactionHash
        self.amount = amount
        self.currency = currency
        self.gasUsed = gasUsed
        self.totalFee = totalFee
        self.estimatedConfirmationTime = estimatedConfirmationTime
    }
}

public struct StakingResult {
    public let transactionHash: String
    public let stakedAmount: Double
    public let estimatedAPY: Double
    public let lockupPeriod: TimeInterval
    public let rewardsToken: String
    public let nextRewardDate: Date?
    
    public init(transactionHash: String, stakedAmount: Double, estimatedAPY: Double,
                lockupPeriod: TimeInterval, rewardsToken: String, nextRewardDate: Date? = nil) {
        self.transactionHash = transactionHash
        self.stakedAmount = stakedAmount
        self.estimatedAPY = estimatedAPY
        self.lockupPeriod = lockupPeriod
        self.rewardsToken = rewardsToken
        self.nextRewardDate = nextRewardDate
    }
}

public struct LiquidityResult {
    public let transactionHash: String
    public let lpTokens: Double
    public let poolShare: Double
    public let estimatedAPR: Double
    public let impermanentLossRisk: Double?
    
    public init(transactionHash: String, lpTokens: Double, poolShare: Double,
                estimatedAPR: Double, impermanentLossRisk: Double? = nil) {
        self.transactionHash = transactionHash
        self.lpTokens = lpTokens
        self.poolShare = poolShare
        self.estimatedAPR = estimatedAPR
        self.impermanentLossRisk = impermanentLossRisk
    }
}

public struct FractionalizationResult {
    public let contractAddress: String
    public let totalSupply: Int
    public let pricePerFraction: Double
    public let fractionalizedAsset: FractionalizedNFT
    public let marketplaceListingUrl: String?
    
    public init(contractAddress: String, totalSupply: Int, pricePerFraction: Double,
                fractionalizedAsset: FractionalizedNFT, marketplaceListingUrl: String? = nil) {
        self.contractAddress = contractAddress
        self.totalSupply = totalSupply
        self.pricePerFraction = pricePerFraction
        self.fractionalizedAsset = fractionalizedAsset
        self.marketplaceListingUrl = marketplaceListingUrl
    }
}

// MARK: - Service Result Models

public struct MintResult {
    public let tokenId: String
    public let contractAddress: String
    public let transactionHash: String?
    public let gasUsed: Int?
    public let mintingFee: Double?
    
    public init(tokenId: String, contractAddress: String, transactionHash: String? = nil,
                gasUsed: Int? = nil, mintingFee: Double? = nil) {
        self.tokenId = tokenId
        self.contractAddress = contractAddress
        self.transactionHash = transactionHash
        self.gasUsed = gasUsed
        self.mintingFee = mintingFee
    }
}

public struct NFTMarketData {
    public let floorPrice: Double
    public let averagePrice: Double
    public let totalVolume: Double
    public let totalSales: Int
    public let highestSale: Double
    public let lowestSale: Double
    public let priceHistory: [PriceDataPoint]
    
    public init(floorPrice: Double, averagePrice: Double, totalVolume: Double,
                totalSales: Int, highestSale: Double, lowestSale: Double,
                priceHistory: [PriceDataPoint] = []) {
        self.floorPrice = floorPrice
        self.averagePrice = averagePrice
        self.totalVolume = totalVolume
        self.totalSales = totalSales
        self.highestSale = highestSale
        self.lowestSale = lowestSale
        self.priceHistory = priceHistory
    }
}

public struct BlockchainTransactionResult {
    public let hash: String
    public let blockNumber: Int?
    public let gasUsed: Int?
    public let effectiveGasPrice: Double?
    public let confirmations: Int
    
    public init(hash: String, blockNumber: Int? = nil, gasUsed: Int? = nil,
                effectiveGasPrice: Double? = nil, confirmations: Int = 0) {
        self.hash = hash
        self.blockNumber = blockNumber
        self.gasUsed = gasUsed
        self.effectiveGasPrice = effectiveGasPrice
        self.confirmations = confirmations
    }
}

public struct LiquidityTransactionResult {
    public let hash: String
    public let lpTokensReceived: Double
    public let poolShare: Double
    public let estimatedAPR: Double
    
    public init(hash: String, lpTokensReceived: Double, poolShare: Double, estimatedAPR: Double) {
        self.hash = hash
        self.lpTokensReceived = lpTokensReceived
        self.poolShare = poolShare
        self.estimatedAPR = estimatedAPR
    }
}

public struct CryptoTransactionResult {
    public let id: String
    public let fee: Double
    public let receipt: String
    public let processingTime: TimeInterval?
    
    public init(id: String, fee: Double, receipt: String, processingTime: TimeInterval? = nil) {
        self.id = id
        self.fee = fee
        self.receipt = receipt
        self.processingTime = processingTime
    }
}

public struct CryptoSaleResult {
    public let id: String
    public let fee: Double
    public let fiatAmount: Double
    public let exchangeRate: Double?
    public let settlementTime: TimeInterval?
    
    public init(id: String, fee: Double, fiatAmount: Double, exchangeRate: Double? = nil,
                settlementTime: TimeInterval? = nil) {
        self.id = id
        self.fee = fee
        self.fiatAmount = fiatAmount
        self.exchangeRate = exchangeRate
        self.settlementTime = settlementTime
    }
}

public struct GasEstimate {
    public let gasUsed: Int
    public let fee: Double
    public let confirmationTime: TimeInterval
    public let priority: GasPriority
    
    public init(gasUsed: Int, fee: Double, confirmationTime: TimeInterval, priority: GasPriority = .standard) {
        self.gasUsed = gasUsed
        self.fee = fee
        self.confirmationTime = confirmationTime
        self.priority = priority
    }
}

public enum GasPriority: String, CaseIterable {
    case slow = "Slow"
    case standard = "Standard"
    case fast = "Fast"
    case instant = "Instant"
    
    public var multiplier: Double {
        switch self {
        case .slow: return 0.8
        case .standard: return 1.0
        case .fast: return 1.5
        case .instant: return 2.0
        }
    }
}

// MARK: - Compliance Models

public struct ComplianceResult {
    public let isAllowed: Bool
    public let reason: String
    public let riskScore: Double?
    public let requiredDocuments: [String]
    
    public init(isAllowed: Bool, reason: String, riskScore: Double? = nil, requiredDocuments: [String] = []) {
        self.isAllowed = isAllowed
        self.reason = reason
        self.riskScore = riskScore
        self.requiredDocuments = requiredDocuments
    }
}

public struct AMLResult {
    public let isApproved: Bool
    public let reason: String
    public let riskLevel: RiskLevel
    public let additionalChecksRequired: Bool
    
    public init(isApproved: Bool, reason: String, riskLevel: RiskLevel = .low, additionalChecksRequired: Bool = false) {
        self.isApproved = isApproved
        self.reason = reason
        self.riskLevel = riskLevel
        self.additionalChecksRequired = additionalChecksRequired
    }
}

// MARK: - Smart Contract Models

public struct SmartContract {
    public let address: String
    public let abi: String?
    public let bytecode: String?
    public let network: BlockchainNetwork
    public let deploymentDate: Date
    public let deployer: String
    public let version: String
    public var isVerified: Bool
    
    public init(address: String, abi: String? = nil, bytecode: String? = nil,
                network: BlockchainNetwork = .ethereum, deploymentDate: Date = Date(),
                deployer: String = "", version: String = "1.0.0", isVerified: Bool = false) {
        self.address = address
        self.abi = abi
        self.bytecode = bytecode
        self.network = network
        self.deploymentDate = deploymentDate
        self.deployer = deployer
        self.version = version
        self.isVerified = isVerified
    }
}

public struct MarketplaceListing {
    public let tokenId: String
    public let contractAddress: String?
    public let seller: String
    public let price: Double
    public let currency: String
    public let listingDate: Date
    public let expirationDate: Date?
    public var status: ListingStatus
    public let description: String?
    
    public init(tokenId: String, contractAddress: String? = nil, seller: String, price: Double,
                currency: String = "ETH", listingDate: Date = Date(), expirationDate: Date? = nil,
                status: ListingStatus = .active, description: String? = nil) {
        self.tokenId = tokenId
        self.contractAddress = contractAddress
        self.seller = seller
        self.price = price
        self.currency = currency
        self.listingDate = listingDate
        self.expirationDate = expirationDate
        self.status = status
        self.description = description
    }
}

public enum ListingStatus: String, CaseIterable {
    case active = "Active"
    case sold = "Sold"
    case canceled = "Canceled"
    case expired = "Expired"
    case reserved = "Reserved"
}

// MARK: - Cryptocurrency Creation Functions

extension BlockchainMarketplace {
    func createBitcoinCurrency() -> Cryptocurrency {
        return Cryptocurrency(
            symbol: "BTC",
            name: "Bitcoin",
            network: .bitcoin,
            decimals: 8,
            isStableCoin: false,
            marketCap: 800_000_000_000,
            dailyVolume: 20_000_000_000,
            supportedFeatures: [.fastTransactions, .privacyFocused]
        )
    }
    
    func createEthereumCurrency() -> Cryptocurrency {
        return Cryptocurrency(
            symbol: "ETH",
            name: "Ethereum",
            network: .ethereum,
            decimals: 18,
            isStableCoin: false,
            marketCap: 400_000_000_000,
            dailyVolume: 15_000_000_000,
            supportedFeatures: [.smartContracts, .defi, .nft, .staking]
        )
    }
    
    func createUSDCCurrency() -> Cryptocurrency {
        return Cryptocurrency(
            symbol: "USDC",
            name: "USD Coin",
            network: .ethereum,
            contractAddress: "0xA0b86a33E6441E2cC67E15b4aD61D6e0C5a9D4e2",
            decimals: 6,
            isStableCoin: true,
            marketCap: 50_000_000_000,
            dailyVolume: 3_000_000_000,
            supportedFeatures: [.defi, .fastTransactions, .lowFees]
        )
    }
    
    func createFlexCoinCurrency() -> Cryptocurrency {
        return Cryptocurrency(
            symbol: "FLEX",
            name: "FlexPort Token",
            network: .ethereum,
            contractAddress: "0x1234567890123456789012345678901234567890",
            decimals: 18,
            isStableCoin: false,
            marketCap: 100_000_000,
            dailyVolume: 1_000_000,
            supportedFeatures: [.governance, .staking, .defi, .nft]
        )
    }
    
    func createCommodityCoin() -> Cryptocurrency {
        return Cryptocurrency(
            symbol: "COMC",
            name: "Commodity Coin",
            network: .ethereum,
            contractAddress: "0x2345678901234567890123456789012345678901",
            decimals: 18,
            isStableCoin: true,
            marketCap: 500_000_000,
            dailyVolume: 5_000_000,
            supportedFeatures: [.defi, .staking]
        )
    }
    
    func createShippingCoin() -> Cryptocurrency {
        return Cryptocurrency(
            symbol: "SHIP",
            name: "Shipping Services Token",
            network: .polygon,
            contractAddress: "0x3456789012345678901234567890123456789012",
            decimals: 18,
            isStableCoin: false,
            marketCap: 50_000_000,
            dailyVolume: 500_000,
            supportedFeatures: [.governance, .lowFees, .fastTransactions]
        )
    }
    
    func createCarbonCreditCoin() -> Cryptocurrency {
        return Cryptocurrency(
            symbol: "CARBON",
            name: "Carbon Credit Token",
            network: .polygon,
            contractAddress: "0x4567890123456789012345678901234567890123",
            decimals: 18,
            isStableCoin: false,
            marketCap: 25_000_000,
            dailyVolume: 100_000,
            supportedFeatures: [.carbonNeutral, .governance, .nft]
        )
    }
}

// MARK: - Agricultural Zone Creation Functions

extension SeasonalMarketEngine {
    func createNorthAmericaAgZones() -> [AgriculturalZone] {
        return [
            AgriculturalZone(
                name: "US Midwest Corn Belt",
                location: CLLocationCoordinate2D(latitude: 41.0, longitude: -93.0),
                climateZone: .continental,
                primaryCrops: ["CORN", "SOYBEANS", "WHEAT"],
                soilQuality: 0.9,
                waterAvailability: 0.8,
                infrastructureLevel: 0.9,
                technologyAdoption: 0.95,
                laborAvailability: 0.8,
                marketAccess: 0.95
            ),
            AgriculturalZone(
                name: "Canadian Prairies",
                location: CLLocationCoordinate2D(latitude: 52.0, longitude: -106.0),
                climateZone: .continental,
                primaryCrops: ["WHEAT", "CANOLA", "BARLEY"],
                soilQuality: 0.85,
                waterAvailability: 0.7,
                infrastructureLevel: 0.8,
                technologyAdoption: 0.9,
                laborAvailability: 0.75,
                marketAccess: 0.8
            )
        ]
    }
    
    func createSouthAmericaAgZones() -> [AgriculturalZone] {
        return [
            AgriculturalZone(
                name: "Argentine Pampas",
                location: CLLocationCoordinate2D(latitude: -34.0, longitude: -61.0),
                climateZone: .temperate,
                primaryCrops: ["SOYBEANS", "WHEAT", "CORN", "BEEF"],
                soilQuality: 0.9,
                waterAvailability: 0.8,
                infrastructureLevel: 0.7,
                technologyAdoption: 0.8,
                laborAvailability: 0.85,
                marketAccess: 0.75
            ),
            AgriculturalZone(
                name: "Brazilian Cerrado",
                location: CLLocationCoordinate2D(latitude: -15.0, longitude: -55.0),
                climateZone: .tropical,
                primaryCrops: ["SOYBEANS", "CORN", "COTTON", "COFFEE"],
                soilQuality: 0.7,
                waterAvailability: 0.9,
                infrastructureLevel: 0.6,
                technologyAdoption: 0.85,
                laborAvailability: 0.9,
                marketAccess: 0.7
            )
        ]
    }
    
    func createEuropeAgZones() -> [AgriculturalZone] {
        return [
            AgriculturalZone(
                name: "French Plains",
                location: CLLocationCoordinate2D(latitude: 48.5, longitude: 2.0),
                climateZone: .temperate,
                primaryCrops: ["WHEAT", "BARLEY", "CORN", "SUGAR_BEET"],
                soilQuality: 0.85,
                waterAvailability: 0.8,
                infrastructureLevel: 0.95,
                technologyAdoption: 0.9,
                laborAvailability: 0.7,
                marketAccess: 0.95
            ),
            AgriculturalZone(
                name: "Ukrainian Steppes",
                location: CLLocationCoordinate2D(latitude: 49.0, longitude: 32.0),
                climateZone: .continental,
                primaryCrops: ["WHEAT", "BARLEY", "CORN", "SUNFLOWER"],
                soilQuality: 0.95,
                waterAvailability: 0.6,
                infrastructureLevel: 0.6,
                technologyAdoption: 0.7,
                laborAvailability: 0.8,
                marketAccess: 0.6
            )
        ]
    }
    
    func createAsiaAgZones() -> [AgriculturalZone] {
        return [
            AgriculturalZone(
                name: "Ganges Plain",
                location: CLLocationCoordinate2D(latitude: 26.0, longitude: 82.0),
                climateZone: .tropical,
                primaryCrops: ["RICE", "WHEAT", "SUGARCANE"],
                soilQuality: 0.8,
                waterAvailability: 0.9,
                infrastructureLevel: 0.5,
                technologyAdoption: 0.6,
                laborAvailability: 0.95,
                marketAccess: 0.6
            ),
            AgriculturalZone(
                name: "Mekong Delta",
                location: CLLocationCoordinate2D(latitude: 10.5, longitude: 105.5),
                climateZone: .tropical,
                primaryCrops: ["RICE", "PALM_OIL"],
                soilQuality: 0.9,
                waterAvailability: 0.95,
                infrastructureLevel: 0.6,
                technologyAdoption: 0.7,
                laborAvailability: 0.9,
                marketAccess: 0.7
            )
        ]
    }
    
    func createAfricaAgZones() -> [AgriculturalZone] {
        return [
            AgriculturalZone(
                name: "Nile Delta",
                location: CLLocationCoordinate2D(latitude: 30.5, longitude: 31.0),
                climateZone: .arid,
                primaryCrops: ["RICE", "WHEAT", "COTTON"],
                soilQuality: 0.8,
                waterAvailability: 0.7,
                infrastructureLevel: 0.6,
                technologyAdoption: 0.5,
                laborAvailability: 0.8,
                marketAccess: 0.6
            ),
            AgriculturalZone(
                name: "Ethiopian Highlands",
                location: CLLocationCoordinate2D(latitude: 9.0, longitude: 38.0),
                climateZone: .temperate,
                primaryCrops: ["COFFEE", "WHEAT", "BARLEY"],
                soilQuality: 0.7,
                waterAvailability: 0.6,
                infrastructureLevel: 0.4,
                technologyAdoption: 0.3,
                laborAvailability: 0.9,
                marketAccess: 0.4
            )
        ]
    }
    
    func createOceaniaAgZones() -> [AgriculturalZone] {
        return [
            AgriculturalZone(
                name: "Murray-Darling Basin",
                location: CLLocationCoordinate2D(latitude: -34.0, longitude: 142.0),
                climateZone: .temperate,
                primaryCrops: ["WHEAT", "COTTON", "RICE"],
                soilQuality: 0.7,
                waterAvailability: 0.5,
                infrastructureLevel: 0.8,
                technologyAdoption: 0.9,
                laborAvailability: 0.6,
                marketAccess: 0.8
            )
        ]
    }
    
    func createMiddleEastAgZones() -> [AgriculturalZone] {
        return [
            AgriculturalZone(
                name: "Mesopotamian Plains",
                location: CLLocationCoordinate2D(latitude: 33.0, longitude: 44.0),
                climateZone: .arid,
                primaryCrops: ["WHEAT", "BARLEY", "DATES"],
                soilQuality: 0.6,
                waterAvailability: 0.4,
                infrastructureLevel: 0.5,
                technologyAdoption: 0.6,
                laborAvailability: 0.7,
                marketAccess: 0.5
            )
        ]
    }
}

// MARK: - Seasonal Pattern Creation Functions

extension SeasonalMarketEngine {
    func createWheatPattern(_ hemisphere: Hemisphere) -> CommoditySeasonalPattern {
        let monthlyMultipliers: [Int: Double]
        let supplyPattern: [Int: Double]
        let demandPattern: [Int: Double]
        
        if hemisphere == .northern {
            monthlyMultipliers = [7: 0.9, 8: 0.85, 9: 0.8, 10: 1.1, 11: 1.2, 12: 1.15, 1: 1.1, 2: 1.05, 3: 1.0, 4: 0.95, 5: 0.9, 6: 0.95]
            supplyPattern = [7: 1.3, 8: 1.5, 9: 1.4, 10: 1.0, 11: 0.9, 12: 0.8, 1: 0.8, 2: 0.8, 3: 0.9, 4: 1.0, 5: 1.1, 6: 1.2]
            demandPattern = [1: 1.1, 2: 1.1, 3: 1.0, 4: 0.9, 5: 0.9, 6: 0.9, 7: 1.0, 8: 1.0, 9: 1.1, 10: 1.2, 11: 1.2, 12: 1.1]
        } else {
            monthlyMultipliers = [1: 0.9, 2: 0.85, 3: 0.8, 4: 1.1, 5: 1.2, 6: 1.15, 7: 1.1, 8: 1.05, 9: 1.0, 10: 0.95, 11: 0.9, 12: 0.95]
            supplyPattern = [1: 1.3, 2: 1.5, 3: 1.4, 4: 1.0, 5: 0.9, 6: 0.8, 7: 0.8, 8: 0.8, 9: 0.9, 10: 1.0, 11: 1.1, 12: 1.2]
            demandPattern = [7: 1.1, 8: 1.1, 9: 1.0, 10: 0.9, 11: 0.9, 12: 0.9, 1: 1.0, 2: 1.0, 3: 1.1, 4: 1.2, 5: 1.2, 6: 1.1]
        }
        
        return CommoditySeasonalPattern(
            commodity: "WHEAT",
            patternType: .agricultural,
            monthlyMultipliers: monthlyMultipliers,
            volatilityPattern: [7: 0.3, 8: 0.4, 9: 0.3, 10: 0.2, 11: 0.1, 12: 0.1, 1: 0.1, 2: 0.1, 3: 0.2, 4: 0.2, 5: 0.2, 6: 0.3],
            supplyPattern: supplyPattern,
            demandPattern: demandPattern,
            weatherSensitivity: WeatherSensitivity(temperature: 0.6, precipitation: 0.8, wind: 0.3, extremeWeather: 0.8)
        )
    }
    
    func createCornPattern(_ hemisphere: Hemisphere) -> CommoditySeasonalPattern {
        let monthlyMultipliers: [Int: Double]
        let supplyPattern: [Int: Double]
        
        if hemisphere == .northern {
            monthlyMultipliers = [9: 0.8, 10: 0.85, 11: 0.9, 12: 1.0, 1: 1.1, 2: 1.15, 3: 1.1, 4: 1.0, 5: 0.95, 6: 0.9, 7: 0.9, 8: 0.9]
            supplyPattern = [9: 1.5, 10: 1.4, 11: 1.2, 12: 1.0, 1: 0.8, 2: 0.8, 3: 0.8, 4: 0.9, 5: 1.0, 6: 1.1, 7: 1.2, 8: 1.3]
        } else {
            monthlyMultipliers = [3: 0.8, 4: 0.85, 5: 0.9, 6: 1.0, 7: 1.1, 8: 1.15, 9: 1.1, 10: 1.0, 11: 0.95, 12: 0.9, 1: 0.9, 2: 0.9]
            supplyPattern = [3: 1.5, 4: 1.4, 5: 1.2, 6: 1.0, 7: 0.8, 8: 0.8, 9: 0.8, 10: 0.9, 11: 1.0, 12: 1.1, 1: 1.2, 2: 1.3]
        }
        
        return CommoditySeasonalPattern(
            commodity: "CORN",
            patternType: .agricultural,
            monthlyMultipliers: monthlyMultipliers,
            volatilityPattern: [9: 0.3, 10: 0.3, 11: 0.2, 12: 0.1, 1: 0.1, 2: 0.1, 3: 0.2, 4: 0.2, 5: 0.3, 6: 0.3, 7: 0.3, 8: 0.3],
            supplyPattern: supplyPattern,
            demandPattern: [1: 1.2, 2: 1.2, 3: 1.1, 4: 1.0, 5: 0.9, 6: 0.9, 7: 0.9, 8: 0.9, 9: 1.0, 10: 1.1, 11: 1.2, 12: 1.2],
            weatherSensitivity: WeatherSensitivity(temperature: 0.7, precipitation: 0.9, wind: 0.2, extremeWeather: 0.8)
        )
    }
    
    func createNaturalGasPattern(_ hemisphere: Hemisphere) -> CommoditySeasonalPattern {
        let monthlyMultipliers: [Int: Double]
        let demandPattern: [Int: Double]
        
        if hemisphere == .northern {
            monthlyMultipliers = [12: 1.4, 1: 1.5, 2: 1.4, 3: 1.2, 4: 1.0, 5: 0.8, 6: 0.9, 7: 1.1, 8: 1.2, 9: 0.9, 10: 1.0, 11: 1.2]
            demandPattern = [12: 1.6, 1: 1.7, 2: 1.6, 3: 1.3, 4: 1.0, 5: 0.7, 6: 0.8, 7: 1.0, 8: 1.1, 9: 0.8, 10: 1.0, 11: 1.3]
        } else {
            monthlyMultipliers = [6: 1.4, 7: 1.5, 8: 1.4, 9: 1.2, 10: 1.0, 11: 0.8, 12: 0.9, 1: 1.1, 2: 1.2, 3: 0.9, 4: 1.0, 5: 1.2]
            demandPattern = [6: 1.6, 7: 1.7, 8: 1.6, 9: 1.3, 10: 1.0, 11: 0.7, 12: 0.8, 1: 1.0, 2: 1.1, 3: 0.8, 4: 1.0, 5: 1.3]
        }
        
        return CommoditySeasonalPattern(
            commodity: "NATURAL_GAS",
            patternType: .energy,
            monthlyMultipliers: monthlyMultipliers,
            volatilityPattern: [1: 0.4, 2: 0.4, 3: 0.3, 4: 0.2, 5: 0.3, 6: 0.3, 7: 0.3, 8: 0.3, 9: 0.3, 10: 0.3, 11: 0.3, 12: 0.4],
            supplyPattern: [1: 0.9, 2: 0.9, 3: 1.0, 4: 1.1, 5: 1.2, 6: 1.2, 7: 1.2, 8: 1.1, 9: 1.1, 10: 1.0, 11: 0.9, 12: 0.9],
            demandPattern: demandPattern,
            weatherSensitivity: WeatherSensitivity(temperature: 0.9, precipitation: 0.1, wind: 0.2, extremeWeather: 0.6)
        )
    }
    
    // Additional pattern creation methods would go here for other commodities...
    func createSoybeansPattern(_ hemisphere: Hemisphere) -> CommoditySeasonalPattern {
        return CommoditySeasonalPattern(
            commodity: "SOYBEANS",
            patternType: .agricultural,
            monthlyMultipliers: [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0, 8: 1.0, 9: 1.0, 10: 1.0, 11: 1.0, 12: 1.0],
            volatilityPattern: [1: 0.2, 2: 0.2, 3: 0.2, 4: 0.2, 5: 0.2, 6: 0.2, 7: 0.2, 8: 0.2, 9: 0.2, 10: 0.2, 11: 0.2, 12: 0.2],
            supplyPattern: [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0, 8: 1.0, 9: 1.0, 10: 1.0, 11: 1.0, 12: 1.0],
            demandPattern: [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0, 8: 1.0, 9: 1.0, 10: 1.0, 11: 1.0, 12: 1.0],
            weatherSensitivity: WeatherSensitivity(temperature: 0.7, precipitation: 0.8, extremeWeather: 0.8)
        )
    }
    
    func createHeatingOilPattern(_ hemisphere: Hemisphere) -> CommoditySeasonalPattern {
        return CommoditySeasonalPattern(
            commodity: "HEATING_OIL",
            patternType: .energy,
            monthlyMultipliers: [1: 1.3, 2: 1.3, 3: 1.2, 4: 1.0, 5: 0.8, 6: 0.7, 7: 0.7, 8: 0.8, 9: 0.9, 10: 1.1, 11: 1.2, 12: 1.3],
            volatilityPattern: [1: 0.3, 2: 0.3, 3: 0.3, 4: 0.2, 5: 0.2, 6: 0.2, 7: 0.2, 8: 0.2, 9: 0.2, 10: 0.2, 11: 0.3, 12: 0.3],
            supplyPattern: [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0, 8: 1.0, 9: 1.0, 10: 1.0, 11: 1.0, 12: 1.0],
            demandPattern: [1: 1.5, 2: 1.5, 3: 1.3, 4: 1.0, 5: 0.7, 6: 0.5, 7: 0.5, 8: 0.6, 9: 0.8, 10: 1.1, 11: 1.3, 12: 1.4],
            weatherSensitivity: WeatherSensitivity(temperature: 0.9, precipitation: 0.1, extremeWeather: 0.5)
        )
    }
    
    // Placeholder implementations for other patterns
    func createCoffeePattern(_ climate: SeasonalPatternType) -> CommoditySeasonalPattern {
        return CommoditySeasonalPattern(
            commodity: "COFFEE",
            patternType: climate,
            monthlyMultipliers: [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0, 8: 1.0, 9: 1.0, 10: 1.0, 11: 1.0, 12: 1.0],
            volatilityPattern: [1: 0.3, 2: 0.3, 3: 0.3, 4: 0.3, 5: 0.3, 6: 0.3, 7: 0.3, 8: 0.3, 9: 0.3, 10: 0.3, 11: 0.3, 12: 0.3],
            supplyPattern: [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0, 8: 1.0, 9: 1.0, 10: 1.0, 11: 1.0, 12: 1.0],
            demandPattern: [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0, 8: 1.0, 9: 1.0, 10: 1.0, 11: 1.0, 12: 1.0],
            weatherSensitivity: WeatherSensitivity(temperature: 0.8, precipitation: 0.9, extremeWeather: 0.9)
        )
    }
    
    func createIronOrePattern(_ climate: SeasonalPatternType) -> CommoditySeasonalPattern {
        return CommoditySeasonalPattern(
            commodity: "IRON_ORE",
            patternType: climate,
            monthlyMultipliers: [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0, 8: 1.0, 9: 1.0, 10: 1.0, 11: 1.0, 12: 1.0],
            volatilityPattern: [1: 0.2, 2: 0.2, 3: 0.2, 4: 0.2, 5: 0.2, 6: 0.2, 7: 0.2, 8: 0.2, 9: 0.2, 10: 0.2, 11: 0.2, 12: 0.2],
            supplyPattern: [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0, 8: 1.0, 9: 1.0, 10: 1.0, 11: 1.0, 12: 1.0],
            demandPattern: [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0, 8: 1.0, 9: 1.0, 10: 1.0, 11: 1.0, 12: 1.0],
            weatherSensitivity: WeatherSensitivity(temperature: 0.2, precipitation: 0.3, extremeWeather: 0.4)
        )
    }
    
    func createAluminumPattern(_ climate: SeasonalPatternType) -> CommoditySeasonalPattern {
        return CommoditySeasonalPattern(
            commodity: "ALUMINUM",
            patternType: climate,
            monthlyMultipliers: [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0, 8: 1.0, 9: 1.0, 10: 1.0, 11: 1.0, 12: 1.0],
            volatilityPattern: [1: 0.2, 2: 0.2, 3: 0.2, 4: 0.2, 5: 0.2, 6: 0.2, 7: 0.2, 8: 0.2, 9: 0.2, 10: 0.2, 11: 0.2, 12: 0.2],
            supplyPattern: [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0, 8: 1.0, 9: 1.0, 10: 1.0, 11: 1.0, 12: 1.0],
            demandPattern: [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0, 8: 1.0, 9: 1.0, 10: 1.0, 11: 1.0, 12: 1.0],
            weatherSensitivity: WeatherSensitivity(temperature: 0.1, precipitation: 0.1, extremeWeather: 0.2)
        )
    }
    
    func createRicePattern(_ climate: SeasonalPatternType) -> CommoditySeasonalPattern {
        return CommoditySeasonalPattern(
            commodity: "RICE",
            patternType: climate,
            monthlyMultipliers: [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0, 8: 1.0, 9: 1.0, 10: 1.2, 11: 1.3, 12: 1.1],
            volatilityPattern: [1: 0.2, 2: 0.2, 3: 0.2, 4: 0.2, 5: 0.2, 6: 0.3, 7: 0.3, 8: 0.3, 9: 0.3, 10: 0.3, 11: 0.3, 12: 0.2],
            supplyPattern: [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0, 8: 1.0, 9: 1.0, 10: 1.3, 11: 1.4, 12: 1.2],
            demandPattern: [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0, 8: 1.0, 9: 1.0, 10: 1.0, 11: 1.0, 12: 1.0],
            weatherSensitivity: WeatherSensitivity(temperature: 0.7, precipitation: 0.9, extremeWeather: 0.9)
        )
    }
    
    func createPalmOilPattern(_ climate: SeasonalPatternType) -> CommoditySeasonalPattern {
        return CommoditySeasonalPattern(
            commodity: "PALM_OIL",
            patternType: climate,
            monthlyMultipliers: [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0, 8: 1.0, 9: 1.0, 10: 1.0, 11: 1.0, 12: 1.0],
            volatilityPattern: [1: 0.3, 2: 0.3, 3: 0.3, 4: 0.3, 5: 0.3, 6: 0.3, 7: 0.3, 8: 0.3, 9: 0.3, 10: 0.3, 11: 0.3, 12: 0.3],
            supplyPattern: [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0, 8: 1.0, 9: 1.0, 10: 1.0, 11: 1.0, 12: 1.0],
            demandPattern: [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0, 8: 1.0, 9: 1.0, 10: 1.0, 11: 1.0, 12: 1.0],
            weatherSensitivity: WeatherSensitivity(temperature: 0.6, precipitation: 0.8, extremeWeather: 0.8)
        )
    }
    
    func createRubberPattern(_ climate: SeasonalPatternType) -> CommoditySeasonalPattern {
        return CommoditySeasonalPattern(
            commodity: "RUBBER",
            patternType: climate,
            monthlyMultipliers: [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0, 8: 1.0, 9: 1.0, 10: 1.0, 11: 1.0, 12: 1.0],
            volatilityPattern: [1: 0.3, 2: 0.3, 3: 0.3, 4: 0.3, 5: 0.3, 6: 0.3, 7: 0.3, 8: 0.3, 9: 0.3, 10: 0.3, 11: 0.3, 12: 0.3],
            supplyPattern: [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0, 8: 1.0, 9: 1.0, 10: 1.0, 11: 1.0, 12: 1.0],
            demandPattern: [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0, 8: 1.0, 9: 1.0, 10: 1.0, 11: 1.0, 12: 1.0],
            weatherSensitivity: WeatherSensitivity(temperature: 0.6, precipitation: 0.7, extremeWeather: 0.8)
        )
    }
    
    func createCoalPattern(_ climate: SeasonalPatternType) -> CommoditySeasonalPattern {
        return CommoditySeasonalPattern(
            commodity: "COAL",
            patternType: .energy,
            monthlyMultipliers: [1: 1.2, 2: 1.2, 3: 1.1, 4: 1.0, 5: 0.9, 6: 0.9, 7: 0.9, 8: 0.9, 9: 1.0, 10: 1.1, 11: 1.1, 12: 1.2],
            volatilityPattern: [1: 0.3, 2: 0.3, 3: 0.2, 4: 0.2, 5: 0.2, 6: 0.2, 7: 0.2, 8: 0.2, 9: 0.2, 10: 0.2, 11: 0.3, 12: 0.3],
            supplyPattern: [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0, 8: 1.0, 9: 1.0, 10: 1.0, 11: 1.0, 12: 1.0],
            demandPattern: [1: 1.3, 2: 1.3, 3: 1.2, 4: 1.0, 5: 0.8, 6: 0.8, 7: 0.8, 8: 0.8, 9: 1.0, 10: 1.1, 11: 1.2, 12: 1.3],
            weatherSensitivity: WeatherSensitivity(temperature: 0.3, precipitation: 0.2, extremeWeather: 0.3)
        )
    }
    
    func createGoldPattern(_ climate: SeasonalPatternType) -> CommoditySeasonalPattern {
        return CommoditySeasonalPattern(
            commodity: "GOLD",
            patternType: .stable,
            monthlyMultipliers: [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0, 8: 1.0, 9: 1.0, 10: 1.0, 11: 1.0, 12: 1.0],
            volatilityPattern: [1: 0.15, 2: 0.15, 3: 0.15, 4: 0.15, 5: 0.15, 6: 0.15, 7: 0.15, 8: 0.15, 9: 0.15, 10: 0.15, 11: 0.15, 12: 0.15],
            supplyPattern: [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0, 8: 1.0, 9: 1.0, 10: 1.0, 11: 1.0, 12: 1.0],
            demandPattern: [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0, 8: 1.0, 9: 1.0, 10: 1.0, 11: 1.0, 12: 1.0],
            weatherSensitivity: WeatherSensitivity(temperature: 0.0, precipitation: 0.0, extremeWeather: 0.05)
        )
    }
    
    func createPlatinumPattern(_ climate: SeasonalPatternType) -> CommoditySeasonalPattern {
        return CommoditySeasonalPattern(
            commodity: "PLATINUM",
            patternType: .stable,
            monthlyMultipliers: [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0, 8: 1.0, 9: 1.0, 10: 1.0, 11: 1.0, 12: 1.0],
            volatilityPattern: [1: 0.2, 2: 0.2, 3: 0.2, 4: 0.2, 5: 0.2, 6: 0.2, 7: 0.2, 8: 0.2, 9: 0.2, 10: 0.2, 11: 0.2, 12: 0.2],
            supplyPattern: [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0, 8: 1.0, 9: 1.0, 10: 1.0, 11: 1.0, 12: 1.0],
            demandPattern: [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0, 8: 1.0, 9: 1.0, 10: 1.0, 11: 1.0, 12: 1.0],
            weatherSensitivity: WeatherSensitivity(temperature: 0.0, precipitation: 0.0, extremeWeather: 0.05)
        )
    }
    
    func createCottonPattern(_ climate: SeasonalPatternType) -> CommoditySeasonalPattern {
        return CommoditySeasonalPattern(
            commodity: "COTTON",
            patternType: .agricultural,
            monthlyMultipliers: [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0, 8: 1.0, 9: 1.0, 10: 1.1, 11: 1.2, 12: 1.1],
            volatilityPattern: [1: 0.25, 2: 0.25, 3: 0.25, 4: 0.25, 5: 0.25, 6: 0.25, 7: 0.25, 8: 0.25, 9: 0.25, 10: 0.3, 11: 0.3, 12: 0.25],
            supplyPattern: [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0, 8: 1.0, 9: 1.0, 10: 1.2, 11: 1.3, 12: 1.1],
            demandPattern: [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0, 8: 1.0, 9: 1.0, 10: 1.0, 11: 1.0, 12: 1.0],
            weatherSensitivity: WeatherSensitivity(temperature: 0.7, precipitation: 0.8, extremeWeather: 0.8)
        )
    }
    
    func createCrudeOilPattern(_ climate: SeasonalPatternType) -> CommoditySeasonalPattern {
        return CommoditySeasonalPattern(
            commodity: "CRUDE_OIL",
            patternType: .stable,
            monthlyMultipliers: [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0, 8: 1.0, 9: 1.0, 10: 1.0, 11: 1.0, 12: 1.0],
            volatilityPattern: [1: 0.25, 2: 0.25, 3: 0.25, 4: 0.25, 5: 0.25, 6: 0.25, 7: 0.25, 8: 0.25, 9: 0.25, 10: 0.25, 11: 0.25, 12: 0.25],
            supplyPattern: [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0, 8: 1.0, 9: 1.0, 10: 1.0, 11: 1.0, 12: 1.0],
            demandPattern: [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.1, 7: 1.2, 8: 1.2, 9: 1.0, 10: 1.0, 11: 1.0, 12: 1.0],
            weatherSensitivity: WeatherSensitivity(temperature: 0.1, precipitation: 0.1, extremeWeather: 0.4)
        )
    }
    
    func createBeefPattern(_ climate: SeasonalPatternType) -> CommoditySeasonalPattern {
        return CommoditySeasonalPattern(
            commodity: "BEEF",
            patternType: .agricultural,
            monthlyMultipliers: [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.1, 6: 1.2, 7: 1.2, 8: 1.1, 9: 1.0, 10: 1.0, 11: 1.0, 12: 1.0],
            volatilityPattern: [1: 0.2, 2: 0.2, 3: 0.2, 4: 0.2, 5: 0.2, 6: 0.2, 7: 0.2, 8: 0.2, 9: 0.2, 10: 0.2, 11: 0.2, 12: 0.2],
            supplyPattern: [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0, 8: 1.0, 9: 1.0, 10: 1.0, 11: 1.0, 12: 1.0],
            demandPattern: [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.1, 6: 1.2, 7: 1.2, 8: 1.1, 9: 1.0, 10: 1.0, 11: 1.0, 12: 1.0],
            weatherSensitivity: WeatherSensitivity(temperature: 0.4, precipitation: 0.6, extremeWeather: 0.7)
        )
    }
    
    func createWoolPattern(_ climate: SeasonalPatternType) -> CommoditySeasonalPattern {
        return CommoditySeasonalPattern(
            commodity: "WOOL",
            patternType: .agricultural,
            monthlyMultipliers: [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0, 8: 1.0, 9: 1.0, 10: 1.0, 11: 1.0, 12: 1.0],
            volatilityPattern: [1: 0.2, 2: 0.2, 3: 0.2, 4: 0.2, 5: 0.2, 6: 0.2, 7: 0.2, 8: 0.2, 9: 0.2, 10: 0.2, 11: 0.2, 12: 0.2],
            supplyPattern: [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0, 8: 1.0, 9: 1.0, 10: 1.0, 11: 1.0, 12: 1.0],
            demandPattern: [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0, 8: 1.0, 9: 1.0, 10: 1.0, 11: 1.0, 12: 1.0],
            weatherSensitivity: WeatherSensitivity(temperature: 0.3, precipitation: 0.4, extremeWeather: 0.6)
        )
    }
    
    func createDatesPattern(_ climate: SeasonalPatternType) -> CommoditySeasonalPattern {
        return CommoditySeasonalPattern(
            commodity: "DATES",
            patternType: .agricultural,
            monthlyMultipliers: [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0, 8: 1.0, 9: 1.2, 10: 1.3, 11: 1.2, 12: 1.0],
            volatilityPattern: [1: 0.2, 2: 0.2, 3: 0.2, 4: 0.2, 5: 0.2, 6: 0.2, 7: 0.2, 8: 0.2, 9: 0.3, 10: 0.3, 11: 0.3, 12: 0.2],
            supplyPattern: [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0, 8: 1.0, 9: 1.3, 10: 1.5, 11: 1.3, 12: 1.0],
            demandPattern: [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0, 8: 1.0, 9: 1.2, 10: 1.3, 11: 1.2, 12: 1.0],
            weatherSensitivity: WeatherSensitivity(temperature: 0.6, precipitation: 0.5, extremeWeather: 0.7)
        )
    }
}