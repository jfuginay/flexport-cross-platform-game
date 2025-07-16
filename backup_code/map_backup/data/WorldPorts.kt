package com.flexport.map.data

import com.flexport.economics.models.CommodityType
import com.flexport.map.models.*

/**
 * Real-world port data for the FlexPort game
 */
object WorldPorts {
    
    private val SHANGHAI = Port(
        id = "CNSHA",
        name = "Port of Shanghai",
        position = GeographicalPosition(31.2304, 121.4737),
        country = "China",
        region = "Asia Pacific",
        portType = PortType.CONTAINER,
        size = PortSize.MEGA,
        capacity = PortCapacity(
            maxVessels = 100,
            maxTEU = 47_000_000,
            maxBulkTonnage = 500_000_000.0,
            maxLiquidVolume = 50_000_000.0,
            maxGeneralCargo = 200_000_000.0,
            storageCapacity = mapOf(
                CommodityType.ELECTRONICS to 1_000_000.0,
                CommodityType.MACHINERY to 800_000.0,
                CommodityType.CLOTHING to 500_000.0
            ),
            turnAroundTime = TurnAroundTime(
                containerShip = 24,
                bulkCarrier = 48,
                tanker = 36,
                generalCargo = 30,
                roro = 12
            )
        ),
        specializations = setOf(CommodityType.ELECTRONICS, CommodityType.MACHINERY, CommodityType.CLOTHING),
        facilities = setOf(
            PortFacility.CONTAINER_TERMINAL,
            PortFacility.BULK_TERMINAL,
            PortFacility.GENERAL_CARGO_TERMINAL,
            PortFacility.HEAVY_LIFT_CRANES,
            PortFacility.RAIL_CONNECTION,
            PortFacility.ROAD_CONNECTION,
            PortFacility.WAREHOUSE_COMPLEX,
            PortFacility.CUSTOMS_FACILITY
        ),
        operationalHours = OperationalHours(
            is24Hour = true,
            workingHours = 0..23,
            weekendOperations = true,
            holidayRestrictions = setOf("Chinese New Year"),
            tideRestrictions = false,
            weatherRestrictions = setOf(WeatherCondition.SEVERE)
        ),
        weatherConditions = WeatherConditions(
            averageConditions = mapOf(
                1 to WeatherCondition.GOOD, 2 to WeatherCondition.GOOD,
                3 to WeatherCondition.GOOD, 4 to WeatherCondition.EXCELLENT,
                5 to WeatherCondition.EXCELLENT, 6 to WeatherCondition.MODERATE,
                7 to WeatherCondition.POOR, 8 to WeatherCondition.POOR,
                9 to WeatherCondition.MODERATE, 10 to WeatherCondition.EXCELLENT,
                11 to WeatherCondition.EXCELLENT, 12 to WeatherCondition.GOOD
            ),
            extremeWeatherRisk = ExtremeWeatherRisk(
                hurricaneRisk = RiskLevel.NONE,
                typhoonRisk = RiskLevel.HIGH,
                iceRisk = RiskLevel.NONE,
                fogRisk = RiskLevel.MEDIUM,
                stormRisk = RiskLevel.MEDIUM
            ),
            seasonalRestrictions = mapOf(
                7 to setOf(PortRestriction.REDUCED_CAPACITY),
                8 to setOf(PortRestriction.REDUCED_CAPACITY)
            )
        ),
        politicalStability = PoliticalStability(
            stabilityRating = 8,
            securityLevel = SecurityLevel.HIGH,
            corruptionIndex = 0.3,
            tradeAgreements = setOf("ASEAN", "RCEP"),
            sanctions = emptySet(),
            stabilityFactor = 1.1
        ),
        infrastructure = PortInfrastructure(
            roadQuality = InfrastructureQuality.EXCELLENT,
            railQuality = InfrastructureQuality.EXCELLENT,
            craneCapacity = 100,
            numberOfCranes = 200,
            waterDepth = 20.0,
            berthLength = 50000,
            digitalSystems = DigitalCapability(
                automatedSystems = true,
                realTimeTracking = true,
                ediIntegration = true,
                predictiveAnalytics = true,
                iotSensors = true
            ),
            overallRating = 1.8
        ),
        costs = PortCosts(
            berthingFee = 5000.0,
            handlingCost = mapOf(
                CommodityType.ELECTRONICS to 50.0,
                CommodityType.MACHINERY to 40.0,
                CommodityType.CLOTHING to 25.0
            ),
            storageeCost = mapOf(
                CommodityType.ELECTRONICS to 5.0,
                CommodityType.MACHINERY to 3.0,
                CommodityType.CLOTHING to 2.0
            ),
            fuelCost = 0.8,
            pilotage = 2000.0,
            towage = 1500.0,
            agencyFees = 800.0,
            customs = 500.0,
            security = 300.0
        ),
        description = "World's largest container port by volume, major gateway to China"
    )
    
    private val SINGAPORE = Port(
        id = "SGSIN",
        name = "Port of Singapore",
        position = GeographicalPosition(1.2966, 103.7764),
        country = "Singapore",
        region = "Asia Pacific",
        portType = PortType.CONTAINER,
        size = PortSize.MEGA,
        capacity = PortCapacity(
            maxVessels = 120,
            maxTEU = 37_000_000,
            maxBulkTonnage = 100_000_000.0,
            maxLiquidVolume = 80_000_000.0,
            maxGeneralCargo = 50_000_000.0,
            storageCapacity = mapOf(
                CommodityType.FUEL to 2_000_000.0,
                CommodityType.ELECTRONICS to 800_000.0,
                CommodityType.PHARMACEUTICALS to 200_000.0
            ),
            turnAroundTime = TurnAroundTime(
                containerShip = 18,
                bulkCarrier = 36,
                tanker = 24,
                generalCargo = 24,
                roro = 10
            )
        ),
        specializations = setOf(CommodityType.FUEL, CommodityType.ELECTRONICS, CommodityType.PHARMACEUTICALS),
        facilities = setOf(
            PortFacility.CONTAINER_TERMINAL,
            PortFacility.LIQUID_TERMINAL,
            PortFacility.GENERAL_CARGO_TERMINAL,
            PortFacility.HEAVY_LIFT_CRANES,
            PortFacility.BUNKERING,
            PortFacility.SHIP_REPAIR,
            PortFacility.CUSTOMS_FACILITY,
            PortFacility.COLD_STORAGE,
            PortFacility.HAZMAT_HANDLING
        ),
        operationalHours = OperationalHours(
            is24Hour = true,
            workingHours = 0..23,
            weekendOperations = true,
            holidayRestrictions = emptySet(),
            tideRestrictions = false,
            weatherRestrictions = setOf(WeatherCondition.SEVERE)
        ),
        weatherConditions = WeatherConditions(
            averageConditions = (1..12).associateWith { WeatherCondition.EXCELLENT },
            extremeWeatherRisk = ExtremeWeatherRisk(
                hurricaneRisk = RiskLevel.NONE,
                typhoonRisk = RiskLevel.LOW,
                iceRisk = RiskLevel.NONE,
                fogRisk = RiskLevel.LOW,
                stormRisk = RiskLevel.LOW
            ),
            seasonalRestrictions = emptyMap()
        ),
        politicalStability = PoliticalStability(
            stabilityRating = 10,
            securityLevel = SecurityLevel.VERY_HIGH,
            corruptionIndex = 0.05,
            tradeAgreements = setOf("ASEAN", "CPTPP", "RCEP"),
            sanctions = emptySet(),
            stabilityFactor = 1.3
        ),
        infrastructure = PortInfrastructure(
            roadQuality = InfrastructureQuality.WORLD_CLASS,
            railQuality = InfrastructureQuality.WORLD_CLASS,
            craneCapacity = 120,
            numberOfCranes = 150,
            waterDepth = 25.0,
            berthLength = 35000,
            digitalSystems = DigitalCapability(
                automatedSystems = true,
                realTimeTracking = true,
                ediIntegration = true,
                predictiveAnalytics = true,
                iotSensors = true
            ),
            overallRating = 2.0
        ),
        costs = PortCosts(
            berthingFee = 8000.0,
            handlingCost = mapOf(
                CommodityType.FUEL to 30.0,
                CommodityType.ELECTRONICS to 60.0,
                CommodityType.PHARMACEUTICALS to 100.0
            ),
            storageeCost = mapOf(
                CommodityType.FUEL to 2.0,
                CommodityType.ELECTRONICS to 8.0,
                CommodityType.PHARMACEUTICALS to 15.0
            ),
            fuelCost = 0.9,
            pilotage = 3000.0,
            towage = 2000.0,
            agencyFees = 1200.0,
            customs = 300.0,
            security = 500.0
        ),
        description = "World's second-largest container port and leading bunkering hub"
    )
    
    private val ROTTERDAM = Port(
        id = "NLRTM",
        name = "Port of Rotterdam",
        position = GeographicalPosition(51.9244, 4.4777),
        country = "Netherlands",
        region = "Europe",
        portType = PortType.INDUSTRIAL,
        size = PortSize.MEGA,
        capacity = PortCapacity(
            maxVessels = 80,
            maxTEU = 15_000_000,
            maxBulkTonnage = 400_000_000.0,
            maxLiquidVolume = 200_000_000.0,
            maxGeneralCargo = 150_000_000.0,
            storageCapacity = mapOf(
                CommodityType.FUEL to 5_000_000.0,
                CommodityType.RAW_MATERIALS to 3_000_000.0,
                CommodityType.CONSTRUCTION_MATERIALS to 2_000_000.0
            ),
            turnAroundTime = TurnAroundTime(
                containerShip = 20,
                bulkCarrier = 40,
                tanker = 30,
                generalCargo = 28,
                roro = 8
            )
        ),
        specializations = setOf(CommodityType.FUEL, CommodityType.RAW_MATERIALS, CommodityType.CONSTRUCTION_MATERIALS),
        facilities = setOf(
            PortFacility.CONTAINER_TERMINAL,
            PortFacility.BULK_TERMINAL,
            PortFacility.LIQUID_TERMINAL,
            PortFacility.GENERAL_CARGO_TERMINAL,
            PortFacility.RORO_TERMINAL,
            PortFacility.HEAVY_LIFT_CRANES,
            PortFacility.RAIL_CONNECTION,
            PortFacility.ROAD_CONNECTION,
            PortFacility.PIPELINE_CONNECTION,
            PortFacility.BUNKERING,
            PortFacility.SHIP_REPAIR,
            PortFacility.WAREHOUSE_COMPLEX
        ),
        operationalHours = OperationalHours(
            is24Hour = true,
            workingHours = 0..23,
            weekendOperations = true,
            holidayRestrictions = setOf("Christmas", "New Year"),
            tideRestrictions = true,
            weatherRestrictions = setOf(WeatherCondition.SEVERE, WeatherCondition.POOR)
        ),
        weatherConditions = WeatherConditions(
            averageConditions = mapOf(
                1 to WeatherCondition.POOR, 2 to WeatherCondition.MODERATE,
                3 to WeatherCondition.GOOD, 4 to WeatherCondition.GOOD,
                5 to WeatherCondition.EXCELLENT, 6 to WeatherCondition.EXCELLENT,
                7 to WeatherCondition.EXCELLENT, 8 to WeatherCondition.GOOD,
                9 to WeatherCondition.GOOD, 10 to WeatherCondition.MODERATE,
                11 to WeatherCondition.POOR, 12 to WeatherCondition.POOR
            ),
            extremeWeatherRisk = ExtremeWeatherRisk(
                hurricaneRisk = RiskLevel.NONE,
                typhoonRisk = RiskLevel.NONE,
                iceRisk = RiskLevel.MEDIUM,
                fogRisk = RiskLevel.HIGH,
                stormRisk = RiskLevel.HIGH
            ),
            seasonalRestrictions = mapOf(
                1 to setOf(PortRestriction.REDUCED_CAPACITY),
                2 to setOf(PortRestriction.REDUCED_CAPACITY),
                12 to setOf(PortRestriction.REDUCED_CAPACITY)
            )
        ),
        politicalStability = PoliticalStability(
            stabilityRating = 9,
            securityLevel = SecurityLevel.VERY_HIGH,
            corruptionIndex = 0.1,
            tradeAgreements = setOf("EU", "CETA"),
            sanctions = emptySet(),
            stabilityFactor = 1.2
        ),
        infrastructure = PortInfrastructure(
            roadQuality = InfrastructureQuality.WORLD_CLASS,
            railQuality = InfrastructureQuality.WORLD_CLASS,
            craneCapacity = 80,
            numberOfCranes = 100,
            waterDepth = 24.0,
            berthLength = 42000,
            digitalSystems = DigitalCapability(
                automatedSystems = true,
                realTimeTracking = true,
                ediIntegration = true,
                predictiveAnalytics = true,
                iotSensors = true
            ),
            overallRating = 1.9
        ),
        costs = PortCosts(
            berthingFee = 12000.0,
            handlingCost = mapOf(
                CommodityType.FUEL to 25.0,
                CommodityType.RAW_MATERIALS to 20.0,
                CommodityType.CONSTRUCTION_MATERIALS to 15.0
            ),
            storageeCost = mapOf(
                CommodityType.FUEL to 3.0,
                CommodityType.RAW_MATERIALS to 2.0,
                CommodityType.CONSTRUCTION_MATERIALS to 1.5
            ),
            fuelCost = 1.2,
            pilotage = 4000.0,
            towage = 3000.0,
            agencyFees = 1500.0,
            customs = 200.0,
            security = 800.0
        ),
        description = "Europe's largest port and major petrochemical hub"
    )
    
    private val LOS_ANGELES = Port(
        id = "USLAX",
        name = "Port of Los Angeles",
        position = GeographicalPosition(33.7361, -118.2922),
        country = "United States",
        region = "North America",
        portType = PortType.CONTAINER,
        size = PortSize.LARGE,
        capacity = PortCapacity(
            maxVessels = 60,
            maxTEU = 9_300_000,
            maxBulkTonnage = 50_000_000.0,
            maxLiquidVolume = 20_000_000.0,
            maxGeneralCargo = 80_000_000.0,
            storageCapacity = mapOf(
                CommodityType.ELECTRONICS to 600_000.0,
                CommodityType.VEHICLES to 300_000.0,
                CommodityType.CLOTHING to 400_000.0
            ),
            turnAroundTime = TurnAroundTime(
                containerShip = 30,
                bulkCarrier = 60,
                tanker = 48,
                generalCargo = 36,
                roro = 16
            )
        ),
        specializations = setOf(CommodityType.ELECTRONICS, CommodityType.VEHICLES, CommodityType.CLOTHING),
        facilities = setOf(
            PortFacility.CONTAINER_TERMINAL,
            PortFacility.RORO_TERMINAL,
            PortFacility.GENERAL_CARGO_TERMINAL,
            PortFacility.HEAVY_LIFT_CRANES,
            PortFacility.RAIL_CONNECTION,
            PortFacility.ROAD_CONNECTION,
            PortFacility.WAREHOUSE_COMPLEX,
            PortFacility.CUSTOMS_FACILITY
        ),
        operationalHours = OperationalHours(
            is24Hour = false,
            workingHours = 6..22,
            weekendOperations = false,
            holidayRestrictions = setOf("Thanksgiving", "Christmas", "New Year"),
            tideRestrictions = false,
            weatherRestrictions = setOf(WeatherCondition.SEVERE)
        ),
        weatherConditions = WeatherConditions(
            averageConditions = (1..12).associateWith { WeatherCondition.EXCELLENT },
            extremeWeatherRisk = ExtremeWeatherRisk(
                hurricaneRisk = RiskLevel.NONE,
                typhoonRisk = RiskLevel.NONE,
                iceRisk = RiskLevel.NONE,
                fogRisk = RiskLevel.MEDIUM,
                stormRisk = RiskLevel.LOW
            ),
            seasonalRestrictions = emptyMap()
        ),
        politicalStability = PoliticalStability(
            stabilityRating = 8,
            securityLevel = SecurityLevel.HIGH,
            corruptionIndex = 0.2,
            tradeAgreements = setOf("USMCA", "CPTPP"),
            sanctions = setOf("Various"),
            stabilityFactor = 1.0
        ),
        infrastructure = PortInfrastructure(
            roadQuality = InfrastructureQuality.GOOD,
            railQuality = InfrastructureQuality.EXCELLENT,
            craneCapacity = 65,
            numberOfCranes = 80,
            waterDepth = 17.0,
            berthLength = 25000,
            digitalSystems = DigitalCapability(
                automatedSystems = false,
                realTimeTracking = true,
                ediIntegration = true,
                predictiveAnalytics = false,
                iotSensors = true
            ),
            overallRating = 1.4
        ),
        costs = PortCosts(
            berthingFee = 15000.0,
            handlingCost = mapOf(
                CommodityType.ELECTRONICS to 80.0,
                CommodityType.VEHICLES to 100.0,
                CommodityType.CLOTHING to 35.0
            ),
            storageeCost = mapOf(
                CommodityType.ELECTRONICS to 12.0,
                CommodityType.VEHICLES to 15.0,
                CommodityType.CLOTHING to 5.0
            ),
            fuelCost = 1.1,
            pilotage = 5000.0,
            towage = 4000.0,
            agencyFees = 2000.0,
            customs = 1000.0,
            security = 1500.0
        ),
        description = "Busiest container port in the United States"
    )
    
    private val DUBAI = Port(
        id = "AEDXB",
        name = "Port of Jebel Ali",
        position = GeographicalPosition(25.0657, 55.1713),
        country = "United Arab Emirates",
        region = "Middle East",
        portType = PortType.CONTAINER,
        size = PortSize.LARGE,
        capacity = PortCapacity(
            maxVessels = 80,
            maxTEU = 15_000_000,
            maxBulkTonnage = 100_000_000.0,
            maxLiquidVolume = 50_000_000.0,
            maxGeneralCargo = 75_000_000.0,
            storageCapacity = mapOf(
                CommodityType.FUEL to 1_500_000.0,
                CommodityType.LUXURY_GOODS to 200_000.0,
                CommodityType.ELECTRONICS to 500_000.0
            ),
            turnAroundTime = TurnAroundTime(
                containerShip = 22,
                bulkCarrier = 44,
                tanker = 32,
                generalCargo = 28,
                roro = 12
            )
        ),
        specializations = setOf(CommodityType.FUEL, CommodityType.LUXURY_GOODS, CommodityType.ELECTRONICS),
        facilities = setOf(
            PortFacility.CONTAINER_TERMINAL,
            PortFacility.LIQUID_TERMINAL,
            PortFacility.GENERAL_CARGO_TERMINAL,
            PortFacility.HEAVY_LIFT_CRANES,
            PortFacility.ROAD_CONNECTION,
            PortFacility.BUNKERING,
            PortFacility.SHIP_REPAIR,
            PortFacility.WAREHOUSE_COMPLEX,
            PortFacility.CUSTOMS_FACILITY
        ),
        operationalHours = OperationalHours(
            is24Hour = true,
            workingHours = 0..23,
            weekendOperations = true,
            holidayRestrictions = setOf("Eid", "Ramadan evenings"),
            tideRestrictions = false,
            weatherRestrictions = setOf(WeatherCondition.SEVERE)
        ),
        weatherConditions = WeatherConditions(
            averageConditions = mapOf(
                1 to WeatherCondition.EXCELLENT, 2 to WeatherCondition.EXCELLENT,
                3 to WeatherCondition.EXCELLENT, 4 to WeatherCondition.EXCELLENT,
                5 to WeatherCondition.GOOD, 6 to WeatherCondition.MODERATE,
                7 to WeatherCondition.POOR, 8 to WeatherCondition.POOR,
                9 to WeatherCondition.MODERATE, 10 to WeatherCondition.GOOD,
                11 to WeatherCondition.EXCELLENT, 12 to WeatherCondition.EXCELLENT
            ),
            extremeWeatherRisk = ExtremeWeatherRisk(
                hurricaneRisk = RiskLevel.NONE,
                typhoonRisk = RiskLevel.NONE,
                iceRisk = RiskLevel.NONE,
                fogRisk = RiskLevel.LOW,
                stormRisk = RiskLevel.MEDIUM
            ),
            seasonalRestrictions = mapOf(
                7 to setOf(PortRestriction.REDUCED_CAPACITY),
                8 to setOf(PortRestriction.REDUCED_CAPACITY)
            )
        ),
        politicalStability = PoliticalStability(
            stabilityRating = 7,
            securityLevel = SecurityLevel.HIGH,
            corruptionIndex = 0.25,
            tradeAgreements = setOf("GCC", "Various FTAs"),
            sanctions = emptySet(),
            stabilityFactor = 1.1
        ),
        infrastructure = PortInfrastructure(
            roadQuality = InfrastructureQuality.EXCELLENT,
            railQuality = InfrastructureQuality.BASIC,
            craneCapacity = 100,
            numberOfCranes = 120,
            waterDepth = 18.0,
            berthLength = 30000,
            digitalSystems = DigitalCapability(
                automatedSystems = true,
                realTimeTracking = true,
                ediIntegration = true,
                predictiveAnalytics = true,
                iotSensors = true
            ),
            overallRating = 1.6
        ),
        costs = PortCosts(
            berthingFee = 6000.0,
            handlingCost = mapOf(
                CommodityType.FUEL to 28.0,
                CommodityType.LUXURY_GOODS to 120.0,
                CommodityType.ELECTRONICS to 55.0
            ),
            storageeCost = mapOf(
                CommodityType.FUEL to 2.5,
                CommodityType.LUXURY_GOODS to 20.0,
                CommodityType.ELECTRONICS to 8.0
            ),
            fuelCost = 0.7,
            pilotage = 2500.0,
            towage = 2000.0,
            agencyFees = 1000.0,
            customs = 400.0,
            security = 600.0
        ),
        description = "Major Middle Eastern hub port and free zone"
    )
    
    /**
     * All available ports in the game world
     */
    val ALL_PORTS = listOf(
        SHANGHAI, SINGAPORE, ROTTERDAM, LOS_ANGELES, DUBAI
        // Add more ports as needed
    )
    
    /**
     * Ports grouped by region for easy lookup
     */
    val PORTS_BY_REGION = ALL_PORTS.groupBy { it.region }
    
    /**
     * Ports indexed by ID for fast lookup
     */
    val PORTS_BY_ID = ALL_PORTS.associateBy { it.id }
    
    /**
     * Major shipping routes between regions
     */
    val MAJOR_SHIPPING_LANES = listOf(
        "Asia Pacific" to "Europe",
        "Asia Pacific" to "North America", 
        "Europe" to "North America",
        "Middle East" to "Asia Pacific",
        "Middle East" to "Europe"
    )
}