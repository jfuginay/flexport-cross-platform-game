package com.flexport.ecs

import com.flexport.ecs.components.*
import com.flexport.ecs.core.World
import com.flexport.ecs.systems.*
import kotlinx.coroutines.runBlocking

/**
 * Example usage of the ECS system for FlexPort game
 */
class ECSExample {
    
    fun demonstrateECS() = runBlocking {
        // Create the ECS world
        val world = World()
        
        // Create a simple renderer implementation for demo
        val renderer = object : Renderer {
            override fun beginFrame() {
                println("=== Begin Frame ===")
            }
            
            override fun drawSprite(
                textureId: String,
                x: Float,
                y: Float,
                width: Float,
                height: Float,
                rotation: Float,
                tint: Int
            ) {
                println("Drawing $textureId at ($x, $y)")
            }
            
            override fun endFrame() {
                println("=== End Frame ===")
            }
        }
        
        // Create collision handler
        val collisionHandler = object : CollisionHandler {
            override suspend fun onCollision(entityA: Entity, entityB: Entity, distance: Float) {
                println("Collision detected between $entityA and $entityB at distance $distance")
            }
        }
        
        // Register systems
        world.registerSystem(MovementSystem(world.entityManager))
        world.registerSystem(RenderingSystem(world.entityManager, renderer))
        world.registerSystem(EconomicUpdateSystem(world.entityManager))
        world.registerSystem(CollisionSystem(world.entityManager, collisionHandler))
        
        // Create a ship entity
        val ship = world.entityManager.createEntity()
        world.entityManager.addComponent(ship, PositionComponent(100f, 100f, 0f))
        world.entityManager.addComponent(ship, VelocityComponent(10f, 5f, 0.1f, 50f))
        world.entityManager.addComponent(ship, RenderComponent(
            textureId = "ship_texture",
            width = 64f,
            height = 32f,
            layer = 1
        ))
        world.entityManager.addComponent(ship, AssetComponent(
            assetType = AssetType.SHIP,
            assetId = "ship_001",
            name = "Cargo Vessel Alpha",
            capacity = 1000,
            maintenanceCost = 100f
        ))
        world.entityManager.addComponent(ship, EconomicComponent(
            balance = 10000f,
            creditLimit = 5000f
        ))
        
        // Create a port entity
        val port = world.entityManager.createEntity()
        world.entityManager.addComponent(port, PositionComponent(500f, 300f))
        world.entityManager.addComponent(port, RenderComponent(
            textureId = "port_texture",
            width = 128f,
            height = 128f,
            layer = 0
        ))
        world.entityManager.addComponent(port, AssetComponent(
            assetType = AssetType.PORT,
            assetId = "port_001",
            name = "Shanghai Port",
            capacity = 10000
        ))
        world.entityManager.addComponent(port, EconomicComponent(
            balance = 1000000f
        ))
        
        // Create multiple cargo ships for performance testing
        repeat(100) { i ->
            val cargoShip = world.entityManager.createEntity()
            world.entityManager.addComponent(cargoShip, PositionComponent(
                x = (Math.random() * 1000).toFloat(),
                y = (Math.random() * 1000).toFloat()
            ))
            world.entityManager.addComponent(cargoShip, VelocityComponent(
                dx = (Math.random() * 20 - 10).toFloat(),
                dy = (Math.random() * 20 - 10).toFloat()
            ))
            world.entityManager.addComponent(cargoShip, RenderComponent(
                textureId = "small_ship_texture",
                width = 32f,
                height = 16f
            ))
        }
        
        println("Created ${world.entityManager.getEntityCount()} entities")
        
        // Start the world
        world.start()
        
        // Run for a few seconds
        kotlinx.coroutines.delay(3000)
        
        // Stop and dispose
        world.stop()
        world.dispose()
        
        println("ECS demo completed")
    }
    
    /**
     * Example of economic transaction between entities
     */
    suspend fun demonstrateEconomicTransaction(world: World) {
        val seller = world.entityManager.createEntity()
        val buyer = world.entityManager.createEntity()
        
        // Set up seller with cargo
        world.entityManager.addComponent(seller, EconomicComponent(balance = 1000f).apply {
            addCargo(CargoType.ELECTRONICS, 100, 50f)
        })
        
        // Set up buyer with money
        world.entityManager.addComponent(buyer, EconomicComponent(balance = 10000f))
        
        // Perform transaction
        val sellerEcon = world.entityManager.getComponent(seller, EconomicComponent::class)!!
        val buyerEcon = world.entityManager.getComponent(buyer, EconomicComponent::class)!!
        
        val cargoType = CargoType.ELECTRONICS
        val quantity = 50
        val pricePerUnit = 60f
        val totalPrice = quantity * pricePerUnit
        
        if (buyerEcon.canAfford(totalPrice) && sellerEcon.removeCargo(cargoType, quantity)) {
            buyerEcon.processPayment(totalPrice)
            sellerEcon.receivePayment(totalPrice)
            buyerEcon.addCargo(cargoType, quantity, pricePerUnit)
            
            println("Transaction completed: $quantity units of $cargoType for $$totalPrice")
        }
    }
}