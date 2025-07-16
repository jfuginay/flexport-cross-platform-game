package com.flexport.rendering.math

import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.tan

/**
 * 4x4 matrix implementation for 3D transformations
 */
class Matrix4 {
    val values = FloatArray(16)
    
    init {
        setToIdentity()
    }
    
    fun setToIdentity(): Matrix4 {
        values[0] = 1f; values[4] = 0f; values[8] = 0f; values[12] = 0f
        values[1] = 0f; values[5] = 1f; values[9] = 0f; values[13] = 0f
        values[2] = 0f; values[6] = 0f; values[10] = 1f; values[14] = 0f
        values[3] = 0f; values[7] = 0f; values[11] = 0f; values[15] = 1f
        return this
    }
    
    fun set(matrix: Matrix4): Matrix4 {
        System.arraycopy(matrix.values, 0, values, 0, 16)
        return this
    }
    
    fun setToOrtho(left: Float, right: Float, bottom: Float, top: Float, near: Float, far: Float): Matrix4 {
        val x_orth = 2f / (right - left)
        val y_orth = 2f / (top - bottom)
        val z_orth = -2f / (far - near)
        
        val tx = -(right + left) / (right - left)
        val ty = -(top + bottom) / (top - bottom)
        val tz = -(far + near) / (far - near)
        
        values[0] = x_orth; values[4] = 0f; values[8] = 0f; values[12] = tx
        values[1] = 0f; values[5] = y_orth; values[9] = 0f; values[13] = ty
        values[2] = 0f; values[6] = 0f; values[10] = z_orth; values[14] = tz
        values[3] = 0f; values[7] = 0f; values[11] = 0f; values[15] = 1f
        
        return this
    }
    
    fun setToLookAt(eye: Vector3, center: Vector3, up: Vector3): Matrix4 {
        val tmp = Vector3()
        
        tmp.set(eye).sub(center).nor()
        val f_x = -tmp.x
        val f_y = -tmp.y
        val f_z = -tmp.z
        
        tmp.set(up).nor()
        
        // Compute s = f x up (x means cross product)
        val s_x = f_y * tmp.z - f_z * tmp.y
        val s_y = f_z * tmp.x - f_x * tmp.z
        val s_z = f_x * tmp.y - f_y * tmp.x
        
        // Normalize s
        val ls = 1f / kotlin.math.sqrt(s_x * s_x + s_y * s_y + s_z * s_z)
        val ns_x = s_x * ls
        val ns_y = s_y * ls
        val ns_z = s_z * ls
        
        // Compute u = s x f
        val u_x = ns_y * f_z - ns_z * f_y
        val u_y = ns_z * f_x - ns_x * f_z
        val u_z = ns_x * f_y - ns_y * f_x
        
        values[0] = ns_x; values[4] = ns_y; values[8] = ns_z; values[12] = -ns_x * eye.x - ns_y * eye.y - ns_z * eye.z
        values[1] = u_x; values[5] = u_y; values[9] = u_z; values[13] = -u_x * eye.x - u_y * eye.y - u_z * eye.z
        values[2] = -f_x; values[6] = -f_y; values[10] = -f_z; values[14] = f_x * eye.x + f_y * eye.y + f_z * eye.z
        values[3] = 0f; values[7] = 0f; values[11] = 0f; values[15] = 1f
        
        return this
    }
    
    fun mul(matrix: Matrix4): Matrix4 {
        val tmp = FloatArray(16)
        val m1 = values
        val m2 = matrix.values
        
        tmp[0] = m1[0] * m2[0] + m1[4] * m2[1] + m1[8] * m2[2] + m1[12] * m2[3]
        tmp[4] = m1[0] * m2[4] + m1[4] * m2[5] + m1[8] * m2[6] + m1[12] * m2[7]
        tmp[8] = m1[0] * m2[8] + m1[4] * m2[9] + m1[8] * m2[10] + m1[12] * m2[11]
        tmp[12] = m1[0] * m2[12] + m1[4] * m2[13] + m1[8] * m2[14] + m1[12] * m2[15]
        
        tmp[1] = m1[1] * m2[0] + m1[5] * m2[1] + m1[9] * m2[2] + m1[13] * m2[3]
        tmp[5] = m1[1] * m2[4] + m1[5] * m2[5] + m1[9] * m2[6] + m1[13] * m2[7]
        tmp[9] = m1[1] * m2[8] + m1[5] * m2[9] + m1[9] * m2[10] + m1[13] * m2[11]
        tmp[13] = m1[1] * m2[12] + m1[5] * m2[13] + m1[9] * m2[14] + m1[13] * m2[15]
        
        tmp[2] = m1[2] * m2[0] + m1[6] * m2[1] + m1[10] * m2[2] + m1[14] * m2[3]
        tmp[6] = m1[2] * m2[4] + m1[6] * m2[5] + m1[10] * m2[6] + m1[14] * m2[7]
        tmp[10] = m1[2] * m2[8] + m1[6] * m2[9] + m1[10] * m2[10] + m1[14] * m2[11]
        tmp[14] = m1[2] * m2[12] + m1[6] * m2[13] + m1[10] * m2[14] + m1[14] * m2[15]
        
        tmp[3] = m1[3] * m2[0] + m1[7] * m2[1] + m1[11] * m2[2] + m1[15] * m2[3]
        tmp[7] = m1[3] * m2[4] + m1[7] * m2[5] + m1[11] * m2[6] + m1[15] * m2[7]
        tmp[11] = m1[3] * m2[8] + m1[7] * m2[9] + m1[11] * m2[10] + m1[15] * m2[11]
        tmp[15] = m1[3] * m2[12] + m1[7] * m2[13] + m1[11] * m2[14] + m1[15] * m2[15]
        
        System.arraycopy(tmp, 0, values, 0, 16)
        return this
    }
    
    fun inv(): Matrix4 {
        val l_det = det()
        if (l_det == 0f) return this
        
        val m = values
        val tmp = FloatArray(16)
        
        tmp[0] = m[5] * m[10] * m[15] - m[5] * m[11] * m[14] - m[9] * m[6] * m[15] + m[9] * m[7] * m[14] + m[13] * m[6] * m[11] - m[13] * m[7] * m[10]
        tmp[4] = -m[4] * m[10] * m[15] + m[4] * m[11] * m[14] + m[8] * m[6] * m[15] - m[8] * m[7] * m[14] - m[12] * m[6] * m[11] + m[12] * m[7] * m[10]
        tmp[8] = m[4] * m[9] * m[15] - m[4] * m[11] * m[13] - m[8] * m[5] * m[15] + m[8] * m[7] * m[13] + m[12] * m[5] * m[11] - m[12] * m[7] * m[9]
        tmp[12] = -m[4] * m[9] * m[14] + m[4] * m[10] * m[13] + m[8] * m[5] * m[14] - m[8] * m[6] * m[13] - m[12] * m[5] * m[10] + m[12] * m[6] * m[9]
        
        tmp[1] = -m[1] * m[10] * m[15] + m[1] * m[11] * m[14] + m[9] * m[2] * m[15] - m[9] * m[3] * m[14] - m[13] * m[2] * m[11] + m[13] * m[3] * m[10]
        tmp[5] = m[0] * m[10] * m[15] - m[0] * m[11] * m[14] - m[8] * m[2] * m[15] + m[8] * m[3] * m[14] + m[12] * m[2] * m[11] - m[12] * m[3] * m[10]
        tmp[9] = -m[0] * m[9] * m[15] + m[0] * m[11] * m[13] + m[8] * m[1] * m[15] - m[8] * m[3] * m[13] - m[12] * m[1] * m[11] + m[12] * m[3] * m[9]
        tmp[13] = m[0] * m[9] * m[14] - m[0] * m[10] * m[13] - m[8] * m[1] * m[14] + m[8] * m[2] * m[13] + m[12] * m[1] * m[10] - m[12] * m[2] * m[9]
        
        tmp[2] = m[1] * m[6] * m[15] - m[1] * m[7] * m[14] - m[5] * m[2] * m[15] + m[5] * m[3] * m[14] + m[13] * m[2] * m[7] - m[13] * m[3] * m[6]
        tmp[6] = -m[0] * m[6] * m[15] + m[0] * m[7] * m[14] + m[4] * m[2] * m[15] - m[4] * m[3] * m[14] - m[12] * m[2] * m[7] + m[12] * m[3] * m[6]
        tmp[10] = m[0] * m[5] * m[15] - m[0] * m[7] * m[13] - m[4] * m[1] * m[15] + m[4] * m[3] * m[13] + m[12] * m[1] * m[7] - m[12] * m[3] * m[5]
        tmp[14] = -m[0] * m[5] * m[14] + m[0] * m[6] * m[13] + m[4] * m[1] * m[14] - m[4] * m[2] * m[13] - m[12] * m[1] * m[6] + m[12] * m[2] * m[5]
        
        tmp[3] = -m[1] * m[6] * m[11] + m[1] * m[7] * m[10] + m[5] * m[2] * m[11] - m[5] * m[3] * m[10] - m[9] * m[2] * m[7] + m[9] * m[3] * m[6]
        tmp[7] = m[0] * m[6] * m[11] - m[0] * m[7] * m[10] - m[4] * m[2] * m[11] + m[4] * m[3] * m[10] + m[8] * m[2] * m[7] - m[8] * m[3] * m[6]
        tmp[11] = -m[0] * m[5] * m[11] + m[0] * m[7] * m[9] + m[4] * m[1] * m[11] - m[4] * m[3] * m[9] - m[8] * m[1] * m[7] + m[8] * m[3] * m[5]
        tmp[15] = m[0] * m[5] * m[10] - m[0] * m[6] * m[9] - m[4] * m[1] * m[10] + m[4] * m[2] * m[9] + m[8] * m[1] * m[6] - m[8] * m[2] * m[5]
        
        val inv_det = 1.0f / l_det
        for (i in 0..15) {
            values[i] = tmp[i] * inv_det
        }
        
        return this
    }
    
    fun det(): Float {
        val m = values
        return m[3] * m[6] * m[9] * m[12] - m[2] * m[7] * m[9] * m[12] - m[3] * m[5] * m[10] * m[12] + m[1] * m[7] * m[10] * m[12] +
               m[2] * m[5] * m[11] * m[12] - m[1] * m[6] * m[11] * m[12] - m[3] * m[6] * m[8] * m[13] + m[2] * m[7] * m[8] * m[13] +
               m[3] * m[4] * m[10] * m[13] - m[0] * m[7] * m[10] * m[13] - m[2] * m[4] * m[11] * m[13] + m[0] * m[6] * m[11] * m[13] +
               m[3] * m[5] * m[8] * m[14] - m[1] * m[7] * m[8] * m[14] - m[3] * m[4] * m[9] * m[14] + m[0] * m[7] * m[9] * m[14] +
               m[1] * m[4] * m[11] * m[14] - m[0] * m[5] * m[11] * m[14] - m[2] * m[5] * m[8] * m[15] + m[1] * m[6] * m[8] * m[15] +
               m[2] * m[4] * m[9] * m[15] - m[0] * m[6] * m[9] * m[15] - m[1] * m[4] * m[10] * m[15] + m[0] * m[5] * m[10] * m[15]
    }
}