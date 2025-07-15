package com.flexport.game.ecs.core

import kotlin.reflect.KClass

/**
 * Base interface for all components in the ECS system.
 * Components are pure data containers with no logic.
 */
interface Component

/**
 * Type alias for component classes
 */
typealias ComponentType = KClass<out Component>