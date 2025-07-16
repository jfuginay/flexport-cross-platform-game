# FlexPort Touch Input System

A comprehensive touch input and gesture handling system for the FlexPort Android game, designed for smooth 60fps performance with multi-touch support and seamless ECS integration.

## Features

### Core Touch Input
- **Multi-touch gesture detection** (pan, zoom, tap, long press, drag)
- **World/screen coordinate conversion** integrated with camera system
- **High-performance input processing** with object pooling and batching
- **Haptic feedback system** with customizable intensity and patterns
- **Input state management** with proper edge case handling

### Game-Specific Interactions
- **Entity selection** with single/multi-select and box selection
- **Camera controls** with pan, zoom, and momentum
- **Trade route creation** through drag gestures with snap-to targeting
- **Context menus** via long press
- **Touch feedback** with haptic responses

### Performance Optimizations
- **Object pooling** for Vector2, TouchEvent, and GestureEvent instances
- **Input batching** to maintain 60fps performance
- **Spatial partitioning** for efficient hit testing
- **Input deduplication** to reduce redundant processing
- **Frame rate limiting** for input processing

## Architecture

### Core Components

#### TouchInputManager
Central manager for all touch input with coordinate conversion and event pooling.

```kotlin
val touchInputManager = TouchInputManager(camera)
touchInputManager.touchEvents.collect { event ->
    // Handle touch events
}
```

#### Gesture Detection
- `GestureDetector` - Single touch gestures (tap, long press, pan, drag)
- `MultiTouchGestureDetector` - Multi-touch gestures (pinch, two-finger pan)

#### ECS Integration
- `TouchableComponent` - Makes entities touchable with configurable bounds
- `SelectableComponent` - Enables entity selection with callbacks
- `InteractableComponent` - Advanced interaction support with gesture handling
- `TouchInputSystem` - ECS system that processes touch events for entities

### Game-Specific Handlers

#### CameraController
Handles camera controls through touch input:
- Single finger pan to move camera
- Pinch to zoom in/out
- Momentum and smooth movement
- World bounds constraints

#### SelectionManager
Manages entity selection:
- Single/multiple selection modes
- Box selection with drag gestures
- Selection events and callbacks
- Visual feedback integration

#### RouteCreationHandler
Handles trade route creation:
- Drag from port/ship to create routes
- Snap-to targeting for nearby entities
- Route validation and feedback
- Visual route preview during creation

## Usage

### Basic Setup

```kotlin
// Initialize the complete touch input system
val integration = TouchInputIntegration(
    context = this,
    gameSurfaceView = surfaceView,
    camera = camera,
    entityManager = entityManager
)

// Initialize all systems
integration.initialize()

// In your game loop
integration.update(deltaTime)
```

### Adding Touch Components to Entities

```kotlin
// Make an entity touchable
val entity = entityManager.createEntity()
entity.addComponent(PositionComponent(100f, 100f))
entity.addComponent(TouchableComponent().apply {
    setBoundsFromCenter(100f, 100f, 64f, 64f)
    priority = 10
})

// Make it selectable
entity.addComponent(SelectableComponent().apply {
    selectionCallback = { selected ->
        println("Entity selection changed: $selected")
    }
})

// Add interactions
entity.addComponent(InteractableComponent().apply {
    supportsTap = true
    supportsLongPress = true
    supportsDrag = true
    onTapCallback = { println("Entity tapped!") }
    onLongPressCallback = { println("Entity long pressed!") }
})
```

### Input Modes

```kotlin
// Switch to different input modes
integration.setInputMode(InputMode.NORMAL)        // All interactions enabled
integration.setInputMode(InputMode.CAMERA_ONLY)   // Only camera controls
integration.setInputMode(InputMode.ROUTE_CREATION) // Route creation mode
integration.setInputMode(InputMode.SELECTION_ONLY) // Selection only
integration.setInputMode(InputMode.DISABLED)      // All input disabled
```

### Haptic Feedback

```kotlin
// Configure haptic feedback
integration.setHapticEnabled(true)
integration.setHapticIntensity(0.8f)

// Manual haptic triggers
val hapticManager = HapticFeedbackManager(context)
hapticManager.triggerHaptic(HapticType.TAP, intensity = 0.5f)
hapticManager.triggerHaptic(HapticType.SUCCESS, intensity = 1.0f)
```

### Performance Monitoring

```kotlin
// Get performance statistics
val stats = integration.getInputPerformanceStats()
println("Events processed: ${stats.totalEventsProcessed}")
println("Drop rate: ${stats.dropRate}")
println("Batch efficiency: ${stats.batchEfficiency}")

// Reset statistics
integration.resetInputPerformanceStats()
```

## Configuration

### Touch Sensitivity

```kotlin
// Configure gesture detection sensitivity
val gestureDetector = GestureDetector(
    tapTimeout = 150L,        // Max time for tap
    longPressTimeout = 500L,  // Time for long press
    touchSlop = 10f,          // Movement threshold
    minimumFlingVelocity = 100f,
    maximumFlingVelocity = 8000f
)
```

### Camera Controls

```kotlin
cameraController.isPanEnabled = true
cameraController.isZoomEnabled = true
cameraController.panSensitivity = 1.0f
cameraController.zoomSensitivity = 1.0f
cameraController.smoothingEnabled = true
cameraController.smoothingFactor = 0.1f
cameraController.setWorldBounds(-5000f, -5000f, 10000f, 10000f)
```

### Selection Behavior

```kotlin
selectionManager.setSelectionMode(SelectionMode.MULTIPLE)
selectionManager.allowBoxSelection = true
selectionManager.boxSelectionMinDistance = 20f
```

### Route Creation

```kotlin
routeCreationHandler.minimumDragDistance = 50f
routeCreationHandler.snapDistance = 100f
routeCreationHandler.allowSelfRoutes = false
```

## Performance Tips

1. **Use object pooling** - The system automatically pools Vector2 and event objects
2. **Enable input batching** - Events are batched at 60fps intervals
3. **Optimize touch bounds** - Use appropriate sizes for touchable areas
4. **Limit entity counts** - Use spatial partitioning for large numbers of touchable entities
5. **Profile regularly** - Monitor performance stats to identify bottlenecks

## Events and Callbacks

### Touch Events
- `TouchEvent.TouchAction.DOWN` - Finger down
- `TouchEvent.TouchAction.MOVE` - Finger movement
- `TouchEvent.TouchAction.UP` - Finger up
- `TouchEvent.TouchAction.CANCEL` - Touch cancelled

### Gesture Events
- `GestureEvent.Tap` - Single tap
- `GestureEvent.LongPress` - Long press
- `GestureEvent.Pan` - Single finger pan
- `GestureEvent.Pinch` - Pinch to zoom
- `GestureEvent.Drag*` - Drag operations

### Selection Events
- `SelectionEvent.EntitySelected` - Entity was selected
- `SelectionEvent.EntityDeselected` - Entity was deselected
- `SelectionEvent.SelectionCleared` - All selections cleared
- `SelectionEvent.BoxSelection*` - Box selection events

### Route Events
- `RouteEvent.RouteCreationStarted` - Route creation began
- `RouteEvent.RouteCreationUpdated` - Route preview updated
- `RouteEvent.RouteCreationCompleted` - Route creation finished
- `RouteEvent.RouteCreationCancelled` - Route creation cancelled

## File Structure

```
com.flexport.input/
├── TouchEvent.kt                    # Touch event data classes
├── TouchInputManager.kt             # Central input manager
├── GestureDetector.kt              # Single touch gesture detection
├── MultiTouchGestureDetector.kt    # Multi-touch gesture detection
├── HapticFeedbackManager.kt        # Haptic feedback system
├── InputPerformanceOptimizer.kt    # Performance optimizations
├── TouchInputIntegration.kt        # Complete integration example
└── interactions/
    ├── CameraController.kt         # Camera control handler
    ├── SelectionManager.kt         # Entity selection management
    └── RouteCreationHandler.kt     # Trade route creation
```

## Second Best Alternative Approach

If you needed a simpler touch input system without the full ECS integration, the second best approach would have been to create a traditional Android View-based touch handling system using:

1. **Custom View with onTouchEvent override** - Direct touch handling in view hierarchy
2. **GestureDetector from Android SDK** - Using built-in gesture detection
3. **Simple callback interfaces** - Basic touch listeners without complex event flows
4. **Manual coordinate conversion** - Basic screen-to-world conversion without camera integration
5. **Direct entity querying** - Linear search through entities instead of spatial optimization

This approach would be simpler to implement but less performant and flexible than the comprehensive ECS-integrated system provided here.