# FlexPort: The Video Game - Android

Modern Android implementation of FlexPort: The Video Game built with Kotlin and Jetpack Compose.

## Architecture

This project follows clean architecture principles with the following layers:

### Presentation Layer (`com.flexport.game.presentation`)
- **UI Components**: Jetpack Compose UI built with Material Design 3
- **ViewModels**: State management using Hilt and Coroutines
- **Navigation**: Compose Navigation for screen transitions
- **Screens**: Main Menu, Game, and Settings screens

### Domain Layer (`com.flexport.game.domain`)
- **Models**: Core business models (GameState, Settings)
- **Use Cases**: Business logic implementations
- **Repository Interfaces**: Abstraction for data access

### Data Layer (`com.flexport.game.data`)
- **Local**: Room database for offline storage
- **Remote**: Retrofit API client for network operations
- **Repository Implementations**: Data access layer implementations

### Core Layer (`com.flexport.game.core`)
- **Dependency Injection**: Hilt modules for DI
- **Utilities**: Common utilities and extensions
- **Constants**: App-wide constants

## Technology Stack

- **UI Framework**: Jetpack Compose with Material Design 3
- **Architecture**: MVVM with Clean Architecture
- **Dependency Injection**: Hilt
- **Async Programming**: Kotlin Coroutines and Flow
- **Local Database**: Room
- **Networking**: Retrofit with OkHttp
- **Graphics**: OpenGL ES 3.0 (with Vulkan support planned)

## Build Requirements

- Android Studio Hedgehog or newer
- Android SDK 34
- Kotlin 1.9.24
- Gradle 8.7

## Getting Started

1. Clone the repository
2. Open in Android Studio
3. Sync Gradle files
4. Run the app on an emulator or device

## Features

- Modern Material Design 3 UI
- Landscape-oriented gameplay
- Local game state persistence
- Settings management
- Graphics quality options
- Audio controls
- High-performance rendering with OpenGL ES

## Game Features (Planned)

- Ship management simulation
- Cargo delivery mechanics
- Economic progression system
- Leaderboards
- Real-time multiplayer (future)

## Development Status

This is the initial project setup with basic architecture and navigation in place. Game logic and rendering engine are next development priorities.