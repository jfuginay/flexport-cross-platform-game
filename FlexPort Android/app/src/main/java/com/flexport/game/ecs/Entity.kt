package com.flexport.game.ecs

import kotlinx.serialization.Serializable
import java.util.*

/**
 * Entity in the Entity-Component-System architecture.
 * An entity is simply a unique identifier that can have components attached.
 */
@Serializable
data class Entity(
    val id: String = UUID.randomUUID().toString(),
    val active: Boolean = true
) {
    companion object {
        fun create(): Entity {
            return Entity()
        }
        
        fun create(id: String): Entity {
            return Entity(id = id)
        }
    }
    
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is Entity) return false
        return id == other.id
    }
    
    override fun hashCode(): Int {
        return id.hashCode()
    }
}