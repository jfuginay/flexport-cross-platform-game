package com.flexport.rendering.math

import kotlin.math.sqrt

/**
 * 3D vector implementation
 */
data class Vector3(
    var x: Float = 0f,
    var y: Float = 0f,
    var z: Float = 0f
) {
    
    fun set(x: Float, y: Float, z: Float): Vector3 {
        this.x = x
        this.y = y
        this.z = z
        return this
    }
    
    fun set(v: Vector3): Vector3 {
        this.x = v.x
        this.y = v.y
        this.z = v.z
        return this
    }
    
    fun add(x: Float, y: Float, z: Float): Vector3 {
        this.x += x
        this.y += y
        this.z += z
        return this
    }
    
    fun add(v: Vector3): Vector3 {
        this.x += v.x
        this.y += v.y
        this.z += v.z
        return this
    }
    
    fun sub(x: Float, y: Float, z: Float): Vector3 {
        this.x -= x
        this.y -= y
        this.z -= z
        return this
    }
    
    fun sub(v: Vector3): Vector3 {
        this.x -= v.x
        this.y -= v.y
        this.z -= v.z
        return this
    }
    
    fun mul(scalar: Float): Vector3 {
        this.x *= scalar
        this.y *= scalar
        this.z *= scalar
        return this
    }
    
    fun mul(matrix: Matrix4): Vector3 {
        val l_mat = matrix.values
        this.set(
            x * l_mat[0] + y * l_mat[4] + z * l_mat[8] + l_mat[12],
            x * l_mat[1] + y * l_mat[5] + z * l_mat[9] + l_mat[13],
            x * l_mat[2] + y * l_mat[6] + z * l_mat[10] + l_mat[14]
        )
        return this
    }
    
    fun prj(matrix: Matrix4): Vector3 {
        val l_mat = matrix.values
        val l_w = 1f / (x * l_mat[3] + y * l_mat[7] + z * l_mat[11] + l_mat[15])
        this.set(
            (x * l_mat[0] + y * l_mat[4] + z * l_mat[8] + l_mat[12]) * l_w,
            (x * l_mat[1] + y * l_mat[5] + z * l_mat[9] + l_mat[13]) * l_w,
            (x * l_mat[2] + y * l_mat[6] + z * l_mat[10] + l_mat[14]) * l_w
        )
        return this
    }
    
    fun len(): Float = sqrt(x * x + y * y + z * z)
    
    fun len2(): Float = x * x + y * y + z * z
    
    fun nor(): Vector3 {
        val len = len()
        if (len != 0f) {
            x /= len
            y /= len
            z /= len
        }
        return this
    }
    
    fun cpy(): Vector3 = Vector3(x, y, z)
    
    companion object {
        val ZERO = Vector3(0f, 0f, 0f)
        val ONE = Vector3(1f, 1f, 1f)
        val X = Vector3(1f, 0f, 0f)
        val Y = Vector3(0f, 1f, 0f)
        val Z = Vector3(0f, 0f, 1f)
    }
}