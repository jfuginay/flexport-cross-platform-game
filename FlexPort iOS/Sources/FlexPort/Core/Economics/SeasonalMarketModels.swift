import Foundation
import CoreLocation

// MARK: - Core Seasonal Models

public struct SeasonalFactorSet {
    public let region: String
    public let timestamp: Date
    public var commodityFactors: [String: CommoditySeasonalFactors] = [:]
    public var weatherFactors: WeatherFactors
    public var agriculturalFactors: AgriculturalFactors
    public var energyFactors: EnergyFactors
    
    public init(region: String, timestamp: Date = Date()) {
        self.region = region
        self.timestamp = timestamp
        self.weatherFactors = WeatherFactors()
        self.agriculturalFactors = AgriculturalFactors()
        self.energyFactors = EnergyFactors()
    }
}

public struct CommoditySeasonalFactors {
    public let commodity: String
    public var priceMultiplier: Double
    public var volatilityAdjustment: Double
    public var demandAdjustment: Double
    public var supplyAdjustment: Double
    public var confidence: Double
    public let season: Season
    public let hemisphere: Hemisphere
    
    public init(commodity: String, priceMultiplier: Double = 1.0, volatilityAdjustment: Double = 0.0,
                demandAdjustment: Double = 1.0, supplyAdjustment: Double = 1.0, confidence: Double = 0.8,
                season: Season = .spring, hemisphere: Hemisphere = .northern) {
        self.commodity = commodity
        self.priceMultiplier = priceMultiplier
        self.volatilityAdjustment = volatilityAdjustment
        self.demandAdjustment = demandAdjustment
        self.supplyAdjustment = supplyAdjustment
        self.confidence = confidence
        self.season = season
        self.hemisphere = hemisphere
    }
    
    public static let `default` = CommoditySeasonalFactors(commodity: "DEFAULT")
}

public struct WeatherFactors {
    public var temperatureFactor: Double = 1.0
    public var precipitationFactor: Double = 1.0
    public var windFactor: Double = 1.0
    public var humidityFactor: Double = 1.0
    public var extremeWeatherRisk: Double = 0.2
    public var seasonalVariation: Double = 0.1
}

public struct AgriculturalFactors {
    public var plantingSeason: Bool = false
    public var harvestSeason: Bool = false
    public var growingSeason: Bool = false
    public var dormantSeason: Bool = false
    public var yieldExpectation: Double = 1.0
    public var cropCondition: Double = 0.8
    public var irrigationDemand: Double = 0.5
}

public struct EnergyFactors {
    public var heatingDemand: Double = 0.5
    public var coolingDemand: Double = 0.5
    public var renewableGeneration: Double = 0.8
    public var storageRequirement: Double = 0.3
    public var transmissionEfficiency: Double = 0.95
}

// MARK: - Weather and Climate Models

public struct WeatherEvent {
    public let id: UUID
    public let type: WeatherEventType
    public let intensity: Double // 0.0 to 1.0
    public let duration: TimeInterval
    public let startTime: Date
    public let affectedRegions: [String]
    public let expectedImpacts: [String: Double]
    public let confidence: Double
    
    public var isActive: Bool {
        let elapsed = Date().timeIntervalSince(startTime)
        return elapsed < duration
    }
    
    public var currentIntensity: Double {
        let elapsed = Date().timeIntervalSince(startTime)
        let normalizedTime = elapsed / duration
        
        if normalizedTime >= 1.0 { return 0.0 }
        
        // Bell curve intensity over time
        let peak = 0.3 // Peak at 30% of duration
        let sigma = 0.2 // Standard deviation
        
        let x = normalizedTime - peak
        let gaussian = exp(-(x * x) / (2 * sigma * sigma))
        
        return intensity * gaussian
    }
}

public enum WeatherEventType: String, CaseIterable {
    case hurricane = "Hurricane"
    case typhoon = "Typhoon"
    case cyclone = "Cyclone"
    case tornado = "Tornado"
    case drought = "Drought"
    case flood = "Flood"
    case blizzard = "Blizzard"
    case heatwave = "Heatwave"
    case coldSnap = "Cold Snap"
    case monsoon = "Monsoon"
    case elNino = "El Niño"
    case laNina = "La Niña"
    case volcanic = "Volcanic Eruption"
    case wildfire = "Wildfire"
    case sandstorm = "Sandstorm"
    case tsunami = "Tsunami"
    case earthquake = "Earthquake"
    case other = "Other"
}

public struct WeatherImpactFactor {
    public let priceMultiplier: Double
    public let volatilityAdjustment: Double
    public let demandAdjustment: Double
    public let supplyAdjustment: Double
    public let supplyRisk: Double
    public let demandRisk: Double
    public let confidence: Double
    
    public init(priceMultiplier: Double = 1.0, volatilityAdjustment: Double = 0.0,
                demandAdjustment: Double = 1.0, supplyAdjustment: Double = 1.0,
                supplyRisk: Double = 0.2, demandRisk: Double = 0.2, confidence: Double = 0.7) {
        self.priceMultiplier = priceMultiplier
        self.volatilityAdjustment = volatilityAdjustment
        self.demandAdjustment = demandAdjustment
        self.supplyAdjustment = supplyAdjustment
        self.supplyRisk = supplyRisk
        self.demandRisk = demandRisk
        self.confidence = confidence
    }
}

public struct EventImpactFactor {
    public let priceMultiplier: Double
    public let volatilityAdjustment: Double
    public let supplyRisk: Double
    public let demandRisk: Double
    public let confidence: Double
    
    public init(priceMultiplier: Double = 1.0, volatilityAdjustment: Double = 0.0,
                supplyRisk: Double = 0.0, demandRisk: Double = 0.0, confidence: Double = 1.0) {
        self.priceMultiplier = priceMultiplier
        self.volatilityAdjustment = volatilityAdjustment
        self.supplyRisk = supplyRisk
        self.demandRisk = demandRisk
        self.confidence = confidence
    }
}

public struct GlobalWeatherData {
    public let timestamp: Date
    public let regionalConditions: [String: RegionalWeatherConditions]
    public let globalTemperatureAnomaly: Double
    public let globalPrecipitationAnomaly: Double
    public let oceanTemperatures: [String: Double]
    public let atmosphericPressure: [String: Double]
    
    public init(timestamp: Date = Date()) {
        self.timestamp = timestamp
        self.regionalConditions = [:]
        self.globalTemperatureAnomaly = 0.0
        self.globalPrecipitationAnomaly = 0.0
        self.oceanTemperatures = [:]
        self.atmosphericPressure = [:]
    }
}

public struct RegionalWeatherConditions {
    public let region: String
    public let temperature: Double // Celsius
    public let precipitation: Double // mm/day
    public let windSpeed: Double // km/h
    public let humidity: Double // 0.0 to 1.0
    public let pressure: Double // hPa
    public let cloudCover: Double // 0.0 to 1.0
    public let visibility: Double // km
    public let uvIndex: Double // 0-11+
    public let dewPoint: Double // Celsius
    public let feelsLike: Double // Celsius
    
    public init(region: String, temperature: Double = 20.0, precipitation: Double = 0.0,
                windSpeed: Double = 10.0, humidity: Double = 0.5, pressure: Double = 1013.25,
                cloudCover: Double = 0.5, visibility: Double = 10.0, uvIndex: Double = 5.0,
                dewPoint: Double = 15.0, feelsLike: Double = 20.0) {
        self.region = region
        self.temperature = temperature
        self.precipitation = precipitation
        self.windSpeed = windSpeed
        self.humidity = humidity
        self.pressure = pressure
        self.cloudCover = cloudCover
        self.visibility = visibility
        self.uvIndex = uvIndex
        self.dewPoint = dewPoint
        self.feelsLike = feelsLike
    }
}

// MARK: - Climate Models

public struct ClimateProjections {
    public let baseYear: Int
    public let projectionYear: Int
    public let scenario: ClimateScenario
    public let regionalProjections: [String: RegionalClimateProjection]
    public let globalProjection: GlobalClimateProjection
    public let confidence: Double
    
    public init(baseYear: Int = 2024, projectionYear: Int = 2050, scenario: ClimateScenario = .moderate) {
        self.baseYear = baseYear
        self.projectionYear = projectionYear
        self.scenario = scenario
        self.regionalProjections = [:]
        self.globalProjection = GlobalClimateProjection()
        self.confidence = 0.7
    }
}

public enum ClimateScenario: String, CaseIterable {
    case optimistic = "Optimistic (1.5°C)"
    case moderate = "Moderate (2.0°C)"
    case pessimistic = "Pessimistic (3.0°C)"
    case extreme = "Extreme (4.0°C+)"
}

public struct RegionalClimateProjection {
    public let region: String
    public let temperatureChange: Double // °C change
    public let precipitationChange: Double // % change
    public let seaLevelChange: Double // cm change
    public let extremeWeatherFrequency: Double // multiplier
    public let timeHorizon: Int // years
    
    public init(region: String, temperatureChange: Double = 2.0, precipitationChange: Double = 0.1,
                seaLevelChange: Double = 20.0, extremeWeatherFrequency: Double = 1.5, timeHorizon: Int = 30) {
        self.region = region
        self.temperatureChange = temperatureChange
        self.precipitationChange = precipitationChange
        self.seaLevelChange = seaLevelChange
        self.extremeWeatherFrequency = extremeWeatherFrequency
        self.timeHorizon = timeHorizon
    }
}

public struct GlobalClimateProjection {
    public let globalTemperatureChange: Double
    public let oceanAcidification: Double
    public let arcticIceReduction: Double
    public let forestCoverChange: Double
    public let desertificationRate: Double
    
    public init(globalTemperatureChange: Double = 2.0, oceanAcidification: Double = 0.3,
                arcticIceReduction: Double = 0.5, forestCoverChange: Double = -0.2,
                desertificationRate: Double = 0.1) {
        self.globalTemperatureChange = globalTemperatureChange
        self.oceanAcidification = oceanAcidification
        self.arcticIceReduction = arcticIceReduction
        self.forestCoverChange = forestCoverChange
        self.desertificationRate = desertificationRate
    }
}

public struct ClimateImpact {
    public let temperatureChange: Double
    public let precipitationChange: Double
    public let seaLevelChange: Double
    public let extremeWeatherFrequency: Double
    public let agriculturalProductivity: Double
    public let energyDemand: Double
    public let infrastructureStress: Double
    public let timeHorizon: Int
    
    public init(temperatureChange: Double = 0.0, precipitationChange: Double = 0.0,
                seaLevelChange: Double = 0.0, extremeWeatherFrequency: Double = 1.0,
                agriculturalProductivity: Double = 1.0, energyDemand: Double = 1.0,
                infrastructureStress: Double = 0.0, timeHorizon: Int = 30) {
        self.temperatureChange = temperatureChange
        self.precipitationChange = precipitationChange
        self.seaLevelChange = seaLevelChange
        self.extremeWeatherFrequency = extremeWeatherFrequency
        self.agriculturalProductivity = agriculturalProductivity
        self.energyDemand = energyDemand
        self.infrastructureStress = infrastructureStress
        self.timeHorizon = timeHorizon
    }
}

// MARK: - Regional and Seasonal Patterns

public struct RegionalSeasonalPattern {
    public let region: String
    public let hemisphere: Hemisphere
    public let climateZones: [ClimateZone]
    public let temperatureRange: (min: Double, max: Double)
    public let precipitationRange: (min: Double, max: Double)
    public var seasonalCommodityPatterns: [String: CommoditySeasonalPattern]
    public let majorWeatherPatterns: [WeatherPatternType]
    public let agriculturalZones: [AgriculturalZone]
    
    public init(region: String, hemisphere: Hemisphere, climateZones: [ClimateZone],
                temperatureRange: (Double, Double), precipitationRange: (Double, Double),
                seasonalCommodityPatterns: [String: CommoditySeasonalPattern],
                majorWeatherPatterns: [WeatherPatternType],
                agriculturalZones: [AgriculturalZone]) {
        self.region = region
        self.hemisphere = hemisphere
        self.climateZones = climateZones
        self.temperatureRange = temperatureRange
        self.precipitationRange = precipitationRange
        self.seasonalCommodityPatterns = seasonalCommodityPatterns
        self.majorWeatherPatterns = majorWeatherPatterns
        self.agriculturalZones = agriculturalZones
    }
    
    public func getTemperatureFactor(for date: Date) -> Double {
        let month = Calendar.current.component(.month, from: date)
        let season = getSeason(for: month, hemisphere: hemisphere)
        
        switch season {
        case .winter: return 0.3
        case .spring: return 0.7
        case .summer: return 1.0
        case .autumn: return 0.6
        }
    }
    
    public func getPrecipitationFactor(for date: Date) -> Double {
        let month = Calendar.current.component(.month, from: date)
        
        // Regional precipitation patterns
        switch region {
        case "ASIA":
            // Monsoon pattern
            return [6: 2.0, 7: 2.5, 8: 2.0, 9: 1.5][month] ?? 0.5
        case "EUROPE":
            // Mediterranean and Atlantic patterns
            return [10: 1.5, 11: 1.5, 12: 1.3, 1: 1.3, 2: 1.2, 3: 1.0][month] ?? 0.8
        case "AFRICA":
            // Seasonal rainfall
            return [6: 1.8, 7: 2.0, 8: 1.8, 9: 1.5][month] ?? 0.3
        default:
            return 1.0
        }
    }
    
    public func getCommodityFactors(for date: Date) -> [String: CommoditySeasonalFactors] {
        var factors: [String: CommoditySeasonalFactors] = [:]
        
        for (commodity, pattern) in seasonalCommodityPatterns {
            factors[commodity] = pattern.getFactors(for: date, hemisphere: hemisphere)
        }
        
        return factors
    }
    
    private func getSeason(for month: Int, hemisphere: Hemisphere) -> Season {
        switch hemisphere {
        case .northern:
            switch month {
            case 12, 1, 2: return .winter
            case 3, 4, 5: return .spring
            case 6, 7, 8: return .summer
            case 9, 10, 11: return .autumn
            default: return .spring
            }
        case .southern:
            switch month {
            case 6, 7, 8: return .winter
            case 9, 10, 11: return .spring
            case 12, 1, 2: return .summer
            case 3, 4, 5: return .autumn
            default: return .spring
            }
        case .mixed:
            // Use northern hemisphere as default
            return getSeason(for: month, hemisphere: .northern)
        }
    }
}

public struct CommoditySeasonalPattern {
    public let commodity: String
    public let patternType: SeasonalPatternType
    public let monthlyMultipliers: [Int: Double] // Month -> Price multiplier
    public let volatilityPattern: [Int: Double] // Month -> Volatility adjustment
    public let supplyPattern: [Int: Double] // Month -> Supply factor
    public let demandPattern: [Int: Double] // Month -> Demand factor
    public let weatherSensitivity: WeatherSensitivity
    
    public init(commodity: String, patternType: SeasonalPatternType,
                monthlyMultipliers: [Int: Double], volatilityPattern: [Int: Double],
                supplyPattern: [Int: Double], demandPattern: [Int: Double],
                weatherSensitivity: WeatherSensitivity) {
        self.commodity = commodity
        self.patternType = patternType
        self.monthlyMultipliers = monthlyMultipliers
        self.volatilityPattern = volatilityPattern
        self.supplyPattern = supplyPattern
        self.demandPattern = demandPattern
        self.weatherSensitivity = weatherSensitivity
    }
    
    public func getFactors(for date: Date, hemisphere: Hemisphere) -> CommoditySeasonalFactors {
        let month = Calendar.current.component(.month, from: date)
        
        // Adjust for hemisphere if needed
        let adjustedMonth = hemisphere == .southern ? (month + 6) % 12 + 1 : month
        
        let priceMultiplier = monthlyMultipliers[adjustedMonth] ?? 1.0
        let volatilityAdjustment = volatilityPattern[adjustedMonth] ?? 0.0
        let supplyAdjustment = supplyPattern[adjustedMonth] ?? 1.0
        let demandAdjustment = demandPattern[adjustedMonth] ?? 1.0
        
        return CommoditySeasonalFactors(
            commodity: commodity,
            priceMultiplier: priceMultiplier,
            volatilityAdjustment: volatilityAdjustment,
            demandAdjustment: demandAdjustment,
            supplyAdjustment: supplyAdjustment,
            confidence: 0.8,
            season: getCurrentSeason(for: date, hemisphere: hemisphere),
            hemisphere: hemisphere
        )
    }
    
    private func getCurrentSeason(for date: Date, hemisphere: Hemisphere) -> Season {
        let month = Calendar.current.component(.month, from: date)
        
        switch hemisphere {
        case .northern:
            switch month {
            case 12, 1, 2: return .winter
            case 3, 4, 5: return .spring
            case 6, 7, 8: return .summer
            case 9, 10, 11: return .autumn
            default: return .spring
            }
        case .southern:
            switch month {
            case 6, 7, 8: return .winter
            case 9, 10, 11: return .spring
            case 12, 1, 2: return .summer
            case 3, 4, 5: return .autumn
            default: return .spring
            }
        case .mixed:
            return getCurrentSeason(for: date, hemisphere: .northern)
        }
    }
}

public enum SeasonalPatternType: String, CaseIterable {
    case agricultural = "Agricultural"
    case energy = "Energy"
    case stable = "Stable"
    case tropical = "Tropical"
    case temperate = "Temperate"
    case continental = "Continental"
    case arid = "Arid"
}

public struct WeatherSensitivity {
    public let temperatureSensitivity: Double // -1.0 to 1.0
    public let precipitationSensitivity: Double
    public let windSensitivity: Double
    public let extremeWeatherImpact: Double
    
    public init(temperature: Double = 0.0, precipitation: Double = 0.0,
                wind: Double = 0.0, extremeWeather: Double = 0.3) {
        self.temperatureSensitivity = temperature
        self.precipitationSensitivity = precipitation
        self.windSensitivity = wind
        self.extremeWeatherImpact = extremeWeather
    }
}

// MARK: - Agricultural Models

public struct AgriculturalZone {
    public let name: String
    public let location: CLLocationCoordinate2D
    public let climateZone: ClimateZone
    public let primaryCrops: [String]
    public let soilQuality: Double // 0.0 to 1.0
    public let waterAvailability: Double // 0.0 to 1.0
    public let infrastructureLevel: Double // 0.0 to 1.0
    public let technologyAdoption: Double // 0.0 to 1.0
    public let laborAvailability: Double // 0.0 to 1.0
    public let marketAccess: Double // 0.0 to 1.0
    
    public init(name: String, location: CLLocationCoordinate2D, climateZone: ClimateZone,
                primaryCrops: [String], soilQuality: Double = 0.7, waterAvailability: Double = 0.7,
                infrastructureLevel: Double = 0.6, technologyAdoption: Double = 0.5,
                laborAvailability: Double = 0.8, marketAccess: Double = 0.7) {
        self.name = name
        self.location = location
        self.climateZone = climateZone
        self.primaryCrops = primaryCrops
        self.soilQuality = soilQuality
        self.waterAvailability = waterAvailability
        self.infrastructureLevel = infrastructureLevel
        self.technologyAdoption = technologyAdoption
        self.laborAvailability = laborAvailability
        self.marketAccess = marketAccess
    }
    
    public var productivityIndex: Double {
        (soilQuality + waterAvailability + infrastructureLevel + 
         technologyAdoption + laborAvailability + marketAccess) / 6.0
    }
}

public struct AgriculturalCycle {
    public let region: String
    public let cropCalendar: [String: CropCycle]
    public let weatherDependencies: [String: WeatherDependency]
    public let riskFactors: [String: Double]
    
    public init(region: String) {
        self.region = region
        self.cropCalendar = [:]
        self.weatherDependencies = [:]
        self.riskFactors = [:]
    }
}

public struct CropCycle {
    public let crop: String
    public let plantingWindow: (start: Int, end: Int) // Months
    public let growingPeriod: Int // Months
    public let harvestWindow: (start: Int, end: Int) // Months
    public let criticalPeriods: [CriticalPeriod]
    public let yieldPotential: Double
    public let climateRequirements: ClimateRequirements
    
    public init(crop: String, plantingWindow: (Int, Int), growingPeriod: Int,
                harvestWindow: (Int, Int), criticalPeriods: [CriticalPeriod],
                yieldPotential: Double, climateRequirements: ClimateRequirements) {
        self.crop = crop
        self.plantingWindow = plantingWindow
        self.growingPeriod = growingPeriod
        self.harvestWindow = harvestWindow
        self.criticalPeriods = criticalPeriods
        self.yieldPotential = yieldPotential
        self.climateRequirements = climateRequirements
    }
}

public struct CriticalPeriod {
    public let stage: GrowthStage
    public let duration: Int // Days
    public let weatherRequirements: WeatherRequirements
    public let riskFactors: [String: Double]
    
    public init(stage: GrowthStage, duration: Int, weatherRequirements: WeatherRequirements,
                riskFactors: [String: Double] = [:]) {
        self.stage = stage
        self.duration = duration
        self.weatherRequirements = weatherRequirements
        self.riskFactors = riskFactors
    }
}

public enum GrowthStage: String, CaseIterable {
    case planting = "Planting"
    case germination = "Germination"
    case vegetative = "Vegetative Growth"
    case flowering = "Flowering"
    case fruitSet = "Fruit Set"
    case maturation = "Maturation"
    case harvest = "Harvest"
}

public struct WeatherRequirements {
    public let optimalTemperatureRange: (min: Double, max: Double)
    public let minimumPrecipitation: Double
    public let maximumPrecipitation: Double
    public let sunlightHours: Double
    public let windTolerance: Double
    
    public init(temperatureRange: (Double, Double), minPrecipitation: Double,
                maxPrecipitation: Double, sunlightHours: Double, windTolerance: Double) {
        self.optimalTemperatureRange = temperatureRange
        self.minimumPrecipitation = minPrecipitation
        self.maximumPrecipitation = maxPrecipitation
        self.sunlightHours = sunlightHours
        self.windTolerance = windTolerance
    }
}

public struct ClimateRequirements {
    public let annualTemperatureRange: (min: Double, max: Double)
    public let annualPrecipitation: (min: Double, max: Double)
    public let growingSeasonLength: Int // Days
    public let frostTolerance: FrostTolerance
    public let droughtTolerance: DroughtTolerance
    public let floodTolerance: FloodTolerance
    
    public init(temperatureRange: (Double, Double), precipitation: (Double, Double),
                growingSeasonLength: Int, frostTolerance: FrostTolerance = .moderate,
                droughtTolerance: DroughtTolerance = .moderate, 
                floodTolerance: FloodTolerance = .moderate) {
        self.annualTemperatureRange = temperatureRange
        self.annualPrecipitation = precipitation
        self.growingSeasonLength = growingSeasonLength
        self.frostTolerance = frostTolerance
        self.droughtTolerance = droughtTolerance
        self.floodTolerance = floodTolerance
    }
}

public enum FrostTolerance: String, CaseIterable {
    case none = "None"
    case low = "Low"
    case moderate = "Moderate"
    case high = "High"
    case extreme = "Extreme"
}

public enum DroughtTolerance: String, CaseIterable {
    case none = "None"
    case low = "Low"
    case moderate = "Moderate"
    case high = "High"
    case extreme = "Extreme"
}

public enum FloodTolerance: String, CaseIterable {
    case none = "None"
    case low = "Low"
    case moderate = "Moderate"
    case high = "High"
    case extreme = "Extreme"
}

public struct WeatherDependency {
    public let commodity: String
    public let temperatureImpact: Double
    public let precipitationImpact: Double
    public let windImpact: Double
    public let extremeWeatherImpact: Double
    public let lagEffect: TimeInterval // How long weather effects persist
    
    public init(commodity: String, temperatureImpact: Double = 0.0,
                precipitationImpact: Double = 0.0, windImpact: Double = 0.0,
                extremeWeatherImpact: Double = 0.3, lagEffect: TimeInterval = 86400 * 30) {
        self.commodity = commodity
        self.temperatureImpact = temperatureImpact
        self.precipitationImpact = precipitationImpact
        self.windImpact = windImpact
        self.extremeWeatherImpact = extremeWeatherImpact
        self.lagEffect = lagEffect
    }
}

// MARK: - Event Models

public struct EventProbabilityModel {
    public let eventType: String
    public let baseFrequency: Double // Daily probability
    public let seasonalMultipliers: [Int: Double] // Month -> multiplier
    public let climateSensitivity: Double // How much climate change affects frequency
    public let regionProbabilities: [String: Double] // Region -> probability multiplier
    public let intensityDistribution: [Double: Double] // Intensity -> probability
    public let durationRange: (min: TimeInterval, max: TimeInterval)
    public let confidenceLevel: Double
    
    public init(eventType: String, baseFrequency: Double, seasonalMultipliers: [Int: Double],
                climateSensitivity: Double, regionProbabilities: [String: Double],
                intensityDistribution: [Double: Double], durationRange: (TimeInterval, TimeInterval),
                confidenceLevel: Double) {
        self.eventType = eventType
        self.baseFrequency = baseFrequency
        self.seasonalMultipliers = seasonalMultipliers
        self.climateSensitivity = climateSensitivity
        self.regionProbabilities = regionProbabilities
        self.intensityDistribution = intensityDistribution
        self.durationRange = durationRange
        self.confidenceLevel = confidenceLevel
    }
    
    public func calculateProbability(date: Date, season: Season, 
                                   weatherConditions: GlobalWeatherData,
                                   climateFactors: ClimateFactors) -> Double {
        let month = Calendar.current.component(.month, from: date)
        let seasonalMultiplier = seasonalMultipliers[month] ?? 1.0
        let climateMultiplier = 1.0 + climateFactors.temperatureAnomaly * climateSensitivity
        
        return baseFrequency * seasonalMultiplier * climateMultiplier
    }
    
    public func generateIntensity() -> Double {
        let random = Double.random(in: 0...1)
        var cumulativeProbability = 0.0
        
        for (intensity, probability) in intensityDistribution.sorted(by: { $0.key < $1.key }) {
            cumulativeProbability += probability
            if random <= cumulativeProbability {
                return intensity
            }
        }
        
        return intensityDistribution.keys.max() ?? 0.5
    }
    
    public func generateDuration(intensity: Double) -> TimeInterval {
        let minDuration = durationRange.min
        let maxDuration = durationRange.max
        
        // Higher intensity events tend to last longer
        let intensityFactor = intensity * intensity // Square for more dramatic effect
        
        return minDuration + (maxDuration - minDuration) * intensityFactor
    }
    
    public func generateAffectedRegions(intensity: Double) -> [String] {
        var affectedRegions: [String] = []
        
        for (region, probability) in regionProbabilities {
            let adjustedProbability = probability * intensity
            if Double.random(in: 0...1) < adjustedProbability {
                affectedRegions.append(region)
            }
        }
        
        return affectedRegions.isEmpty ? [regionProbabilities.keys.randomElement() ?? "GLOBAL"] : affectedRegions
    }
    
    public func calculateExpectedImpacts(intensity: Double) -> [String: Double] {
        var impacts: [String: Double] = [:]
        
        switch eventType {
        case "DROUGHT":
            impacts["AGRICULTURAL_SUPPLY"] = -intensity * 0.5
            impacts["WATER_PRICES"] = intensity * 0.8
            impacts["ENERGY_DEMAND"] = intensity * 0.3
        case "FLOOD":
            impacts["TRANSPORTATION"] = -intensity * 0.7
            impacts["AGRICULTURAL_SUPPLY"] = -intensity * 0.4
            impacts["INFRASTRUCTURE"] = -intensity * 0.6
        case "HURRICANE", "TYPHOON", "CYCLONE":
            impacts["ENERGY_INFRASTRUCTURE"] = -intensity * 0.8
            impacts["TRANSPORTATION"] = -intensity * 0.9
            impacts["AGRICULTURAL_SUPPLY"] = -intensity * 0.3
        case "HEATWAVE":
            impacts["ENERGY_DEMAND"] = intensity * 0.6
            impacts["AGRICULTURAL_SUPPLY"] = -intensity * 0.4
            impacts["WATER_DEMAND"] = intensity * 0.5
        case "COLD_SNAP":
            impacts["ENERGY_DEMAND"] = intensity * 0.8
            impacts["TRANSPORTATION"] = -intensity * 0.3
            impacts["AGRICULTURAL_SUPPLY"] = -intensity * 0.2
        default:
            impacts["GENERAL"] = intensity * 0.3
        }
        
        return impacts
    }
}

public struct MarketEvent {
    public let id: UUID
    public let type: MarketEventType
    public let title: String
    public let description: String
    public let severity: Double // 0.0 to 1.0
    public let startTime: Date
    public let duration: TimeInterval
    public let affectedRegions: [String]
    public let affectedCommodities: [String]
    public let priceImpacts: [String: Double]
    public let supplyImpacts: [String: Double]
    public let demandImpacts: [String: Double]
    
    public var isActive: Bool {
        let elapsed = Date().timeIntervalSince(startTime)
        return elapsed < duration
    }
    
    public var remainingDuration: TimeInterval {
        let elapsed = Date().timeIntervalSince(startTime)
        return max(0, duration - elapsed)
    }
}

public enum MarketEventType: String, CaseIterable {
    case weatherEvent = "Weather Event"
    case seasonalShift = "Seasonal Shift"
    case climateEvent = "Climate Event"
    case agriculturalEvent = "Agricultural Event"
    case energyEvent = "Energy Event"
}

// MARK: - Forecasting Models

public struct SeasonalForecast {
    public let region: String
    public let predictions: [SeasonalPrediction]
    public let methodology: String
    public let lastUpdated: Date
    
    public init(region: String, predictions: [SeasonalPrediction], methodology: String, lastUpdated: Date = Date()) {
        self.region = region
        self.predictions = predictions
        self.methodology = methodology
        self.lastUpdated = lastUpdated
    }
}

public struct SeasonalPrediction {
    public let date: Date
    public let temperatureFactor: Double
    public let precipitationFactor: Double
    public let commodityFactors: [String: CommoditySeasonalFactors]
    public let eventProbabilities: [String: Double]
    public let confidence: Double
    
    public init(date: Date, temperatureFactor: Double, precipitationFactor: Double,
                commodityFactors: [String: CommoditySeasonalFactors], eventProbabilities: [String: Double],
                confidence: Double) {
        self.date = date
        self.temperatureFactor = temperatureFactor
        self.precipitationFactor = precipitationFactor
        self.commodityFactors = commodityFactors
        self.eventProbabilities = eventProbabilities
        self.confidence = confidence
    }
}

public struct SeasonalAdjustment {
    public let priceMultiplier: Double
    public let volatilityAdjustment: Double
    public let demandAdjustment: Double
    public let supplyAdjustment: Double
    public let confidence: Double
    
    public init(priceMultiplier: Double, volatilityAdjustment: Double, demandAdjustment: Double,
                supplyAdjustment: Double, confidence: Double) {
        self.priceMultiplier = priceMultiplier
        self.volatilityAdjustment = volatilityAdjustment
        self.demandAdjustment = demandAdjustment
        self.supplyAdjustment = supplyAdjustment
        self.confidence = confidence
    }
}

// MARK: - Analysis Models

public struct SeasonalAnalysis {
    public let commodity: String
    public let region: String
    public let currentFactors: CommoditySeasonalFactors
    public let weatherImpact: WeatherImpactFactor
    public let eventImpact: EventImpactFactor
    public let forecast: SeasonalForecast?
    public let recommendations: [String]
    public let riskAssessment: SeasonalRiskAssessment
    
    public init(commodity: String, region: String, currentFactors: CommoditySeasonalFactors,
                weatherImpact: WeatherImpactFactor, eventImpact: EventImpactFactor,
                forecast: SeasonalForecast?, recommendations: [String], riskAssessment: SeasonalRiskAssessment) {
        self.commodity = commodity
        self.region = region
        self.currentFactors = currentFactors
        self.weatherImpact = weatherImpact
        self.eventImpact = eventImpact
        self.forecast = forecast
        self.recommendations = recommendations
        self.riskAssessment = riskAssessment
    }
}

public struct SeasonalRiskAssessment {
    public let overallRisk: Double
    public let priceRisk: Double
    public let supplyRisk: Double
    public let demandRisk: Double
    public let volatilityRisk: Double
    public let timeHorizon: TimeInterval
    
    public init(overallRisk: Double, priceRisk: Double, supplyRisk: Double, demandRisk: Double,
                volatilityRisk: Double, timeHorizon: TimeInterval) {
        self.overallRisk = overallRisk
        self.priceRisk = priceRisk
        self.supplyRisk = supplyRisk
        self.demandRisk = demandRisk
        self.volatilityRisk = volatilityRisk
        self.timeHorizon = timeHorizon
    }
}

// MARK: - Supporting Enums

public enum Season: String, CaseIterable {
    case spring = "Spring"
    case summer = "Summer"
    case autumn = "Autumn"
    case winter = "Winter"
}

public enum Hemisphere: String, CaseIterable {
    case northern = "Northern"
    case southern = "Southern"
    case mixed = "Mixed"
}

public enum ClimateZone: String, CaseIterable {
    case tropical = "Tropical"
    case arid = "Arid"
    case temperate = "Temperate"
    case continental = "Continental"
    case polar = "Polar"
    case mediterranean = "Mediterranean"
    case savanna = "Savanna"
    case desert = "Desert"
    case tundra = "Tundra"
    case alpine = "Alpine"
    case oceanic = "Oceanic"
    case subarctic = "Subarctic"
    case arctic = "Arctic"
}

public enum WeatherPatternType: String, CaseIterable {
    case monsoon = "Monsoon"
    case hurricane = "Hurricane"
    case typhoon = "Typhoon"
    case cyclone = "Cyclone"
    case tornado = "Tornado"
    case drought = "Drought"
    case flood = "Flood"
    case blizzard = "Blizzard"
    case heatwave = "Heatwave"
    case coldSnap = "Cold Snap"
    case elNino = "El Niño"
    case laNina = "La Niña"
    case storm = "Storm"
    case sandstorm = "Sandstorm"
    case bushfire = "Bushfire"
}

// MARK: - Supporting Data Structures

public struct HemisphereData {
    public let seasonOffset: Int // Months offset from northern hemisphere
    public let temperatureBase: Double // Base temperature in Celsius
    public let precipitationBase: Double // Base precipitation factor
    
    public init(seasonOffset: Int, temperatureBase: Double, precipitationBase: Double) {
        self.seasonOffset = seasonOffset
        self.temperatureBase = temperatureBase
        self.precipitationBase = precipitationBase
    }
}

public struct ClimateFactors {
    public let temperatureAnomaly: Double
    public let precipitationAnomaly: Double
    public let seaLevelAnomaly: Double
    public let extremeWeatherIndex: Double
    public let carbonDioxideLevel: Double
    public let oceansTemperatureAnomaly: Double
    
    public init(temperatureAnomaly: Double = 0.0, precipitationAnomaly: Double = 0.0,
                seaLevelAnomaly: Double = 0.0, extremeWeatherIndex: Double = 1.0,
                carbonDioxideLevel: Double = 420.0, oceansTemperatureAnomaly: Double = 0.0) {
        self.temperatureAnomaly = temperatureAnomaly
        self.precipitationAnomaly = precipitationAnomaly
        self.seaLevelAnomaly = seaLevelAnomaly
        self.extremeWeatherIndex = extremeWeatherIndex
        self.carbonDioxideLevel = carbonDioxideLevel
        self.oceansTemperatureAnomaly = oceansTemperatureAnomaly
    }
}

// MARK: - Service Protocols

public protocol WeatherDataServiceProtocol {
    var currentWeatherData: GlobalWeatherData { get }
    var globalWeatherSummary: GlobalWeatherData { get }
    
    func getRegionalWeather(_ region: String) -> RegionalWeatherConditions
    func getProjectedWeather(for date: Date, region: String) -> RegionalWeatherConditions
}

public protocol ClimateModelingServiceProtocol {
    var climateProjections: ClimateProjections { get }
    var currentClimateFactors: ClimateFactors { get }
    
    func getProjectedFactors(for date: Date) -> ClimateFactors
}

public protocol AgriculturalCycleServiceProtocol {
    func getCycle(for region: String) -> AgriculturalCycle
}

// MARK: - Calculator Classes

public class SeasonalCalculator {
    public func calculateFactors(for date: Date, pattern: RegionalSeasonalPattern,
                               weatherData: RegionalWeatherConditions?,
                               agriculturalCycle: AgriculturalCycle) -> SeasonalFactorSet {
        var factorSet = SeasonalFactorSet(region: pattern.region, timestamp: date)
        
        // Calculate commodity factors
        for (commodity, commodityPattern) in pattern.seasonalCommodityPatterns {
            let factors = commodityPattern.getFactors(for: date, hemisphere: pattern.hemisphere)
            factorSet.commodityFactors[commodity] = factors
        }
        
        // Calculate weather factors
        if let weather = weatherData {
            factorSet.weatherFactors = calculateWeatherFactors(weather: weather, pattern: pattern)
        }
        
        // Calculate agricultural factors
        factorSet.agriculturalFactors = calculateAgriculturalFactors(cycle: agriculturalCycle, date: date)
        
        // Calculate energy factors
        factorSet.energyFactors = calculateEnergyFactors(date: date, pattern: pattern)
        
        return factorSet
    }
    
    private func calculateWeatherFactors(weather: RegionalWeatherConditions, 
                                       pattern: RegionalSeasonalPattern) -> WeatherFactors {
        var factors = WeatherFactors()
        
        // Normalize temperature relative to regional range
        let tempRange = pattern.temperatureRange.max - pattern.temperatureRange.min
        let normalizedTemp = (weather.temperature - pattern.temperatureRange.min) / tempRange
        factors.temperatureFactor = max(0.1, min(2.0, normalizedTemp))
        
        // Normalize precipitation
        let precipRange = pattern.precipitationRange.max - pattern.precipitationRange.min
        let normalizedPrecip = (weather.precipitation - pattern.precipitationRange.min) / precipRange
        factors.precipitationFactor = max(0.1, min(2.0, normalizedPrecip))
        
        // Wind factor
        factors.windFactor = min(2.0, weather.windSpeed / 20.0) // Normalize to 20 km/h baseline
        
        // Humidity factor
        factors.humidityFactor = weather.humidity
        
        // Extreme weather risk
        if weather.temperature > pattern.temperatureRange.max * 0.9 ||
           weather.temperature < pattern.temperatureRange.min * 1.1 ||
           weather.precipitation > pattern.precipitationRange.max * 0.8 ||
           weather.windSpeed > 50.0 {
            factors.extremeWeatherRisk = 0.8
        }
        
        return factors
    }
    
    private func calculateAgriculturalFactors(cycle: AgriculturalCycle, date: Date) -> AgriculturalFactors {
        var factors = AgriculturalFactors()
        let month = Calendar.current.component(.month, from: date)
        
        // Check if any crops are in critical periods
        for (_, cropCycle) in cycle.cropCalendar {
            if month >= cropCycle.plantingWindow.start && month <= cropCycle.plantingWindow.end {
                factors.plantingSeason = true
            }
            if month >= cropCycle.harvestWindow.start && month <= cropCycle.harvestWindow.end {
                factors.harvestSeason = true
            }
        }
        
        return factors
    }
    
    private func calculateEnergyFactors(date: Date, pattern: RegionalSeasonalPattern) -> EnergyFactors {
        var factors = EnergyFactors()
        let month = Calendar.current.component(.month, from: date)
        
        // Seasonal energy demand patterns
        switch pattern.hemisphere {
        case .northern:
            factors.heatingDemand = [1: 0.9, 2: 0.9, 3: 0.7, 12: 0.8][month] ?? 0.3
            factors.coolingDemand = [6: 0.8, 7: 0.9, 8: 0.9, 9: 0.6][month] ?? 0.2
        case .southern:
            factors.heatingDemand = [6: 0.8, 7: 0.9, 8: 0.8, 9: 0.6][month] ?? 0.3
            factors.coolingDemand = [12: 0.7, 1: 0.9, 2: 0.9, 3: 0.6][month] ?? 0.2
        case .mixed:
            factors.heatingDemand = 0.5
            factors.coolingDemand = 0.5
        }
        
        return factors
    }
}

public class WeatherImpactCalculator {
    public func calculateImpact(conditions: RegionalWeatherConditions,
                              seasonalPattern: RegionalSeasonalPattern?,
                              economicProfile: EconomicProfile?) -> WeatherImpactFactor {
        
        let temperatureImpact = calculateTemperatureImpact(conditions.temperature, pattern: seasonalPattern)
        let precipitationImpact = calculatePrecipitationImpact(conditions.precipitation, pattern: seasonalPattern)
        let windImpact = calculateWindImpact(conditions.windSpeed)
        
        let combinedPriceMultiplier = 1.0 + (temperatureImpact + precipitationImpact + windImpact) / 3.0
        let volatilityAdjustment = (abs(temperatureImpact) + abs(precipitationImpact) + abs(windImpact)) / 3.0
        
        return WeatherImpactFactor(
            priceMultiplier: combinedPriceMultiplier,
            volatilityAdjustment: volatilityAdjustment,
            demandAdjustment: 1.0 + temperatureImpact * 0.3,
            supplyAdjustment: 1.0 + precipitationImpact * 0.5,
            supplyRisk: max(0.0, -precipitationImpact),
            demandRisk: max(0.0, abs(temperatureImpact)),
            confidence: 0.7
        )
    }
    
    public func calculateCommodityImpact(commodity: String, weather: RegionalWeatherConditions,
                                       pattern: RegionalSeasonalPattern?) -> WeatherImpactFactor {
        
        // Commodity-specific weather sensitivity
        let sensitivity = getCommodityWeatherSensitivity(commodity)
        let baseImpact = calculateImpact(conditions: weather, seasonalPattern: pattern, economicProfile: nil)
        
        return WeatherImpactFactor(
            priceMultiplier: 1.0 + (baseImpact.priceMultiplier - 1.0) * sensitivity.temperatureSensitivity,
            volatilityAdjustment: baseImpact.volatilityAdjustment * sensitivity.extremeWeatherImpact,
            demandAdjustment: 1.0 + (baseImpact.demandAdjustment - 1.0) * abs(sensitivity.temperatureSensitivity),
            supplyAdjustment: 1.0 + (baseImpact.supplyAdjustment - 1.0) * abs(sensitivity.precipitationSensitivity),
            supplyRisk: baseImpact.supplyRisk * sensitivity.extremeWeatherImpact,
            demandRisk: baseImpact.demandRisk * abs(sensitivity.temperatureSensitivity),
            confidence: baseImpact.confidence
        )
    }
    
    private func calculateTemperatureImpact(_ temperature: Double, pattern: RegionalSeasonalPattern?) -> Double {
        guard let pattern = pattern else { return 0.0 }
        
        let midRange = (pattern.temperatureRange.min + pattern.temperatureRange.max) / 2.0
        let range = pattern.temperatureRange.max - pattern.temperatureRange.min
        
        let deviation = (temperature - midRange) / range
        return deviation * 0.3 // 30% impact maximum
    }
    
    private func calculatePrecipitationImpact(_ precipitation: Double, pattern: RegionalSeasonalPattern?) -> Double {
        guard let pattern = pattern else { return 0.0 }
        
        let midRange = (pattern.precipitationRange.min + pattern.precipitationRange.max) / 2.0
        let range = pattern.precipitationRange.max - pattern.precipitationRange.min
        
        let deviation = (precipitation - midRange) / range
        return deviation * 0.4 // 40% impact maximum
    }
    
    private func calculateWindImpact(_ windSpeed: Double) -> Double {
        // High winds generally negative for transportation and agriculture
        return min(0.2, windSpeed / 100.0) * -1.0
    }
    
    private func getCommodityWeatherSensitivity(_ commodity: String) -> WeatherSensitivity {
        switch commodity {
        case "WHEAT", "CORN", "SOYBEANS", "RICE":
            return WeatherSensitivity(temperature: 0.8, precipitation: 0.9, wind: 0.3, extremeWeather: 0.9)
        case "COFFEE", "COTTON":
            return WeatherSensitivity(temperature: 0.7, precipitation: 0.8, wind: 0.2, extremeWeather: 0.8)
        case "NATURAL_GAS", "HEATING_OIL":
            return WeatherSensitivity(temperature: 0.9, precipitation: 0.1, wind: 0.1, extremeWeather: 0.5)
        case "CRUDE_OIL":
            return WeatherSensitivity(temperature: 0.2, precipitation: 0.1, wind: 0.4, extremeWeather: 0.7)
        case "GOLD", "SILVER":
            return WeatherSensitivity(temperature: 0.0, precipitation: 0.0, wind: 0.0, extremeWeather: 0.1)
        default:
            return WeatherSensitivity(temperature: 0.3, precipitation: 0.3, wind: 0.2, extremeWeather: 0.4)
        }
    }
}

public class EventImpactCalculator {
    public func calculateCombinedImpact(events: [MarketEvent], commodity: String) -> EventImpactFactor {
        guard !events.isEmpty else {
            return EventImpactFactor()
        }
        
        var totalPriceImpact = 1.0
        var totalVolatilityAdjustment = 0.0
        var maxSupplyRisk = 0.0
        var maxDemandRisk = 0.0
        var minConfidence = 1.0
        
        for event in events {
            let eventImpact = calculateSingleEventImpact(event: event, commodity: commodity)
            
            totalPriceImpact *= eventImpact.priceMultiplier
            totalVolatilityAdjustment += eventImpact.volatilityAdjustment
            maxSupplyRisk = max(maxSupplyRisk, eventImpact.supplyRisk)
            maxDemandRisk = max(maxDemandRisk, eventImpact.demandRisk)
            minConfidence = min(minConfidence, eventImpact.confidence)
        }
        
        return EventImpactFactor(
            priceMultiplier: totalPriceImpact,
            volatilityAdjustment: totalVolatilityAdjustment,
            supplyRisk: maxSupplyRisk,
            demandRisk: maxDemandRisk,
            confidence: minConfidence
        )
    }
    
    private func calculateSingleEventImpact(event: MarketEvent, commodity: String) -> EventImpactFactor {
        let baseImpact = event.priceImpacts[commodity] ?? 0.0
        let supplyImpact = event.supplyImpacts[commodity] ?? 0.0
        let demandImpact = event.demandImpacts[commodity] ?? 0.0
        
        let priceMultiplier = 1.0 + baseImpact * event.severity
        let volatilityAdjustment = event.severity * 0.2
        let supplyRisk = max(0.0, -supplyImpact) * event.severity
        let demandRisk = abs(demandImpact) * event.severity
        
        return EventImpactFactor(
            priceMultiplier: priceMultiplier,
            volatilityAdjustment: volatilityAdjustment,
            supplyRisk: supplyRisk,
            demandRisk: demandRisk,
            confidence: 0.6
        )
    }
}

// MARK: - Service Implementations

public class WeatherDataService: WeatherDataServiceProtocol, ObservableObject {
    @Published public var currentWeatherData: GlobalWeatherData = GlobalWeatherData()
    @Published public var connectionStatus: WeatherAPIConnectionStatus = .disconnected
    @Published public var lastUpdate: Date?
    
    // API Configuration
    private let openWeatherAPIKey = "your_openweather_api_key"
    private let weatherAPIKey = "your_weatherapi_key"
    private let noaaAPIKey = "your_noaa_api_key"
    
    // Regional weather stations and monitoring points
    private let weatherStations: [String: WeatherStationConfig] = [
        "NORTH_AMERICA": WeatherStationConfig(
            cities: ["New York", "Chicago", "Los Angeles", "Dallas", "Montreal"],
            coordinates: [(40.7128, -74.0060), (41.8781, -87.6298), (34.0522, -118.2437), (32.7767, -96.7970), (45.5017, -73.5673)]
        ),
        "SOUTH_AMERICA": WeatherStationConfig(
            cities: ["São Paulo", "Buenos Aires", "Lima", "Bogotá", "Santiago"],
            coordinates: [(-23.5505, -46.6333), (-34.6118, -58.3960), (-12.0464, -77.0428), (4.7110, -74.0721), (-33.4489, -70.6693)]
        ),
        "EUROPE": WeatherStationConfig(
            cities: ["London", "Paris", "Berlin", "Rome", "Madrid"],
            coordinates: [(51.5074, -0.1278), (48.8566, 2.3522), (52.5200, 13.4050), (41.9028, 12.4964), (40.4168, -3.7038)]
        ),
        "ASIA": WeatherStationConfig(
            cities: ["Tokyo", "Shanghai", "Mumbai", "Singapore", "Seoul"],
            coordinates: [(35.6762, 139.6503), (31.2304, 121.4737), (19.0760, 72.8777), (1.3521, 103.8198), (37.5665, 126.9780)]
        ),
        "AFRICA": WeatherStationConfig(
            cities: ["Cairo", "Lagos", "Cape Town", "Nairobi", "Casablanca"],
            coordinates: [(30.0444, 31.2357), (6.5244, 3.3792), (-33.9249, 18.4241), (-1.2921, 36.8219), (33.5731, -7.5898)]
        ),
        "OCEANIA": WeatherStationConfig(
            cities: ["Sydney", "Melbourne", "Auckland", "Perth", "Brisbane"],
            coordinates: [(-33.8688, 151.2093), (-37.8136, 144.9631), (-36.8485, 174.7633), (-31.9505, 115.8605), (-27.4698, 153.0251)]
        ),
        "MIDDLE_EAST": WeatherStationConfig(
            cities: ["Dubai", "Riyadh", "Tehran", "Istanbul", "Tel Aviv"],
            coordinates: [(25.2048, 55.2708), (24.7136, 46.6753), (35.6892, 51.3890), (41.0082, 28.9784), (32.0853, 34.7818)]
        )
    ]
    
    // Rate limiting and caching
    private let rateLimiter = WeatherAPIRateLimiter(requestsPerMinute: 80)
    private let dataCache = WeatherDataCache()
    private var cancellables = Set<AnyCancellable>()
    private let updateInterval: TimeInterval = 1800 // 30 minutes for weather data
    
    public init() {
        startPeriodicUpdates()
    }
    
    private func startPeriodicUpdates() {
        Timer.publish(every: updateInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.updateAllWeatherData()
                }
            }
            .store(in: &cancellables)
    }
    
    /// Update all regional weather data
    public func updateAllWeatherData() async {
        connectionStatus = .updating
        
        var regionalConditions: [String: RegionalWeatherConditions] = [:]
        
        await withTaskGroup(of: (String, RegionalWeatherConditions?).self) { group in
            for (region, config) in weatherStations {
                group.addTask {
                    do {
                        let conditions = try await self.fetchRegionalWeather(region: region, config: config)
                        return (region, conditions)
                    } catch {
                        print("Failed to fetch weather for \(region): \(error)")
                        if let cachedConditions = self.dataCache.getCachedWeather(region) {
                            return (region, cachedConditions)
                        }
                        return (region, nil)
                    }
                }
            }
            
            for await (region, conditions) in group {
                if let conditions = conditions {
                    regionalConditions[region] = conditions
                }
            }
        }
        
        await MainActor.run {
            self.currentWeatherData = GlobalWeatherData(
                timestamp: Date(),
                globalAverageTemperature: calculateGlobalAverage(regionalConditions, \.temperature),
                globalAveragePrecipitation: calculateGlobalAverage(regionalConditions, \.precipitation),
                extremeWeatherEvents: countExtremeEvents(regionalConditions),
                regionalConditions: regionalConditions
            )
            self.lastUpdate = Date()
            self.connectionStatus = .connected
        }
        
        // Cache the data
        dataCache.cacheGlobalWeather(currentWeatherData, expiry: Date().addingTimeInterval(3600))
    }
    
    /// Fetch weather data for a specific region
    private func fetchRegionalWeather(region: String, config: WeatherStationConfig) async throws -> RegionalWeatherConditions {
        guard await rateLimiter.canMakeRequest() else {
            throw WeatherDataError.rateLimitExceeded
        }
        
        // Fetch weather data from multiple cities in the region and average
        var temperatures: [Double] = []
        var precipitations: [Double] = []
        var windSpeeds: [Double] = []
        var humidities: [Double] = []
        var pressures: [Double] = []
        var cloudCovers: [Double] = []
        
        for (city, coordinate) in zip(config.cities, config.coordinates) {
            do {
                let weather = try await fetchCityWeather(city: city, coordinate: coordinate)
                temperatures.append(weather.temperature)
                precipitations.append(weather.precipitation)
                windSpeeds.append(weather.windSpeed)
                humidities.append(weather.humidity)
                pressures.append(weather.pressure)
                cloudCovers.append(weather.cloudCover)
            } catch {
                print("Failed to fetch weather for \(city): \(error)")
            }
        }
        
        guard !temperatures.isEmpty else {
            throw WeatherDataError.noDataAvailable
        }
        
        let avgTemperature = temperatures.reduce(0, +) / Double(temperatures.count)
        let avgPrecipitation = precipitations.reduce(0, +) / Double(precipitations.count)
        let avgWindSpeed = windSpeeds.reduce(0, +) / Double(windSpeeds.count)
        let avgHumidity = humidities.reduce(0, +) / Double(humidities.count)
        let avgPressure = pressures.reduce(0, +) / Double(pressures.count)
        let avgCloudCover = cloudCovers.reduce(0, +) / Double(cloudCovers.count)
        
        return RegionalWeatherConditions(
            region: region,
            temperature: avgTemperature,
            precipitation: avgPrecipitation,
            windSpeed: avgWindSpeed,
            humidity: avgHumidity,
            pressure: avgPressure,
            cloudCover: avgCloudCover,
            visibility: 10.0, // Default visibility
            uvIndex: calculateUVIndex(temperature: avgTemperature, cloudCover: avgCloudCover),
            dewPoint: calculateDewPoint(temperature: avgTemperature, humidity: avgHumidity),
            feelsLike: calculateFeelsLike(temperature: avgTemperature, humidity: avgHumidity, windSpeed: avgWindSpeed)
        )
    }
    
    /// Fetch weather for a specific city using OpenWeatherMap API
    private func fetchCityWeather(city: String, coordinate: (Double, Double)) async throws -> CityWeatherData {
        let (lat, lon) = coordinate
        let url = URL(string: "https://api.openweathermap.org/data/2.5/weather?lat=\(lat)&lon=\(lon)&appid=\(openWeatherAPIKey)&units=metric")!
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            // Try WeatherAPI as backup
            return try await fetchCityWeatherFromWeatherAPI(city: city, coordinate: coordinate)
        }
        
        let weatherResponse = try JSONDecoder().decode(OpenWeatherMapResponse.self, from: data)
        
        return CityWeatherData(
            city: city,
            temperature: weatherResponse.main.temp,
            precipitation: weatherResponse.rain?.oneHour ?? 0.0,
            windSpeed: weatherResponse.wind.speed,
            humidity: weatherResponse.main.humidity,
            pressure: weatherResponse.main.pressure,
            cloudCover: weatherResponse.clouds.all,
            uvIndex: 0.0, // Would need separate UV API call
            visibility: weatherResponse.visibility / 1000.0 // Convert to km
        )
    }
    
    /// Backup weather API (WeatherAPI.com)
    private func fetchCityWeatherFromWeatherAPI(city: String, coordinate: (Double, Double)) async throws -> CityWeatherData {
        let (lat, lon) = coordinate
        let url = URL(string: "https://api.weatherapi.com/v1/current.json?key=\(weatherAPIKey)&q=\(lat),\(lon)")!
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw WeatherDataError.invalidResponse
        }
        
        let weatherResponse = try JSONDecoder().decode(WeatherAPIResponse.self, from: data)
        
        return CityWeatherData(
            city: city,
            temperature: weatherResponse.current.tempC,
            precipitation: weatherResponse.current.precipMM,
            windSpeed: weatherResponse.current.windKph / 3.6, // Convert to m/s
            humidity: weatherResponse.current.humidity,
            pressure: weatherResponse.current.pressureMb,
            cloudCover: weatherResponse.current.cloud,
            uvIndex: weatherResponse.current.uv,
            visibility: weatherResponse.current.visKm
        )
    }
    
    // MARK: - Weather Calculations
    
    private func calculateUVIndex(temperature: Double, cloudCover: Double) -> Double {
        // Simplified UV calculation based on temperature and cloud cover
        let baseUV = max(0, min(11, (temperature - 10) / 5)) // 0-11 scale
        let cloudFactor = 1.0 - (cloudCover / 100.0 * 0.7) // Clouds reduce UV by up to 70%
        return baseUV * cloudFactor
    }
    
    private func calculateDewPoint(temperature: Double, humidity: Double) -> Double {
        // Magnus formula approximation
        let a = 17.27
        let b = 237.7
        let alpha = ((a * temperature) / (b + temperature)) + log(humidity / 100.0)
        return (b * alpha) / (a - alpha)
    }
    
    private func calculateFeelsLike(temperature: Double, humidity: Double, windSpeed: Double) -> Double {
        // Heat index calculation for temperatures above 26.7°C (80°F)
        if temperature > 26.7 {
            let t = temperature
            let rh = humidity
            let hi = -42.379 + 2.04901523 * t + 10.14333127 * rh - 0.22475541 * t * rh -
                     0.00683783 * t * t - 0.05481717 * rh * rh + 0.00122874 * t * t * rh +
                     0.00085282 * t * rh * rh - 0.00000199 * t * t * rh * rh
            return (hi - 32) * 5/9 // Convert to Celsius
        }
        
        // Wind chill calculation for temperatures below 10°C (50°F)
        if temperature < 10 && windSpeed > 1.34 {
            let t = temperature * 9/5 + 32 // Convert to Fahrenheit
            let v = windSpeed * 2.237 // Convert to mph
            let wc = 35.74 + 0.6215 * t - 35.75 * pow(v, 0.16) + 0.4275 * t * pow(v, 0.16)
            return (wc - 32) * 5/9 // Convert back to Celsius
        }
        
        return temperature
    }
    
    private func calculateGlobalAverage<T: Numeric>(_ conditions: [String: RegionalWeatherConditions], _ keyPath: KeyPath<RegionalWeatherConditions, T>) -> Double {
        let values = conditions.values.map { Double(exactly: $0[keyPath: keyPath]) ?? 0.0 }
        return values.isEmpty ? 0.0 : values.reduce(0, +) / Double(values.count)
    }
    
    private func countExtremeEvents(_ conditions: [String: RegionalWeatherConditions]) -> Int {
        var extremeCount = 0
        
        for condition in conditions.values {
            // Count extreme temperatures
            if condition.temperature > 35 || condition.temperature < -20 {
                extremeCount += 1
            }
            
            // Count extreme precipitation
            if condition.precipitation > 50 {
                extremeCount += 1
            }
            
            // Count extreme wind
            if condition.windSpeed > 20 {
                extremeCount += 1
            }
        }
        
        return extremeCount
    }
    
    // MARK: - Public Interface
    
    public var globalWeatherSummary: GlobalWeatherData {
        currentWeatherData
    }
    
    public func getRegionalWeather(_ region: String) -> RegionalWeatherConditions {
        return currentWeatherData.regionalConditions[region] ?? RegionalWeatherConditions(region: region)
    }
    
    public func getProjectedWeather(for date: Date, region: String) -> RegionalWeatherConditions {
        let current = getRegionalWeather(region)
        let daysDiff = date.timeIntervalSinceNow / 86400
        
        // Use simplified climate models for projection
        let seasonalFactor = getSeasonalVariation(for: date, region: region)
        let climateChangeFactor = getClimateChangeProjection(yearsAhead: daysDiff / 365.25)
        
        let tempVariation = seasonalFactor.temperature + climateChangeFactor.temperature
        let precipVariation = seasonalFactor.precipitation + climateChangeFactor.precipitation
        
        return RegionalWeatherConditions(
            region: region,
            temperature: current.temperature + tempVariation,
            precipitation: max(0, current.precipitation + precipVariation),
            windSpeed: current.windSpeed + seasonalFactor.wind,
            humidity: current.humidity,
            pressure: current.pressure,
            cloudCover: current.cloudCover,
            visibility: current.visibility,
            uvIndex: current.uvIndex,
            dewPoint: current.dewPoint,
            feelsLike: current.feelsLike + tempVariation
        )
    }
    
    private func getSeasonalVariation(for date: Date, region: String) -> (temperature: Double, precipitation: Double, wind: Double) {
        let month = Calendar.current.component(.month, from: date)
        let currentMonth = Calendar.current.component(.month, from: Date())
        let monthDiff = month - currentMonth
        
        // Simplified seasonal variation
        let tempVariation = sin(Double(monthDiff) * .pi / 6) * 5.0 // ±5°C seasonal variation
        let precipVariation = cos(Double(monthDiff) * .pi / 6) * 20.0 // ±20mm seasonal variation
        let windVariation = sin(Double(monthDiff) * .pi / 3) * 2.0 // ±2 m/s seasonal variation
        
        return (tempVariation, precipVariation, windVariation)
    }
    
    private func getClimateChangeProjection(yearsAhead: Double) -> (temperature: Double, precipitation: Double) {
        // IPCC climate projections simplified
        let tempIncrease = yearsAhead * 0.02 // 0.02°C per year warming
        let precipChange = yearsAhead * 0.1 // Slight precipitation increase
        
        return (tempIncrease, precipChange)
    }
    
    /// Force refresh weather data
    public func forceRefresh() async {
        await updateAllWeatherData()
    }
}

public class ClimateModelingService: ClimateModelingServiceProtocol, ObservableObject {
    @Published public var climateProjections: ClimateProjections = ClimateProjections()
    
    public var currentClimateFactors: ClimateFactors {
        ClimateFactors()
    }
    
    public func getProjectedFactors(for date: Date) -> ClimateFactors {
        let yearsAhead = Calendar.current.dateComponents([.year], from: Date(), to: date).year ?? 0
        
        return ClimateFactors(
            temperatureAnomaly: Double(yearsAhead) * 0.02, // 0.02°C per year
            precipitationAnomaly: Double(yearsAhead) * 0.001,
            seaLevelAnomaly: Double(yearsAhead) * 0.33, // 3.3mm per year
            extremeWeatherIndex: 1.0 + Double(yearsAhead) * 0.01,
            carbonDioxideLevel: 420.0 + Double(yearsAhead) * 2.0
        )
    }
}

public class AgriculturalCycleService: AgriculturalCycleServiceProtocol {
    private var cachedCycles: [String: AgriculturalCycle] = [:]
    
    public func getCycle(for region: String) -> AgriculturalCycle {
        if let cached = cachedCycles[region] {
            return cached
        }
        
        let cycle = AgriculturalCycle(region: region)
        cachedCycles[region] = cycle
        return cycle
    }
}

// MARK: - Supporting Types

public struct EconomicProfile {
    public let gdpPerCapita: Double
    public let agriculturalShare: Double
    public let industrialShare: Double
    public let servicesShare: Double
    public let tradeOpenness: Double
    
    public init(gdpPerCapita: Double, agriculturalShare: Double, industrialShare: Double,
                servicesShare: Double, tradeOpenness: Double) {
        self.gdpPerCapita = gdpPerCapita
        self.agriculturalShare = agriculturalShare
        self.industrialShare = industrialShare
        self.servicesShare = servicesShare
        self.tradeOpenness = tradeOpenness
    }
}

// MARK: - Weather API Models and Infrastructure

public enum WeatherAPIConnectionStatus {
    case connected, disconnected, updating, error(String)
}

public enum WeatherDataError: Error {
    case rateLimitExceeded
    case invalidResponse
    case noDataAvailable
    case networkError
}

public struct WeatherStationConfig {
    public let cities: [String]
    public let coordinates: [(Double, Double)]
    
    public init(cities: [String], coordinates: [(Double, Double)]) {
        self.cities = cities
        self.coordinates = coordinates
    }
}

public struct CityWeatherData {
    public let city: String
    public let temperature: Double
    public let precipitation: Double
    public let windSpeed: Double
    public let humidity: Double
    public let pressure: Double
    public let cloudCover: Double
    public let uvIndex: Double
    public let visibility: Double
    
    public init(city: String, temperature: Double, precipitation: Double, windSpeed: Double,
                humidity: Double, pressure: Double, cloudCover: Double, uvIndex: Double, visibility: Double) {
        self.city = city
        self.temperature = temperature
        self.precipitation = precipitation
        self.windSpeed = windSpeed
        self.humidity = humidity
        self.pressure = pressure
        self.cloudCover = cloudCover
        self.uvIndex = uvIndex
        self.visibility = visibility
    }
}

// MARK: - OpenWeatherMap API Models

public struct OpenWeatherMapResponse: Codable {
    public let main: OWMMain
    public let wind: OWMWind
    public let clouds: OWMClouds
    public let rain: OWMRain?
    public let visibility: Double
}

public struct OWMMain: Codable {
    public let temp: Double
    public let humidity: Double
    public let pressure: Double
}

public struct OWMWind: Codable {
    public let speed: Double
}

public struct OWMClouds: Codable {
    public let all: Double
}

public struct OWMRain: Codable {
    public let oneHour: Double
    
    private enum CodingKeys: String, CodingKey {
        case oneHour = "1h"
    }
}

// MARK: - WeatherAPI.com Models

public struct WeatherAPIResponse: Codable {
    public let current: WeatherAPICurrent
}

public struct WeatherAPICurrent: Codable {
    public let tempC: Double
    public let precipMM: Double
    public let windKph: Double
    public let humidity: Double
    public let pressureMb: Double
    public let cloud: Double
    public let uv: Double
    public let visKm: Double
    
    private enum CodingKeys: String, CodingKey {
        case tempC = "temp_c"
        case precipMM = "precip_mm"
        case windKph = "wind_kph"
        case humidity = "humidity"
        case pressureMb = "pressure_mb"
        case cloud = "cloud"
        case uv = "uv"
        case visKm = "vis_km"
    }
}

// MARK: - Weather Rate Limiter and Cache

public class WeatherAPIRateLimiter {
    private let requestsPerMinute: Int
    private var requestTimes: [Date] = []
    private let queue = DispatchQueue(label: "weather_rate_limiter")
    
    public init(requestsPerMinute: Int) {
        self.requestsPerMinute = requestsPerMinute
    }
    
    public func canMakeRequest() async -> Bool {
        return await withCheckedContinuation { continuation in
            queue.async {
                let now = Date()
                let oneMinuteAgo = now.addingTimeInterval(-60)
                
                self.requestTimes = self.requestTimes.filter { $0 > oneMinuteAgo }
                
                if self.requestTimes.count < self.requestsPerMinute {
                    self.requestTimes.append(now)
                    continuation.resume(returning: true)
                } else {
                    continuation.resume(returning: false)
                }
            }
        }
    }
}

public class WeatherDataCache {
    private var globalWeatherCache: (data: GlobalWeatherData, expiry: Date)?
    private var regionalWeatherCache: [String: (data: RegionalWeatherConditions, expiry: Date)] = [:]
    private var hitCount = 0
    private var missCount = 0
    
    public func cacheGlobalWeather(_ data: GlobalWeatherData, expiry: Date) {
        globalWeatherCache = (data, expiry)
    }
    
    public func getCachedGlobalWeather() -> GlobalWeatherData? {
        guard let cache = globalWeatherCache, cache.expiry > Date() else {
            missCount += 1
            return nil
        }
        hitCount += 1
        return cache.data
    }
    
    public func cacheWeather(_ region: String, _ data: RegionalWeatherConditions, expiry: Date) {
        regionalWeatherCache[region] = (data, expiry)
    }
    
    public func getCachedWeather(_ region: String) -> RegionalWeatherConditions? {
        guard let cache = regionalWeatherCache[region], cache.expiry > Date() else {
            missCount += 1
            return nil
        }
        hitCount += 1
        return cache.data
    }
    
    public func getHitRate() -> Double {
        let total = hitCount + missCount
        return total > 0 ? Double(hitCount) / Double(total) : 0.0
    }
}

// MARK: - Helper Functions for Regional Patterns and Agricultural Zones

/// Helper functions for creating agricultural zones for different regions
public func createNorthAmericaAgZones() -> [AgriculturalZone] {
    return [
        AgriculturalZone(
            name: "Corn Belt",
            primaryCrops: ["CORN", "SOYBEANS"],
            coordinates: (42.0, -94.0),
            area: 500000, // km²
            soilQuality: 0.9,
            irrigationType: .rainfed,
            mechanizationLevel: 0.95,
            climaticRequirements: ClimateRequirements(
                temperatureRange: (10, 30),
                precipitation: (500, 1200),
                growingSeasonLength: 180
            ),
            seasonalPatterns: [
                .spring: SeasonalPattern(
                    temperatureFactor: 0.8,
                    precipitationFactor: 1.2,
                    activityLevel: 0.9 // High planting activity
                ),
                .summer: SeasonalPattern(
                    temperatureFactor: 1.2,
                    precipitationFactor: 1.0,
                    activityLevel: 0.7 // Growing season
                ),
                .autumn: SeasonalPattern(
                    temperatureFactor: 0.9,
                    precipitationFactor: 0.8,
                    activityLevel: 1.0 // Harvest season
                ),
                .winter: SeasonalPattern(
                    temperatureFactor: 0.3,
                    precipitationFactor: 0.6,
                    activityLevel: 0.1 // Dormant season
                )
            ]
        ),
        AgriculturalZone(
            name: "Great Plains",
            primaryCrops: ["WHEAT", "CORN", "SORGHUM"],
            coordinates: (39.0, -101.0),
            area: 750000,
            soilQuality: 0.8,
            irrigationType: .mixed,
            mechanizationLevel: 0.92,
            climaticRequirements: ClimateRequirements(
                temperatureRange: (5, 35),
                precipitation: (300, 800),
                growingSeasonLength: 160
            ),
            seasonalPatterns: [
                .spring: SeasonalPattern(temperatureFactor: 0.7, precipitationFactor: 1.1, activityLevel: 0.8),
                .summer: SeasonalPattern(temperatureFactor: 1.3, precipitationFactor: 0.9, activityLevel: 0.6),
                .autumn: SeasonalPattern(temperatureFactor: 0.8, precipitationFactor: 0.7, activityLevel: 0.9),
                .winter: SeasonalPattern(temperatureFactor: 0.2, precipitationFactor: 0.5, activityLevel: 0.1)
            ]
        )
    ]
}

public func createSouthAmericaAgZones() -> [AgriculturalZone] {
    return [
        AgriculturalZone(
            name: "Pampas",
            primaryCrops: ["SOYBEANS", "WHEAT", "CORN", "BEEF"],
            coordinates: (-34.0, -64.0),
            area: 600000,
            soilQuality: 0.95,
            irrigationType: .rainfed,
            mechanizationLevel: 0.85,
            climaticRequirements: ClimateRequirements(
                temperatureRange: (8, 28),
                precipitation: (600, 1000),
                growingSeasonLength: 200
            ),
            seasonalPatterns: [
                .spring: SeasonalPattern(temperatureFactor: 0.9, precipitationFactor: 1.0, activityLevel: 0.8),
                .summer: SeasonalPattern(temperatureFactor: 1.1, precipitationFactor: 1.2, activityLevel: 0.9),
                .autumn: SeasonalPattern(temperatureFactor: 1.0, precipitationFactor: 0.9, activityLevel: 0.95),
                .winter: SeasonalPattern(temperatureFactor: 0.6, precipitationFactor: 0.7, activityLevel: 0.3)
            ]
        )
    ]
}

public func createEuropeAgZones() -> [AgriculturalZone] {
    return [
        AgriculturalZone(
            name: "European Plain",
            primaryCrops: ["WHEAT", "BARLEY", "RAPESEED", "SUGAR_BEET"],
            coordinates: (52.0, 19.0),
            area: 400000,
            soilQuality: 0.85,
            irrigationType: .rainfed,
            mechanizationLevel: 0.98,
            climaticRequirements: ClimateRequirements(
                temperatureRange: (2, 25),
                precipitation: (400, 800),
                growingSeasonLength: 170
            ),
            seasonalPatterns: [
                .spring: SeasonalPattern(temperatureFactor: 0.7, precipitationFactor: 1.0, activityLevel: 0.9),
                .summer: SeasonalPattern(temperatureFactor: 1.0, precipitationFactor: 0.8, activityLevel: 0.7),
                .autumn: SeasonalPattern(temperatureFactor: 0.8, precipitationFactor: 1.1, activityLevel: 0.95),
                .winter: SeasonalPattern(temperatureFactor: 0.3, precipitationFactor: 0.9, activityLevel: 0.2)
            ]
        )
    ]
}

public func createAsiaAgZones() -> [AgriculturalZone] {
    return [
        AgriculturalZone(
            name: "Southeast Asian Rice Belt",
            primaryCrops: ["RICE", "PALM_OIL", "RUBBER"],
            coordinates: (14.0, 101.0),
            area: 300000,
            soilQuality: 0.8,
            irrigationType: .irrigated,
            mechanizationLevel: 0.65,
            climaticRequirements: ClimateRequirements(
                temperatureRange: (20, 35),
                precipitation: (1200, 2500),
                growingSeasonLength: 365
            ),
            seasonalPatterns: [
                .spring: SeasonalPattern(temperatureFactor: 1.0, precipitationFactor: 0.8, activityLevel: 0.8),
                .summer: SeasonalPattern(temperatureFactor: 1.1, precipitationFactor: 1.5, activityLevel: 0.9),
                .autumn: SeasonalPattern(temperatureFactor: 1.0, precipitationFactor: 1.2, activityLevel: 0.95),
                .winter: SeasonalPattern(temperatureFactor: 0.9, precipitationFactor: 0.6, activityLevel: 0.7)
            ]
        )
    ]
}

public func createAfricaAgZones() -> [AgriculturalZone] {
    return [
        AgriculturalZone(
            name: "Sub-Saharan Savanna",
            primaryCrops: ["MAIZE", "COTTON", "COFFEE", "COCOA"],
            coordinates: (0.0, 15.0),
            area: 800000,
            soilQuality: 0.6,
            irrigationType: .rainfed,
            mechanizationLevel: 0.3,
            climaticRequirements: ClimateRequirements(
                temperatureRange: (18, 40),
                precipitation: (400, 1500),
                growingSeasonLength: 240
            ),
            seasonalPatterns: [
                .spring: SeasonalPattern(temperatureFactor: 1.0, precipitationFactor: 0.5, activityLevel: 0.6),
                .summer: SeasonalPattern(temperatureFactor: 1.1, precipitationFactor: 1.8, activityLevel: 0.9),
                .autumn: SeasonalPattern(temperatureFactor: 1.0, precipitationFactor: 1.0, activityLevel: 0.8),
                .winter: SeasonalPattern(temperatureFactor: 0.9, precipitationFactor: 0.2, activityLevel: 0.4)
            ]
        )
    ]
}

public func createOceaniaAgZones() -> [AgriculturalZone] {
    return [
        AgriculturalZone(
            name: "Australian Wheat Belt",
            primaryCrops: ["WHEAT", "BARLEY", "WOOL", "BEEF"],
            coordinates: (-31.0, 117.0),
            area: 450000,
            soilQuality: 0.7,
            irrigationType: .rainfed,
            mechanizationLevel: 0.95,
            climaticRequirements: ClimateRequirements(
                temperatureRange: (8, 35),
                precipitation: (250, 600),
                growingSeasonLength: 150,
                droughtTolerance: .high
            ),
            seasonalPatterns: [
                .spring: SeasonalPattern(temperatureFactor: 0.8, precipitationFactor: 1.2, activityLevel: 0.9),
                .summer: SeasonalPattern(temperatureFactor: 1.3, precipitationFactor: 0.6, activityLevel: 0.5),
                .autumn: SeasonalPattern(temperatureFactor: 1.0, precipitationFactor: 0.8, activityLevel: 0.9),
                .winter: SeasonalPattern(temperatureFactor: 0.6, precipitationFactor: 1.1, activityLevel: 0.3)
            ]
        )
    ]
}

public func createMiddleEastAgZones() -> [AgriculturalZone] {
    return [
        AgriculturalZone(
            name: "Fertile Crescent",
            primaryCrops: ["WHEAT", "BARLEY", "DATES", "OLIVES"],
            coordinates: (35.0, 40.0),
            area: 150000,
            soilQuality: 0.75,
            irrigationType: .irrigated,
            mechanizationLevel: 0.7,
            climaticRequirements: ClimateRequirements(
                temperatureRange: (10, 45),
                precipitation: (200, 600),
                growingSeasonLength: 200,
                droughtTolerance: .extreme
            ),
            seasonalPatterns: [
                .spring: SeasonalPattern(temperatureFactor: 0.8, precipitationFactor: 1.5, activityLevel: 0.9),
                .summer: SeasonalPattern(temperatureFactor: 1.4, precipitationFactor: 0.1, activityLevel: 0.4),
                .autumn: SeasonalPattern(temperatureFactor: 1.0, precipitationFactor: 0.8, activityLevel: 0.8),
                .winter: SeasonalPattern(temperatureFactor: 0.5, precipitationFactor: 1.2, activityLevel: 0.6)
            ]
        )
    ]
}

/// Helper functions for creating commodity seasonal patterns

public func createWheatPattern(_ hemisphere: Hemisphere) -> CommoditySeasonalPattern {
    let seasonOffset = hemisphere == .southern ? 6 : 0
    return CommoditySeasonalPattern(
        commodity: "WHEAT",
        seasonalFactors: [
            adjustMonth(3, offset: seasonOffset): CommoditySeasonalFactors(commodity: "WHEAT", priceMultiplier: 1.1, demandAdjustment: 1.2), // Planting season
            adjustMonth(6, offset: seasonOffset): CommoditySeasonalFactors(commodity: "WHEAT", priceMultiplier: 0.9, supplyAdjustment: 1.3), // Growing season
            adjustMonth(9, offset: seasonOffset): CommoditySeasonalFactors(commodity: "WHEAT", priceMultiplier: 0.8, supplyAdjustment: 1.5), // Harvest
            adjustMonth(12, offset: seasonOffset): CommoditySeasonalFactors(commodity: "WHEAT", priceMultiplier: 1.0, demandAdjustment: 1.1) // Storage season
        ],
        weatherDependencies: [
            WeatherDependency(commodity: "WHEAT", temperatureImpact: 0.3, precipitationImpact: 0.4, extremeWeatherImpact: 0.6)
        ]
    )
}

public func createCornPattern(_ hemisphere: Hemisphere) -> CommoditySeasonalPattern {
    let seasonOffset = hemisphere == .southern ? 6 : 0
    return CommoditySeasonalPattern(
        commodity: "CORN",
        seasonalFactors: [
            adjustMonth(4, offset: seasonOffset): CommoditySeasonalFactors(commodity: "CORN", priceMultiplier: 1.15, demandAdjustment: 1.25),
            adjustMonth(7, offset: seasonOffset): CommoditySeasonalFactors(commodity: "CORN", priceMultiplier: 0.85, supplyAdjustment: 1.4),
            adjustMonth(10, offset: seasonOffset): CommoditySeasonalFactors(commodity: "CORN", priceMultiplier: 0.75, supplyAdjustment: 1.6),
            adjustMonth(1, offset: seasonOffset): CommoditySeasonalFactors(commodity: "CORN", priceMultiplier: 1.05, demandAdjustment: 1.15)
        ],
        weatherDependencies: [
            WeatherDependency(commodity: "CORN", temperatureImpact: 0.35, precipitationImpact: 0.5, extremeWeatherImpact: 0.7)
        ]
    )
}

public func createSoybeansPattern(_ hemisphere: Hemisphere) -> CommoditySeasonalPattern {
    let seasonOffset = hemisphere == .southern ? 6 : 0
    return CommoditySeasonalPattern(
        commodity: "SOYBEANS",
        seasonalFactors: [
            adjustMonth(5, offset: seasonOffset): CommoditySeasonalFactors(commodity: "SOYBEANS", priceMultiplier: 1.12, demandAdjustment: 1.2),
            adjustMonth(8, offset: seasonOffset): CommoditySeasonalFactors(commodity: "SOYBEANS", priceMultiplier: 0.88, supplyAdjustment: 1.35),
            adjustMonth(11, offset: seasonOffset): CommoditySeasonalFactors(commodity: "SOYBEANS", priceMultiplier: 0.82, supplyAdjustment: 1.5),
            adjustMonth(2, offset: seasonOffset): CommoditySeasonalFactors(commodity: "SOYBEANS", priceMultiplier: 1.08, demandAdjustment: 1.18)
        ],
        weatherDependencies: [
            WeatherDependency(commodity: "SOYBEANS", temperatureImpact: 0.3, precipitationImpact: 0.45, extremeWeatherImpact: 0.65)
        ]
    )
}

public func createNaturalGasPattern(_ hemisphere: Hemisphere) -> CommoditySeasonalPattern {
    return CommoditySeasonalPattern(
        commodity: "NATURAL_GAS",
        seasonalFactors: [
            1: CommoditySeasonalFactors(commodity: "NATURAL_GAS", priceMultiplier: 1.3, demandAdjustment: 1.4), // Winter heating
            4: CommoditySeasonalFactors(commodity: "NATURAL_GAS", priceMultiplier: 0.9, demandAdjustment: 0.8), // Spring low demand
            7: CommoditySeasonalFactors(commodity: "NATURAL_GAS", priceMultiplier: 1.1, demandAdjustment: 1.15), // Summer cooling
            10: CommoditySeasonalFactors(commodity: "NATURAL_GAS", priceMultiplier: 1.2, demandAdjustment: 1.25) // Pre-winter buildup
        ],
        weatherDependencies: [
            WeatherDependency(commodity: "NATURAL_GAS", temperatureImpact: 0.6, extremeWeatherImpact: 0.8)
        ]
    )
}

public func createHeatingOilPattern(_ hemisphere: Hemisphere) -> CommoditySeasonalPattern {
    return CommoditySeasonalPattern(
        commodity: "HEATING_OIL",
        seasonalFactors: [
            12: CommoditySeasonalFactors(commodity: "HEATING_OIL", priceMultiplier: 1.25, demandAdjustment: 1.35),
            3: CommoditySeasonalFactors(commodity: "HEATING_OIL", priceMultiplier: 0.85, demandAdjustment: 0.75),
            6: CommoditySeasonalFactors(commodity: "HEATING_OIL", priceMultiplier: 0.9, demandAdjustment: 0.8),
            9: CommoditySeasonalFactors(commodity: "HEATING_OIL", priceMultiplier: 1.1, demandAdjustment: 1.15)
        ],
        weatherDependencies: [
            WeatherDependency(commodity: "HEATING_OIL", temperatureImpact: 0.7, extremeWeatherImpact: 0.9)
        ]
    )
}

private func adjustMonth(_ month: Int, offset: Int) -> Int {
    let adjusted = month + offset
    return adjusted > 12 ? adjusted - 12 : (adjusted < 1 ? adjusted + 12 : adjusted)
}