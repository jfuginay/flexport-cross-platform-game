package com.flexport.game.viewmodels

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.flexport.game.models.Port
import com.flexport.game.models.Ship
import com.flexport.game.models.GeographicalPosition
import com.flexport.game.models.PortType
import com.flexport.game.models.ShipType
import com.flexport.game.networking.GameAction
import com.flexport.game.networking.GameMode
import com.flexport.game.networking.MultiplayerManager
import com.flexport.game.rendering.Route
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import java.util.*

/**
 * ViewModel for managing game state across configuration changes
 */
class GameViewModel(application: Application) : AndroidViewModel(application) {
    
    private val multiplayerManager = MultiplayerManager.getInstance(application)
    
    // Game state
    private val _ships = MutableStateFlow<List<Ship>>(emptyList())
    val ships: StateFlow<List<Ship>> = _ships.asStateFlow()
    
    private val _ports = MutableStateFlow<List<Port>>(emptyList())
    val ports: StateFlow<List<Port>> = _ports.asStateFlow()
    
    private val _routes = MutableStateFlow<List<Route>>(emptyList())
    val routes: StateFlow<List<Route>> = _routes.asStateFlow()
    
    private val _money = MutableStateFlow(1_000_000.0)
    val money: StateFlow<Double> = _money.asStateFlow()
    
    private val _selectedShip = MutableStateFlow<Ship?>(null)
    val selectedShip: StateFlow<Ship?> = _selectedShip.asStateFlow()
    
    // Fleet statistics
    val totalFleetCapacity: StateFlow<Int> = ships.map { shipList ->
        shipList.sumOf { it.capacity }
    }.stateIn(viewModelScope, SharingStarted.Lazily, 0)
    
    val fleetUtilization: StateFlow<Float> = combine(ships, routes) { shipList, routeList ->
        if (shipList.isEmpty()) return@combine 0f
        val activeShips = shipList.count { ship ->
            routeList.any { route -> isShipOnRoute(ship, route) }
        }
        activeShips.toFloat() / shipList.size
    }.stateIn(viewModelScope, SharingStarted.Lazily, 0f)
    
    init {
        initializeGameData()
        observeMultiplayerEvents()
    }
    
    private fun initializeGameData() {
        // Initialize with sample data
        _ports.value = listOf(
            Port(
                id = UUID.randomUUID().toString(),
                name = "Shanghai",
                position = GeographicalPosition(31.2304, 121.4737),
                type = PortType.SEA,
                capacity = 50000
            ),
            Port(
                id = UUID.randomUUID().toString(),
                name = "Singapore",
                position = GeographicalPosition(1.3521, 103.8198),
                type = PortType.SEA,
                capacity = 45000
            ),
            Port(
                id = UUID.randomUUID().toString(),
                name = "Rotterdam",
                position = GeographicalPosition(51.9244, 4.4777),
                type = PortType.SEA,
                capacity = 40000
            ),
            Port(
                id = UUID.randomUUID().toString(),
                name = "Los Angeles",
                position = GeographicalPosition(33.7701, -118.1937),
                type = PortType.SEA,
                capacity = 35000
            )
        )
        
        _ships.value = listOf(
            Ship(
                id = UUID.randomUUID().toString(),
                name = "FlexPort Pioneer",
                type = ShipType.CONTAINER_SHIP,
                capacity = 5000,
                speed = 22.5,
                fuelEfficiency = 85.0,
                maintenanceCost = 15000.0,
                purchasePrice = 1200000.0,
                currentPosition = GeographicalPosition(37.7749, -122.4194)
            ),
            Ship(
                id = UUID.randomUUID().toString(),
                name = "FlexPort Express",
                type = ShipType.CONTAINER_SHIP,
                capacity = 8000,
                speed = 25.0,
                fuelEfficiency = 78.0,
                maintenanceCost = 22000.0,
                purchasePrice = 1500000.0,
                currentPosition = GeographicalPosition(40.7128, -74.0060)
            ),
            Ship(
                id = UUID.randomUUID().toString(),
                name = "FlexPort Voyager", 
                type = ShipType.CONTAINER_SHIP,
                capacity = 12000,
                speed = 20.0,
                fuelEfficiency = 92.0,
                maintenanceCost = 28000.0,
                purchasePrice = 2200000.0,
                currentPosition = GeographicalPosition(51.5074, -0.1278)
            )
        )
    }
    
    private fun observeMultiplayerEvents() {
        viewModelScope.launch {
            multiplayerManager.gameEvents.collect { event ->
                when (event) {
                    is com.flexport.game.networking.GameEvent.ActionReceived -> {
                        handleGameAction(event.action)
                    }
                    is com.flexport.game.networking.GameEvent.StateUpdated -> {
                        updateGameState(event.update)
                    }
                    else -> { /* Handle other events */ }
                }
            }
        }
    }
    
    private fun handleGameAction(action: GameAction) {
        when (action.actionType) {
            "MOVE_SHIP" -> {
                val shipId = action.parameters["shipId"]
                val targetPortId = action.parameters["targetPortId"]
                if (shipId != null && targetPortId != null) {
                    moveShipToPort(shipId, targetPortId)
                }
            }
            "BUY_SHIP" -> {
                val shipType = action.parameters["shipType"]
                if (shipType != null) {
                    purchaseShip(shipType)
                }
            }
            "CREATE_ROUTE" -> {
                val startPortId = action.parameters["startPortId"]
                val endPortId = action.parameters["endPortId"]
                if (startPortId != null && endPortId != null) {
                    createRoute(startPortId, endPortId)
                }
            }
        }
    }
    
    private fun updateGameState(update: com.flexport.game.networking.GameStateUpdate) {
        // Update money and other state from server
        update.playerStates[multiplayerManager.currentSession.value?.players?.firstOrNull()?.id]?.let { playerState ->
            _money.value = playerState.money
        }
    }
    
    // Game actions
    fun selectShip(ship: Ship) {
        _selectedShip.value = ship
    }
    
    fun assignShipToRoute(ship: Ship) {
        viewModelScope.launch {
            // TODO: Show route selection dialog
            // For now, assign to first available route
            _routes.value.firstOrNull()?.let { route ->
                val action = GameAction(
                    playerId = getCurrentPlayerId(),
                    actionType = "ASSIGN_SHIP_ROUTE",
                    parameters = mapOf(
                        "shipId" to ship.id,
                        "routeId" to route.id
                    )
                )
                multiplayerManager.sendGameAction(action)
            }
        }
    }
    
    fun startMultiplayerGame(mode: GameMode = GameMode.REALTIME) {
        viewModelScope.launch {
            try {
                multiplayerManager.startMultiplayerGame(mode)
            } catch (e: Exception) {
                // Handle error
            }
        }
    }
    
    private fun moveShipToPort(shipId: String, targetPortId: String) {
        // Update ship position/route
        // This would integrate with the movement system
    }
    
    private fun purchaseShip(shipType: String) {
        // Add new ship to fleet
        val newShip = Ship(
            id = UUID.randomUUID().toString(),
            name = "FlexPort $shipType ${_ships.value.size + 1}",
            capacity = when (shipType) {
                "small" -> 3000
                "medium" -> 8000
                "large" -> 15000
                else -> 5000
            },
            speed = when (shipType) {
                "small" -> 28.0
                "medium" -> 23.0
                "large" -> 18.0
                else -> 22.0
            },
            type = ShipType.CONTAINER_SHIP,
            fuelEfficiency = 80.0,
            purchasePrice = when (shipType) {
                "small" -> 500_000.0
                "medium" -> 1_200_000.0
                "large" -> 2_500_000.0
                else -> 800_000.0
            },
            currentPosition = GeographicalPosition(40.7128, -74.0060),
            maintenanceCost = when (shipType) {
                "small" -> 10000.0
                "medium" -> 20000.0
                "large" -> 35000.0
                else -> 15000.0
            }
        )
        
        val cost = when (shipType) {
            "small" -> 500_000.0
            "medium" -> 1_200_000.0
            "large" -> 2_500_000.0
            else -> 800_000.0
        }
        
        if (_money.value >= cost) {
            _ships.value = _ships.value + newShip
            _money.value -= cost
        }
    }
    
    private fun createRoute(startPortId: String, endPortId: String) {
        val newRoute = Route(
            id = UUID.randomUUID().toString(),
            startPortId = startPortId,
            endPortId = endPortId
        )
        _routes.value = _routes.value + newRoute
    }
    
    private fun isShipOnRoute(ship: Ship, route: Route): Boolean {
        // TODO: Implement route assignment tracking
        return false
    }
    
    private fun getCurrentPlayerId(): String {
        return multiplayerManager.currentSession.value?.players?.firstOrNull()?.id ?: "local"
    }
}

