package com.flexport.game.ecs.core

import java.util.UUID

/**
 * Entity represents a unique game object in the ECS system.
 * It's essentially just an ID with associated components.
 */
class Entity(
    val id: String = UUID.randomUUID().toString()
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is Entity) return false
        return id == other.id
    }

    override fun hashCode(): Int {
        return id.hashCode()
    }

    override fun toString(): String {
        return "Entity(id='$id')"
    }
}