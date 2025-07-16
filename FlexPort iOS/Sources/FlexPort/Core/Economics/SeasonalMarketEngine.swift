import Foundation
import Combine
import CoreLocation

/// Advanced seasonal market fluctuations engine with regional variations and climate-based modeling
public class SeasonalMarketEngine: ObservableObject {
    @Published public var currentSeasonalFactors: [String: SeasonalFactorSet] = [:]
    @Published public var weatherEvents: [WeatherEvent] = []
    @Published public var seasonalForecasts: [String: SeasonalForecast] = [:]
    @Published public var climateImpacts: [String: ClimateImpact] = [:]
    
    // Regional seasonal patterns
    private var regionalPatterns: [String: RegionalSeasonalPattern] = [:]
    private var hemisphereAdjustments: [String: HemisphereData] = [:]
    
    // Weather and climate services
    private let weatherDataService = WeatherDataService()
    private let climateModelingService = ClimateModelingService()
    private let agriculturalCycleService = AgriculturalCycleService()
    
    // Event generation and tracking
    private var eventProbabilityModels: [String: EventProbabilityModel] = [:]
    private var activeEvents: [MarketEvent] = []
    private var eventHistory: [MarketEvent] = []
    
    // Calculation engines
    private let seasonalCalculator = SeasonalCalculator()
    private let weatherImpactCalculator = WeatherImpactCalculator()
    private let eventImpactCalculator = EventImpactCalculator()
    
    private var cancellables = Set<AnyCancellable>()
    private let updateInterval: TimeInterval = 3600 // Update every hour
    
    public init() {
        initializeSeasonalPatterns()
        initializeEventModels()
        setupWeatherSubscriptions()
        startSeasonalUpdates()
    }
    
    // MARK: - Initialization
    
    private func initializeSeasonalPatterns() {
        regionalPatterns = [
            "NORTH_AMERICA": createNorthAmericaPattern(),
            "SOUTH_AMERICA": createSouthAmericaPattern(),
            "EUROPE": createEuropePattern(),
            "ASIA": createAsiaPattern(),
            "AFRICA": createAfricaPattern(),
            "OCEANIA": createOceaniaPattern(),
            "MIDDLE_EAST": createMiddleEastPattern()
        ]
        
        hemisphereAdjustments = [
            "NORTHERN": HemisphereData(seasonOffset: 0, temperatureBase: 15.0, precipitationBase: 0.5),
            "SOUTHERN": HemisphereData(seasonOffset: 6, temperatureBase: 18.0, precipitationBase: 0.6)
        ]
        
        calculateCurrentSeasonalFactors()
    }
    
    private func initializeEventModels() {
        eventProbabilityModels = [
            "HURRICANE": createHurricaneModel(),
            "DROUGHT": createDroughtModel(),
            "FLOOD": createFloodModel(),
            "HEATWAVE": createHeatwaveModel(),
            "COLD_SNAP": createColdSnapModel(),
            "MONSOON": createMonsoonModel(),
            "EL_NINO": createElNinoModel(),
            "LA_NINA": createLaNinaModel(),
            "VOLCANIC": createVolcanicModel(),
            "WILDFIRE": createWildfireModel()
        ]
    }
    
    private func setupWeatherSubscriptions() {
        weatherDataService.$currentWeatherData
            .sink { [weak self] weatherData in
                self?.processWeatherUpdate(weatherData)
            }
            .store(in: &cancellables)
        
        climateModelingService.$climateProjections
            .sink { [weak self] projections in
                self?.updateClimateImpacts(projections)
            }
            .store(in: &cancellables)
    }
    
    private func startSeasonalUpdates() {
        Timer.publish(every: updateInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateSeasonalFactors()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Core Update Methods
    
    private func updateSeasonalFactors() {
        calculateCurrentSeasonalFactors()
        generateWeatherEvents()
        updateSeasonalForecasts()
        processActiveEvents()
        cleanupExpiredEvents()
    }
    
    private func calculateCurrentSeasonalFactors() {
        let currentDate = Date()
        
        for (region, pattern) in regionalPatterns {
            let factorSet = seasonalCalculator.calculateFactors(
                for: currentDate,
                pattern: pattern,
                weatherData: weatherDataService.getRegionalWeather(region),
                agriculturalCycle: agriculturalCycleService.getCycle(for: region)
            )
            
            currentSeasonalFactors[region] = factorSet
        }
    }
    
    private func generateWeatherEvents() {
        let currentDate = Date()
        let currentSeason = getCurrentSeason()
        
        for (eventType, model) in eventProbabilityModels {
            let probability = model.calculateProbability(
                date: currentDate,
                season: currentSeason,
                weatherConditions: weatherDataService.globalWeatherSummary,
                climateFactors: climateModelingService.currentClimateFactors
            )
            
            if shouldGenerateEvent(probability: probability, eventType: eventType) {
                let event = generateWeatherEvent(type: eventType, model: model)
                weatherEvents.append(event)
                activeEvents.append(convertToMarketEvent(event))
            }
        }
    }
    
    private func updateSeasonalForecasts() {
        for (region, pattern) in regionalPatterns {
            let forecast = generateSeasonalForecast(for: region, pattern: pattern)
            seasonalForecasts[region] = forecast
        }
    }
    
    // MARK: - Weather Event Processing
    
    private func processWeatherUpdate(_ weatherData: GlobalWeatherData) {
        // Update current weather conditions and their market impacts
        for (region, conditions) in weatherData.regionalConditions {
            let impact = weatherImpactCalculator.calculateImpact(
                conditions: conditions,
                seasonalPattern: regionalPatterns[region],
                economicProfile: getEconomicProfile(for: region)
            )
            
            updateRegionalImpacts(region: region, impact: impact)
        }
        
        // Check for extreme weather conditions that could trigger events
        detectExtremeWeatherEvents(from: weatherData)
    }
    
    private func detectExtremeWeatherEvents(from weatherData: GlobalWeatherData) {
        for (region, conditions) in weatherData.regionalConditions {
            // Temperature extremes
            if conditions.temperature > 40.0 || conditions.temperature < -20.0 {
                generateTemperatureExtremeEvent(region: region, conditions: conditions)
            }
            
            // Precipitation extremes
            if conditions.precipitation > 100.0 || (conditions.precipitation < 1.0 && Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 86400 * 30) < 86400) {
                generatePrecipitationExtremeEvent(region: region, conditions: conditions)
            }
            
            // Wind extremes
            if conditions.windSpeed > 30.0 {
                generateWindExtremeEvent(region: region, conditions: conditions)
            }
        }
    }
    
    private func updateClimateImpacts(_ projections: ClimateProjections) {
        for (region, projection) in projections.regionalProjections {
            let impact = ClimateImpact(
                temperatureChange: projection.temperatureChange,
                precipitationChange: projection.precipitationChange,
                seaLevelChange: projection.seaLevelChange,
                extremeWeatherFrequency: projection.extremeWeatherFrequency,
                agriculturalProductivity: calculateAgriculturalImpact(projection),
                energyDemand: calculateEnergyDemandImpact(projection),
                infrastructureStress: calculateInfrastructureStress(projection),
                timeHorizon: projection.timeHorizon
            )
            
            climateImpacts[region] = impact
        }
    }
    
    // MARK: - Seasonal Factor Calculation
    
    /// Get seasonal factors for a specific commodity and region
    public func getSeasonalFactors(commodity: String, region: String) -> CommoditySeasonalFactors {
        guard let factorSet = currentSeasonalFactors[region] else {
            return CommoditySeasonalFactors.default
        }
        
        return factorSet.commodityFactors[commodity] ?? CommoditySeasonalFactors.default
    }
    
    /// Get weather impact on commodity pricing
    public func getWeatherImpact(commodity: String, region: String) -> WeatherImpactFactor {
        let currentWeather = weatherDataService.getRegionalWeather(region)
        let seasonalPattern = regionalPatterns[region]
        
        return weatherImpactCalculator.calculateCommodityImpact(
            commodity: commodity,
            weather: currentWeather,
            pattern: seasonalPattern
        )
    }
    
    /// Get event-based market impact
    public func getEventImpact(commodity: String, region: String) -> EventImpactFactor {
        let relevantEvents = activeEvents.filter { event in
            event.affectedRegions.contains(region) && event.affectedCommodities.contains(commodity)
        }
        
        return eventImpactCalculator.calculateCombinedImpact(events: relevantEvents, commodity: commodity)
    }
    
    /// Get comprehensive seasonal adjustment for pricing
    public func getComprehensiveSeasonalAdjustment(commodity: String, region: String) -> SeasonalAdjustment {
        let seasonalFactors = getSeasonalFactors(commodity: commodity, region: region)
        let weatherImpact = getWeatherImpact(commodity: commodity, region: region)
        let eventImpact = getEventImpact(commodity: commodity, region: region)
        
        let combinedMultiplier = seasonalFactors.priceMultiplier * 
                                weatherImpact.priceMultiplier * 
                                eventImpact.priceMultiplier
        
        let volatilityAdjustment = seasonalFactors.volatilityAdjustment + 
                                  weatherImpact.volatilityAdjustment + 
                                  eventImpact.volatilityAdjustment
        
        return SeasonalAdjustment(
            priceMultiplier: combinedMultiplier,
            volatilityAdjustment: volatilityAdjustment,
            demandAdjustment: seasonalFactors.demandAdjustment * weatherImpact.demandAdjustment,
            supplyAdjustment: seasonalFactors.supplyAdjustment * weatherImpact.supplyAdjustment,
            confidence: calculateAdjustmentConfidence(seasonalFactors, weatherImpact, eventImpact)
        )
    }
    
    // MARK: - Forecasting
    
    private func generateSeasonalForecast(for region: String, pattern: RegionalSeasonalPattern) -> SeasonalForecast {
        let currentDate = Date()
        var predictions: [SeasonalPrediction] = []
        
        // Generate predictions for next 12 months
        for month in 1...12 {
            let targetDate = Calendar.current.date(byAdding: .month, value: month, to: currentDate)!
            
            let prediction = SeasonalPrediction(
                date: targetDate,
                temperatureFactor: pattern.getTemperatureFactor(for: targetDate),
                precipitationFactor: pattern.getPrecipitationFactor(for: targetDate),
                commodityFactors: pattern.getCommodityFactors(for: targetDate),
                eventProbabilities: calculateEventProbabilities(for: targetDate, region: region),
                confidence: calculateForecastConfidence(monthsAhead: month)
            )
            
            predictions.append(prediction)
        }
        
        return SeasonalForecast(
            region: region,
            predictions: predictions,
            methodology: "Advanced Seasonal Modeling with Climate Integration",
            lastUpdated: Date()
        )
    }
    
    private func calculateEventProbabilities(for date: Date, region: String) -> [String: Double] {
        var probabilities: [String: Double] = [:]
        
        for (eventType, model) in eventProbabilityModels {
            let probability = model.calculateProbability(
                date: date,
                season: getSeason(for: date),
                weatherConditions: getProjectedWeather(for: date, region: region),
                climateFactors: climateModelingService.getProjectedFactors(for: date)
            )
            
            probabilities[eventType] = probability
        }
        
        return probabilities
    }
    
    // MARK: - Event Generation and Management
    
    private func shouldGenerateEvent(probability: Double, eventType: String) -> Bool {
        let randomValue = Double.random(in: 0...1)
        let adjustedProbability = probability * getEventFrequencyMultiplier(eventType)
        
        return randomValue < adjustedProbability
    }
    
    private func generateWeatherEvent(type: String, model: EventProbabilityModel) -> WeatherEvent {
        let intensity = model.generateIntensity()
        let duration = model.generateDuration(intensity: intensity)
        let affectedRegions = model.generateAffectedRegions(intensity: intensity)
        
        return WeatherEvent(
            id: UUID(),
            type: WeatherEventType(rawValue: type) ?? .other,
            intensity: intensity,
            duration: duration,
            startTime: Date(),
            affectedRegions: affectedRegions,
            expectedImpacts: model.calculateExpectedImpacts(intensity: intensity),
            confidence: model.confidenceLevel
        )
    }
    
    private func convertToMarketEvent(_ weatherEvent: WeatherEvent) -> MarketEvent {
        return MarketEvent(
            id: weatherEvent.id,
            type: .weatherEvent,
            title: weatherEvent.type.rawValue,
            description: generateEventDescription(weatherEvent),
            severity: weatherEvent.intensity,
            startTime: weatherEvent.startTime,
            duration: weatherEvent.duration,
            affectedRegions: weatherEvent.affectedRegions,
            affectedCommodities: getAffectedCommodities(for: weatherEvent),
            priceImpacts: calculatePriceImpacts(for: weatherEvent),
            supplyImpacts: calculateSupplyImpacts(for: weatherEvent),
            demandImpacts: calculateDemandImpacts(for: weatherEvent)
        )
    }
    
    private func processActiveEvents() {
        for event in activeEvents {
            if event.isActive {
                applyEventEffects(event)
            }
        }
    }
    
    private func cleanupExpiredEvents() {
        let now = Date()
        
        // Move expired events to history
        let expiredEvents = activeEvents.filter { !$0.isActive }
        eventHistory.append(contentsOf: expiredEvents)
        
        // Remove expired events from active list
        activeEvents.removeAll { !$0.isActive }
        
        // Remove old weather events
        weatherEvents.removeAll { now.timeIntervalSince($0.startTime) > $0.duration + 86400 }
        
        // Limit history size
        if eventHistory.count > 1000 {
            eventHistory = Array(eventHistory.suffix(1000))
        }
    }
    
    // MARK: - Regional Pattern Creation
    
    private func createNorthAmericaPattern() -> RegionalSeasonalPattern {
        return RegionalSeasonalPattern(
            region: "NORTH_AMERICA",
            hemisphere: .northern,
            climateZones: [.temperate, .continental, .arctic],
            temperatureRange: (-30.0, 45.0),
            precipitationRange: (0.0, 200.0),
            seasonalCommodityPatterns: [
                "WHEAT": createWheatPattern(.northern),
                "CORN": createCornPattern(.northern),
                "NATURAL_GAS": createNaturalGasPattern(.northern),
                "HEATING_OIL": createHeatingOilPattern(.northern)
            ],
            majorWeatherPatterns: [.tornado, .hurricane, .blizzard, .drought],
            agriculturalZones: createNorthAmericaAgZones()
        )
    }
    
    private func createSouthAmericaPattern() -> RegionalSeasonalPattern {
        return RegionalSeasonalPattern(
            region: "SOUTH_AMERICA",
            hemisphere: .southern,
            climateZones: [.tropical, .temperate, .arid],
            temperatureRange: (0.0, 45.0),
            precipitationRange: (0.0, 300.0),
            seasonalCommodityPatterns: [
                "SOYBEANS": createSoybeansPattern(.southern),
                "CORN": createCornPattern(.southern),
                "COFFEE": createCoffeePattern(.tropical),
                "IRON_ORE": createIronOrePattern(.tropical)
            ],
            majorWeatherPatterns: [.elNino, .laNina, .drought, .flood],
            agriculturalZones: createSouthAmericaAgZones()
        )
    }
    
    private func createEuropePattern() -> RegionalSeasonalPattern {
        return RegionalSeasonalPattern(
            region: "EUROPE",
            hemisphere: .northern,
            climateZones: [.temperate, .mediterranean, .continental],
            temperatureRange: (-25.0, 40.0),
            precipitationRange: (10.0, 150.0),
            seasonalCommodityPatterns: [
                "WHEAT": createWheatPattern(.northern),
                "NATURAL_GAS": createNaturalGasPattern(.northern),
                "HEATING_OIL": createHeatingOilPattern(.northern),
                "ALUMINUM": createAluminumPattern(.temperate)
            ],
            majorWeatherPatterns: [.heatwave, .coldSnap, .flood, .storm],
            agriculturalZones: createEuropeAgZones()
        )
    }
    
    private func createAsiaPattern() -> RegionalSeasonalPattern {
        return RegionalSeasonalPattern(
            region: "ASIA",
            hemisphere: .northern,
            climateZones: [.temperate, .tropical, .arid, .continental],
            temperatureRange: (-40.0, 50.0),
            precipitationRange: (0.0, 400.0),
            seasonalCommodityPatterns: [
                "RICE": createRicePattern(.tropical),
                "PALM_OIL": createPalmOilPattern(.tropical),
                "RUBBER": createRubberPattern(.tropical),
                "IRON_ORE": createIronOrePattern(.continental),
                "COAL": createCoalPattern(.continental)
            ],
            majorWeatherPatterns: [.monsoon, .typhoon, .drought, .heatwave],
            agriculturalZones: createAsiaAgZones()
        )
    }
    
    private func createAfricaPattern() -> RegionalSeasonalPattern {
        return RegionalSeasonalPattern(
            region: "AFRICA",
            hemisphere: .mixed,
            climateZones: [.tropical, .arid, .savanna],
            temperatureRange: (5.0, 50.0),
            precipitationRange: (0.0, 250.0),
            seasonalCommodityPatterns: [
                "COFFEE": createCoffeePattern(.tropical),
                "COTTON": createCottonPattern(.arid),
                "GOLD": createGoldPattern(.stable),
                "PLATINUM": createPlatinumPattern(.stable)
            ],
            majorWeatherPatterns: [.drought, .flood, .sandstorm, .cyclone],
            agriculturalZones: createAfricaAgZones()
        )
    }
    
    private func createOceaniaPattern() -> RegionalSeasonalPattern {
        return RegionalSeasonalPattern(
            region: "OCEANIA",
            hemisphere: .southern,
            climateZones: [.temperate, .tropical, .arid],
            temperatureRange: (-5.0, 45.0),
            precipitationRange: (5.0, 300.0),
            seasonalCommodityPatterns: [
                "IRON_ORE": createIronOrePattern(.arid),
                "COAL": createCoalPattern(.temperate),
                "BEEF": createBeefPattern(.temperate),
                "WOOL": createWoolPattern(.temperate)
            ],
            majorWeatherPatterns: [.drought, .flood, .cyclone, .bushfire],
            agriculturalZones: createOceaniaAgZones()
        )
    }
    
    private func createMiddleEastPattern() -> RegionalSeasonalPattern {
        return RegionalSeasonalPattern(
            region: "MIDDLE_EAST",
            hemisphere: .northern,
            climateZones: [.arid, .desert],
            temperatureRange: (0.0, 55.0),
            precipitationRange: (0.0, 50.0),
            seasonalCommodityPatterns: [
                "CRUDE_OIL": createCrudeOilPattern(.stable),
                "NATURAL_GAS": createNaturalGasPattern(.arid),
                "DATES": createDatesPattern(.arid)
            ],
            majorWeatherPatterns: [.heatwave, .sandstorm, .drought],
            agriculturalZones: createMiddleEastAgZones()
        )
    }
    
    // MARK: - Event Model Creation
    
    private func createHurricaneModel() -> EventProbabilityModel {
        return EventProbabilityModel(
            eventType: "HURRICANE",
            baseFrequency: 0.001, // 0.1% chance per day during season
            seasonalMultipliers: [6: 0.5, 7: 1.0, 8: 2.0, 9: 2.5, 10: 1.5, 11: 0.5],
            climateSensitivity: 1.5,
            regionProbabilities: [
                "NORTH_AMERICA": 0.7,
                "CARIBBEAN": 0.8,
                "ASIA": 0.3
            ],
            intensityDistribution: [0.2: 0.4, 0.4: 0.3, 0.6: 0.2, 0.8: 0.1],
            durationRange: (86400 * 3, 86400 * 14), // 3-14 days
            confidenceLevel: 0.75
        )
    }
    
    private func createDroughtModel() -> EventProbabilityModel {
        return EventProbabilityModel(
            eventType: "DROUGHT",
            baseFrequency: 0.0005, // 0.05% chance per day
            seasonalMultipliers: [6: 1.5, 7: 2.0, 8: 2.0, 9: 1.5],
            climateSensitivity: 2.0,
            regionProbabilities: [
                "AFRICA": 0.8,
                "AUSTRALIA": 0.7,
                "SOUTH_AMERICA": 0.6,
                "NORTH_AMERICA": 0.4
            ],
            intensityDistribution: [0.3: 0.3, 0.5: 0.4, 0.7: 0.2, 0.9: 0.1],
            durationRange: (86400 * 30, 86400 * 365), // 30 days to 1 year
            confidenceLevel: 0.65
        )
    }
    
    private func createFloodModel() -> EventProbabilityModel {
        return EventProbabilityModel(
            eventType: "FLOOD",
            baseFrequency: 0.002, // 0.2% chance per day
            seasonalMultipliers: [3: 1.2, 4: 1.5, 5: 1.3, 6: 1.0, 7: 0.8, 8: 0.9, 9: 1.1],
            climateSensitivity: 1.2,
            regionProbabilities: [
                "ASIA": 0.9,
                "SOUTH_AMERICA": 0.7,
                "EUROPE": 0.5,
                "NORTH_AMERICA": 0.4
            ],
            intensityDistribution: [0.2: 0.5, 0.4: 0.3, 0.6: 0.15, 0.8: 0.05],
            durationRange: (86400 * 1, 86400 * 30), // 1-30 days
            confidenceLevel: 0.7
        )
    }
    
    private func createMonsoonModel() -> EventProbabilityModel {
        return EventProbabilityModel(
            eventType: "MONSOON",
            baseFrequency: 0.01, // 1% chance per day during season
            seasonalMultipliers: [6: 2.0, 7: 3.0, 8: 2.5, 9: 1.5],
            climateSensitivity: 1.0,
            regionProbabilities: [
                "ASIA": 0.95,
                "AFRICA": 0.3
            ],
            intensityDistribution: [0.4: 0.3, 0.6: 0.4, 0.8: 0.2, 1.0: 0.1],
            durationRange: (86400 * 60, 86400 * 120), // 2-4 months
            confidenceLevel: 0.85
        )
    }
    
    private func createElNinoModel() -> EventProbabilityModel {
        return EventProbabilityModel(
            eventType: "EL_NINO",
            baseFrequency: 0.0001, // Very rare but impactful
            seasonalMultipliers: [12: 1.5, 1: 1.5, 2: 1.5], // Peak in winter
            climateSensitivity: 3.0,
            regionProbabilities: [
                "SOUTH_AMERICA": 0.9,
                "ASIA": 0.8,
                "OCEANIA": 0.7,
                "NORTH_AMERICA": 0.5
            ],
            intensityDistribution: [0.5: 0.4, 0.7: 0.3, 0.9: 0.2, 1.0: 0.1],
            durationRange: (86400 * 180, 86400 * 730), // 6 months to 2 years
            confidenceLevel: 0.6
        )
    }
    
    private func createLaNinaModel() -> EventProbabilityModel {
        return EventProbabilityModel(
            eventType: "LA_NINA",
            baseFrequency: 0.0001,
            seasonalMultipliers: [6: 1.5, 7: 1.5, 8: 1.5],
            climateSensitivity: 3.0,
            regionProbabilities: [
                "ASIA": 0.9,
                "OCEANIA": 0.8,
                "SOUTH_AMERICA": 0.7,
                "NORTH_AMERICA": 0.6
            ],
            intensityDistribution: [0.5: 0.4, 0.7: 0.3, 0.9: 0.2, 1.0: 0.1],
            durationRange: (86400 * 180, 86400 * 1095), // 6 months to 3 years
            confidenceLevel: 0.6
        )
    }
    
    private func createHeatwaveModel() -> EventProbabilityModel {
        return EventProbabilityModel(
            eventType: "HEATWAVE",
            baseFrequency: 0.003,
            seasonalMultipliers: [6: 1.5, 7: 2.5, 8: 2.0, 9: 1.2],
            climateSensitivity: 2.5,
            regionProbabilities: [
                "EUROPE": 0.8,
                "NORTH_AMERICA": 0.7,
                "ASIA": 0.6,
                "AFRICA": 0.9,
                "OCEANIA": 0.7
            ],
            intensityDistribution: [0.3: 0.4, 0.5: 0.3, 0.7: 0.2, 0.9: 0.1],
            durationRange: (86400 * 3, 86400 * 21), // 3-21 days
            confidenceLevel: 0.8
        )
    }
    
    private func createColdSnapModel() -> EventProbabilityModel {
        return EventProbabilityModel(
            eventType: "COLD_SNAP",
            baseFrequency: 0.002,
            seasonalMultipliers: [12: 2.0, 1: 2.5, 2: 2.0, 3: 1.2],
            climateSensitivity: 1.5,
            regionProbabilities: [
                "NORTH_AMERICA": 0.8,
                "EUROPE": 0.7,
                "ASIA": 0.9
            ],
            intensityDistribution: [0.3: 0.3, 0.5: 0.4, 0.7: 0.2, 0.9: 0.1],
            durationRange: (86400 * 2, 86400 * 14), // 2-14 days
            confidenceLevel: 0.75
        )
    }
    
    private func createVolcanicModel() -> EventProbabilityModel {
        return EventProbabilityModel(
            eventType: "VOLCANIC",
            baseFrequency: 0.00001, // Very rare
            seasonalMultipliers: [:], // No seasonal pattern
            climateSensitivity: 0.5,
            regionProbabilities: [
                "ASIA": 0.7,
                "OCEANIA": 0.8,
                "SOUTH_AMERICA": 0.4,
                "NORTH_AMERICA": 0.3
            ],
            intensityDistribution: [0.2: 0.7, 0.5: 0.2, 0.8: 0.08, 1.0: 0.02],
            durationRange: (86400 * 1, 86400 * 365), // 1 day to 1 year
            confidenceLevel: 0.4
        )
    }
    
    private func createWildfireModel() -> EventProbabilityModel {
        return EventProbabilityModel(
            eventType: "WILDFIRE",
            baseFrequency: 0.001,
            seasonalMultipliers: [6: 1.5, 7: 2.0, 8: 2.5, 9: 2.0, 10: 1.2],
            climateSensitivity: 2.0,
            regionProbabilities: [
                "NORTH_AMERICA": 0.8,
                "OCEANIA": 0.9,
                "EUROPE": 0.5,
                "AFRICA": 0.6,
                "SOUTH_AMERICA": 0.7
            ],
            intensityDistribution: [0.2: 0.5, 0.4: 0.3, 0.6: 0.15, 0.8: 0.05],
            durationRange: (86400 * 1, 86400 * 90), // 1-90 days
            confidenceLevel: 0.7
        )
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentSeason() -> Season {
        let month = Calendar.current.component(.month, from: Date())
        return getSeason(for: Date())
    }
    
    private func getSeason(for date: Date) -> Season {
        let month = Calendar.current.component(.month, from: date)
        
        switch month {
        case 12, 1, 2: return .winter
        case 3, 4, 5: return .spring
        case 6, 7, 8: return .summer
        case 9, 10, 11: return .autumn
        default: return .spring
        }
    }
    
    private func getEventFrequencyMultiplier(_ eventType: String) -> Double {
        // Adjust frequency based on recent events and climate trends
        let recentEvents = eventHistory.suffix(100).filter { $0.type.rawValue == eventType }
        let recentFrequency = Double(recentEvents.count) / 100.0
        
        // Reduce probability if there have been many recent events of this type
        return max(0.1, 1.0 - recentFrequency * 0.5)
    }
    
    private func calculateAdjustmentConfidence(_ seasonal: CommoditySeasonalFactors,
                                             _ weather: WeatherImpactFactor,
                                             _ event: EventImpactFactor) -> Double {
        let seasonalConfidence = seasonal.confidence
        let weatherConfidence = weather.confidence
        let eventConfidence = event.confidence
        
        // Combined confidence is the minimum of individual confidences
        return min(seasonalConfidence, min(weatherConfidence, eventConfidence))
    }
    
    private func calculateForecastConfidence(monthsAhead: Int) -> Double {
        // Confidence decreases with time horizon
        let baseConfidence = 0.9
        let decayRate = 0.05
        
        return max(0.3, baseConfidence * exp(-decayRate * Double(monthsAhead)))
    }
    
    // MARK: - Public Interface
    
    /// Get active weather events affecting a specific region
    public func getActiveWeatherEvents(for region: String) -> [WeatherEvent] {
        return weatherEvents.filter { $0.affectedRegions.contains(region) && $0.isActive }
    }
    
    /// Get seasonal forecast for a specific region
    public func getSeasonalForecast(for region: String) -> SeasonalForecast? {
        return seasonalForecasts[region]
    }
    
    /// Get climate impact assessment for a region
    public func getClimateImpact(for region: String) -> ClimateImpact? {
        return climateImpacts[region]
    }
    
    /// Simulate a custom weather event
    public func simulateWeatherEvent(_ event: WeatherEvent) {
        weatherEvents.append(event)
        activeEvents.append(convertToMarketEvent(event))
    }
    
    /// Get historical event data for analysis
    public func getEventHistory(eventType: String? = nil, region: String? = nil) -> [MarketEvent] {
        var filteredHistory = eventHistory
        
        if let eventType = eventType {
            filteredHistory = filteredHistory.filter { $0.type.rawValue == eventType }
        }
        
        if let region = region {
            filteredHistory = filteredHistory.filter { $0.affectedRegions.contains(region) }
        }
        
        return filteredHistory
    }
    
    /// Get comprehensive seasonal analysis
    public func getSeasonalAnalysis(commodity: String, region: String) -> SeasonalAnalysis {
        let currentFactors = getSeasonalFactors(commodity: commodity, region: region)
        let weatherImpact = getWeatherImpact(commodity: commodity, region: region)
        let eventImpact = getEventImpact(commodity: commodity, region: region)
        let forecast = getSeasonalForecast(for: region)
        
        return SeasonalAnalysis(
            commodity: commodity,
            region: region,
            currentFactors: currentFactors,
            weatherImpact: weatherImpact,
            eventImpact: eventImpact,
            forecast: forecast,
            recommendations: generateSeasonalRecommendations(commodity, region),
            riskAssessment: assessSeasonalRisk(commodity, region)
        )
    }
    
    private func generateSeasonalRecommendations(_ commodity: String, _ region: String) -> [String] {
        var recommendations: [String] = []
        
        let factors = getSeasonalFactors(commodity: commodity, region: region)
        let weather = getWeatherImpact(commodity: commodity, region: region)
        let events = getEventImpact(commodity: commodity, region: region)
        
        if factors.priceMultiplier > 1.1 {
            recommendations.append("Prices expected to be elevated due to seasonal factors")
        }
        
        if weather.supplyRisk > 0.7 {
            recommendations.append("Supply disruption risk elevated due to weather conditions")
        }
        
        if events.priceMultiplier > 1.2 {
            recommendations.append("Significant price volatility expected due to weather events")
        }
        
        return recommendations
    }
    
    private func assessSeasonalRisk(_ commodity: String, _ region: String) -> SeasonalRiskAssessment {
        let factors = getSeasonalFactors(commodity: commodity, region: region)
        let weather = getWeatherImpact(commodity: commodity, region: region)
        let events = getEventImpact(commodity: commodity, region: region)
        
        let priceRisk = abs(factors.priceMultiplier - 1.0) + abs(weather.priceMultiplier - 1.0) + abs(events.priceMultiplier - 1.0)
        let supplyRisk = weather.supplyRisk + events.supplyRisk
        let demandRisk = abs(factors.demandAdjustment - 1.0) + abs(weather.demandAdjustment - 1.0)
        
        return SeasonalRiskAssessment(
            overallRisk: (priceRisk + supplyRisk + demandRisk) / 3.0,
            priceRisk: priceRisk,
            supplyRisk: supplyRisk,
            demandRisk: demandRisk,
            volatilityRisk: factors.volatilityAdjustment + weather.volatilityAdjustment + events.volatilityAdjustment,
            timeHorizon: 86400 * 90 // 90 days
        )
    }
}