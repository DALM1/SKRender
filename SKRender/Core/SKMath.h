//
//  SKMath.h
//  SKRender
//
//  Created by Dimitri ALMON on 16/06/2025.
//

#ifndef SKMath_h
#define SKMath_h

#import <Foundation/Foundation.h>
#import <simd/simd.h>

typedef struct {
    vector_float3 position;
    vector_float3 normal;
    vector_float2 texCoord;
} SKVertex;

static inline matrix_float4x4 matrix_perspective_right_hand(float fovyRadians, float aspect, float nearZ, float farZ) {
    float ys = 1.0f / tanf(fovyRadians * 0.5f);
    float xs = ys / aspect;
    float zs = farZ / (nearZ - farZ);
    
    return (matrix_float4x4){{
        {xs,  0,  0,  0},
        {0,  ys,  0,  0},
        {0,   0, zs, -1},
        {0,   0, zs * nearZ, 0}
    }};
}

static inline matrix_float4x4 matrix_look_at_right_hand(vector_float3 eye, vector_float3 target, vector_float3 up) {
    vector_float3 zAxis = vector_normalize(eye - target);
    vector_float3 xAxis = vector_normalize(vector_cross(up, zAxis));
    vector_float3 yAxis = vector_cross(zAxis, xAxis);
    
    return (matrix_float4x4){{
        {xAxis.x, yAxis.x, zAxis.x, 0},
        {xAxis.y, yAxis.y, zAxis.y, 0},
        {xAxis.z, yAxis.z, zAxis.z, 0},
        {-vector_dot(xAxis, eye), -vector_dot(yAxis, eye), -vector_dot(zAxis, eye), 1}
    }};
}

static inline matrix_float4x4 matrix4x4_rotation(float radians, vector_float3 axis) {
    vector_float3 unitAxis = vector_normalize(axis);
    float ct = cosf(radians);
    float st = sinf(radians);
    float ci = 1.0f - ct;
    float x = unitAxis.x, y = unitAxis.y, z = unitAxis.z;
    
    return (matrix_float4x4){{
        {ct + x * x * ci,     y * x * ci + z * st, z * x * ci - y * st, 0},
        {x * y * ci - z * st, ct + y * y * ci,     z * y * ci + x * st, 0},
        {x * z * ci + y * st, y * z * ci - x * st, ct + z * z * ci,     0},
        {0,                   0,                   0,                   1}
    }};
}

static inline matrix_float4x4 matrix4x4_scale(float scale) {
    return (matrix_float4x4){{
        {scale, 0,     0,     0},
        {0,     scale, 0,     0},
        {0,     0,     scale, 0},
        {0,     0,     0,     1}
    }};
}

static inline matrix_float4x4 matrix4x4_translation(vector_float3 translation) {
    return (matrix_float4x4){{
        {1, 0, 0, 0},
        {0, 1, 0, 0},
        {0, 0, 1, 0},
        {translation.x, translation.y, translation.z, 1}
    }};
}

#endif
