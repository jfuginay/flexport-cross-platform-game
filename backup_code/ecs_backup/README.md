# FlexPort ECS Architecture

## Overview
This Entity Component System (ECS) implementation provides a performant and scalable architecture for the FlexPort Android game. It's designed to handle thousands of entities (ships, routes, ports) efficiently using Kotlin coroutines for concurrent processing.

## Core Components

### Entity Management
- **Entity**: Lightweight ID-based game objects
- **EntityManager**: Thread-safe management of entities and components
- **World**: Main engine coordinating systems and entities

### Components (Data)
- **PositionComponent**: 2D position and rotation
- **VelocityComponent**: Movement speed and direction
- **RenderComponent**: Visual representation data
- **AssetComponent**: Game assets (ships, warehouses, ports)
- **EconomicComponent**: Financial data and cargo management

### Systems (Logic)
- **MovementSystem**: Updates positions based on velocity
- **RenderingSystem**: Manages visual rendering
- **EconomicUpdateSystem**: Handles economic calculations
- **CollisionSystem**: Spatial collision detection with grid optimization

## Key Features

### Performance Optimizations
- Concurrent system updates using Kotlin coroutines
- Spatial grid for efficient collision detection
- Chunked parallel processing for large entity counts
- Component storage using ConcurrentHashMap for thread safety

### Usage Example
```kotlin
val world = World()

// Register systems
world.registerSystem(MovementSystem(world.entityManager))
world.registerSystem(RenderingSystem(world.entityManager, renderer))

// Create entity
val ship = world.entityManager.createEntity()
world.entityManager.addComponent(ship, PositionComponent(100f, 100f))
world.entityManager.addComponent(ship, VelocityComponent(10f, 5f))

// Start world
world.start()
```

## Architecture Benefits
- **Composition over Inheritance**: Flexible entity creation
- **Data-Oriented Design**: Cache-friendly component storage
- **Parallel Processing**: Leverages coroutines for performance
- **Scalability**: Handles thousands of entities efficiently
- **Maintainability**: Clear separation of data and logic

## Second Best Alternative
The second best approach would have been using a traditional GameObject hierarchy with inheritance, which is simpler to understand but less flexible and performant for large-scale simulations like FlexPort.