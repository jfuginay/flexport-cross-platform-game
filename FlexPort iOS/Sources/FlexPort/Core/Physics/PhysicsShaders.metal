#include <metal_stdlib>
using namespace metal;

struct ShipPhysicsData {
    float3 position;
    float3 velocity;
    float3 acceleration;
    float mass;
    float drag;
    float efficiency;
    float fuelLevel;
    float speed;
};

struct WeatherData {
    float2 windVelocity;
    float waveHeight;
    float visibility;
    float stormIntensity;
};

struct OceanCurrentData {
    float2 currentVelocity;
    float strength;
    float temperature;
};

/// Physics kernel for ship movement calculations
kernel void physicsKernel(device ShipPhysicsData* ships [[buffer(0)]],
                         device WeatherData* weatherCells [[buffer(1)]],
                         device OceanCurrentData* oceanCurrents [[buffer(2)]],
                         constant float& deltaTime [[buffer(3)]],
                         constant uint& shipCount [[buffer(4)]],
                         uint id [[thread_position_in_grid]]) {
    
    if (id >= shipCount) return;
    
    ShipPhysicsData ship = ships[id];
    
    // Calculate environmental forces
    float2 windForce = float2(0, 0);
    float2 currentForce = float2(0, 0);
    float waveResistance = 1.0;
    
    // Sample weather at ship position (simplified grid lookup)
    uint2 gridPos = uint2(ship.position.x / 100.0, ship.position.y / 100.0);
    uint weatherIndex = min(gridPos.y * 100 + gridPos.x, 9999u); // Assuming 100x100 grid
    WeatherData weather = weatherCells[weatherIndex];
    
    // Apply wind effects
    windForce = weather.windVelocity * 0.1; // Wind contribution to movement
    
    // Apply wave resistance
    waveResistance = 1.0 - (weather.waveHeight * 0.1);
    
    // Sample ocean current
    uint currentIndex = min(id / 4, 99u); // Multiple ships per current cell
    OceanCurrentData current = oceanCurrents[currentIndex];
    currentForce = current.currentVelocity * current.strength * 0.05;
    
    // Calculate total force
    float2 environmentalForce = windForce + currentForce;
    
    // Apply forces to ship movement
    float3 totalForce = float3(environmentalForce.x, environmentalForce.y, 0);
    
    // Add propulsion force (based on ship's intended direction and speed)
    float3 propulsionForce = normalize(ship.velocity) * ship.speed * ship.efficiency;
    totalForce += propulsionForce;
    
    // Apply drag
    float3 dragForce = -ship.velocity * ship.drag * 0.5;
    totalForce += dragForce;
    
    // Apply wave resistance
    totalForce *= waveResistance;
    
    // Newton's second law: F = ma
    ship.acceleration = totalForce / ship.mass;
    
    // Integrate velocity
    ship.velocity += ship.acceleration * deltaTime;
    
    // Integrate position
    ship.position += ship.velocity * deltaTime;
    
    // Update fuel consumption
    float fuelConsumption = length(ship.velocity) * 0.001 * deltaTime;
    ship.fuelLevel = max(0.0, ship.fuelLevel - fuelConsumption);
    
    // Reduce efficiency if low on fuel
    if (ship.fuelLevel < 0.1) {
        ship.efficiency *= 0.5;
    }
    
    // Apply velocity damping for stability
    ship.velocity *= 0.99;
    
    // Write back results
    ships[id] = ship;
}

/// Pathfinding kernel for A* algorithm acceleration
kernel void pathfindingKernel(device float* costField [[buffer(0)]],
                             device uint2* gridPositions [[buffer(1)]],
                             device float* distances [[buffer(2)]],
                             constant uint2& gridSize [[buffer(3)]],
                             constant uint2& target [[buffer(4)]],
                             uint id [[thread_position_in_grid]]) {
    
    if (id >= gridSize.x * gridSize.y) return;
    
    uint2 pos = gridPositions[id];
    
    // Calculate Manhattan distance heuristic
    uint2 delta = abs(int2(target) - int2(pos));
    float heuristic = float(delta.x + delta.y);
    
    // Get terrain cost
    float terrainCost = costField[pos.y * gridSize.x + pos.x];
    
    // Calculate total cost estimate
    float totalCost = terrainCost + heuristic;
    
    distances[id] = totalCost;
}

/// Weather simulation kernel
kernel void weatherSimulationKernel(device WeatherData* weatherCells [[buffer(0)]],
                                   constant float& deltaTime [[buffer(1)]],
                                   constant uint& cellCount [[buffer(2)]],
                                   uint id [[thread_position_in_grid]]) {
    
    if (id >= cellCount) return;
    
    WeatherData cell = weatherCells[id];
    
    // Simulate weather evolution
    // Add some chaos and natural variation
    float noise = sin(float(id) * 0.1 + deltaTime * 0.5) * 0.1;
    
    // Evolve wind
    cell.windVelocity.x += noise * 0.5;
    cell.windVelocity.y += noise * 0.3;
    
    // Clamp wind velocity
    float windMagnitude = length(cell.windVelocity);
    if (windMagnitude > 25.0) {
        cell.windVelocity = normalize(cell.windVelocity) * 25.0;
    }
    
    // Evolve wave height based on wind
    cell.waveHeight += (windMagnitude * 0.1 - cell.waveHeight) * deltaTime * 0.1;
    cell.waveHeight = clamp(cell.waveHeight, 0.0, 10.0);
    
    // Evolve visibility (inverse correlation with storm intensity)
    cell.visibility = max(0.1, 1.0 - cell.stormIntensity * 0.8);
    
    // Evolve storm intensity
    cell.stormIntensity += noise * 0.05;
    cell.stormIntensity = clamp(cell.stormIntensity, 0.0, 1.0);
    
    weatherCells[id] = cell;
}

/// Economic simulation kernel for market calculations
kernel void economicSimulationKernel(device float* commodityPrices [[buffer(0)]],
                                    device float* supplies [[buffer(1)]],
                                    device float* demands [[buffer(2)]],
                                    device float* volatilities [[buffer(3)]],
                                    constant float& deltaTime [[buffer(4)]],
                                    constant uint& commodityCount [[buffer(5)]],
                                    uint id [[thread_position_in_grid]]) {
    
    if (id >= commodityCount) return;
    
    float price = commodityPrices[id];
    float supply = supplies[id];
    float demand = demands[id];
    float volatility = volatilities[id];
    
    // Supply and demand dynamics
    float supplyDemandRatio = supply / max(demand, 0.01);
    float priceChange = (1.0 / supplyDemandRatio - 1.0) * volatility;
    
    // Apply market noise
    float noise = sin(float(id) * 0.7 + deltaTime * 2.0) * volatility * 0.05;
    priceChange += noise;
    
    // Update price with damping
    price *= (1.0 + priceChange * 0.1);
    
    // Ensure price stays positive
    price = max(price, 0.01);
    
    commodityPrices[id] = price;
}

/// AI decision making kernel for parallel AI processing
kernel void aiDecisionKernel(device float* aiStates [[buffer(0)]],
                            device float* marketData [[buffer(1)]],
                            device float* decisions [[buffer(2)]],
                            constant uint& aiCount [[buffer(3)]],
                            uint id [[thread_position_in_grid]]) {
    
    if (id >= aiCount) return;
    
    // Simple AI decision making based on market conditions
    float aiMoney = aiStates[id * 4 + 0];
    float aiReputation = aiStates[id * 4 + 1];
    float aiRiskTolerance = aiStates[id * 4 + 2];
    float aiLearningRate = aiStates[id * 4 + 3];
    
    // Sample market conditions
    float marketVolatility = marketData[0];
    float marketGrowth = marketData[1];
    float competitiveness = marketData[2];
    
    // Decision scoring
    float buyShipScore = (aiMoney > 1000000.0 ? 0.3 : 0.0) + 
                        (marketGrowth > 0.02 ? 0.4 : 0.0) + 
                        (competitiveness < 0.7 ? 0.3 : 0.0);
    
    float investResearchScore = (aiMoney > 200000.0 ? 0.2 : 0.0) + 
                               (aiRiskTolerance > 0.6 ? 0.5 : 0.0) + 
                               (marketVolatility > 0.4 ? 0.3 : 0.0);
    
    float expandScore = (aiReputation > 60.0 ? 0.4 : 0.0) + 
                       (marketGrowth > 0.015 ? 0.3 : 0.0) + 
                       (aiMoney > 500000.0 ? 0.3 : 0.0);
    
    // Store decisions (simple max selection)
    float maxScore = max(max(buyShipScore, investResearchScore), expandScore);
    
    if (maxScore == buyShipScore && maxScore > 0.5) {
        decisions[id] = 1.0; // Buy ship
    } else if (maxScore == investResearchScore && maxScore > 0.5) {
        decisions[id] = 2.0; // Invest in research
    } else if (maxScore == expandScore && maxScore > 0.5) {
        decisions[id] = 3.0; // Expand operations
    } else {
        decisions[id] = 0.0; // Wait
    }
}

// MARK: - ECS-Specific Compute Kernels

struct TransformData {
    float3 position;
    float4 rotation;
    float3 scale;
    float3 velocity;
    float padding;
};

/// Transform processing kernel for ECS batch operations
kernel void transformKernel(device TransformData* transforms [[buffer(0)]],
                           device TransformData* outputTransforms [[buffer(1)]],
                           constant float& deltaTime [[buffer(2)]],
                           uint id [[thread_position_in_grid]]) {
    
    TransformData transform = transforms[id];
    
    // Apply velocity to position
    transform.position += transform.velocity * deltaTime;
    
    // Apply any rotation updates (simplified)
    // In a real implementation, this would handle quaternion math properly
    
    // Apply scale animations if needed
    // This could be driven by component data or animation systems
    
    // Apply damping to velocity
    transform.velocity *= 0.99;
    
    outputTransforms[id] = transform;
}

/// Component archetype processing kernel
kernel void archetypeProcessingKernel(device uint* entityArchetypes [[buffer(0)]],
                                     device uint* componentMasks [[buffer(1)]],
                                     device uint* outputMatches [[buffer(2)]],
                                     constant uint& entityCount [[buffer(3)]],
                                     constant uint& queryMask [[buffer(4)]],
                                     uint id [[thread_position_in_grid]]) {
    
    if (id >= entityCount) return;
    
    uint entityMask = componentMasks[id];
    
    // Check if entity matches the query mask
    bool matches = (entityMask & queryMask) == queryMask;
    
    outputMatches[id] = matches ? 1 : 0;
}

/// Spatial partitioning kernel for efficient entity queries
kernel void spatialPartitioningKernel(device float3* positions [[buffer(0)]],
                                     device uint* spatialCells [[buffer(1)]],
                                     device uint* entityIndices [[buffer(2)]],
                                     constant float& cellSize [[buffer(3)]],
                                     constant uint& entityCount [[buffer(4)]],
                                     uint id [[thread_position_in_grid]]) {
    
    if (id >= entityCount) return;
    
    float3 position = positions[id];
    
    // Calculate spatial cell coordinates
    int cellX = (int)(position.x / cellSize);
    int cellZ = (int)(position.z / cellSize);
    
    // Hash cell coordinates to a single value
    uint cellHash = (uint(cellX) * 73856093) ^ (uint(cellZ) * 19349663);
    
    spatialCells[id] = cellHash;
    entityIndices[id] = id;
}

/// Batch component update kernel for cache-efficient processing
kernel void batchComponentUpdateKernel(device void* componentData [[buffer(0)]],
                                      device uint* entityIndices [[buffer(1)]],
                                      device uint* updateFlags [[buffer(2)]],
                                      constant uint& componentSize [[buffer(3)]],
                                      constant uint& entityCount [[buffer(4)]],
                                      uint id [[thread_position_in_grid]]) {
    
    if (id >= entityCount) return;
    
    uint entityIndex = entityIndices[id];
    
    // Only update if flag is set
    if (updateFlags[entityIndex] == 0) return;
    
    // Generic component processing would happen here
    // This is a template for component-specific kernels
    
    // Clear the update flag
    updateFlags[entityIndex] = 0;
}

/// Memory compaction kernel for removing gaps in component arrays
kernel void memoryCompactionKernel(device void* sourceData [[buffer(0)]],
                                  device void* destData [[buffer(1)]],
                                  device uint* validIndices [[buffer(2)]],
                                  device uint* compactionMap [[buffer(3)]],
                                  constant uint& componentSize [[buffer(4)]],
                                  constant uint& validCount [[buffer(5)]],
                                  uint id [[thread_position_in_grid]]) {
    
    if (id >= validCount) return;
    
    uint sourceIndex = validIndices[id];
    uint destIndex = id;
    
    // Copy component data from source to destination
    char* source = (char*)sourceData + (sourceIndex * componentSize);
    char* dest = (char*)destData + (destIndex * componentSize);
    
    for (uint i = 0; i < componentSize; i++) {
        dest[i] = source[i];
    }
    
    // Update compaction mapping
    compactionMap[sourceIndex] = destIndex;
}