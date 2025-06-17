//
//  Shaders.metal
//  SKRender
//
//  Created by Dimitri ALMON on 17/06/2025.
//

#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float2 texCoord [[attribute(2)]];
};

struct VertexOut {
    float4 position [[position]];
    float3 normal;
    float2 texCoord;
    float3 worldPos;
    float3 viewPos;
};

struct BackgroundVertexIn {
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct BackgroundVertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct Uniforms {
    float4x4 modelViewProjectionMatrix;
    float4x4 normalMatrix;
    float time;
    float padding[3];
};

vertex VertexOut vertex_main(VertexIn in [[stage_in]],
                            constant Uniforms& uniforms [[buffer(1)]]) {
    VertexOut out;
    
    out.position = uniforms.modelViewProjectionMatrix * float4(in.position, 1.0);
    out.worldPos = in.position;
    out.normal = normalize((uniforms.normalMatrix * float4(in.normal, 0.0)).xyz);
    out.texCoord = in.texCoord;
    out.viewPos = (uniforms.normalMatrix * float4(in.position, 1.0)).xyz;
    
    return out;
}

vertex BackgroundVertexOut vertex_background(BackgroundVertexIn in [[stage_in]],
                                           constant Uniforms& uniforms [[buffer(1)]]) {
    BackgroundVertexOut out;
    out.position = float4(in.position, 0.0, 1.0);
    out.texCoord = in.texCoord;
    return out;
}

float noise(float2 uv) {
    return fract(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
}

float smoothNoise(float2 uv) {
    float2 i = floor(uv);
    float2 f = fract(uv);
    
    float a = noise(i);
    float b = noise(i + float2(1.0, 0.0));
    float c = noise(i + float2(0.0, 1.0));
    float d = noise(i + float2(1.0, 1.0));
    
    float2 u = f * f * (3.0 - 2.0 * f);
    
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(float2 uv) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    
    for (int i = 0; i < 6; i++) {
        value += amplitude * smoothNoise(uv * frequency);
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    
    return value;
}

fragment float4 fragment_background(BackgroundVertexOut in [[stage_in]],
                                   constant Uniforms& uniforms [[buffer(1)]]) {
    float2 uv = in.texCoord;
    float2 center = float2(0.5, 0.5);
    float dist = distance(uv, center);
    
    float3 color1 = float3(0.05, 0.08, 0.25);
    float3 color2 = float3(0.15, 0.25, 0.45);
    float3 color3 = float3(0.25, 0.35, 0.65);
    float3 color4 = float3(0.1, 0.2, 0.5);
    
    float t1 = sin(uniforms.time * 0.5 + dist * 3.0) * 0.5 + 0.5;
    float t2 = cos(uniforms.time * 0.3 + uv.x * 4.0) * 0.5 + 0.5;
    float t3 = sin(uniforms.time * 0.7 + uv.y * 5.0) * 0.5 + 0.5;
    
    float3 gradient = mix(color1, color2, t1);
    gradient = mix(gradient, color3, t2 * 0.3);
    gradient = mix(gradient, color4, t3 * 0.2);
    
    float2 noiseUV1 = uv * 3.0 + uniforms.time * 0.1;
    float2 noiseUV2 = uv * 5.0 - uniforms.time * 0.08;
    float2 noiseUV3 = uv * 8.0 + uniforms.time * 0.12;
    
    float noise1 = fbm(noiseUV1) * 0.3;
    float noise2 = fbm(noiseUV2) * 0.2;
    float noise3 = fbm(noiseUV3) * 0.15;
    
    gradient += noise1 + noise2 + noise3;
    
    float orb1 = 0.02 / distance(uv, float2(0.3 + sin(uniforms.time) * 0.2, 0.7 + cos(uniforms.time * 0.7) * 0.15));
    float orb2 = 0.015 / distance(uv, float2(0.8 + cos(uniforms.time * 0.8) * 0.25, 0.3 + sin(uniforms.time * 0.6) * 0.2));
    float orb3 = 0.025 / distance(uv, float2(0.6 + sin(uniforms.time * 0.5) * 0.3, 0.5 + cos(uniforms.time * 0.9) * 0.25));
    
    gradient += orb1 * float3(0.4, 0.7, 1.0) * 0.3;
    gradient += orb2 * float3(0.7, 0.4, 1.0) * 0.25;
    gradient += orb3 * float3(0.5, 0.8, 1.0) * 0.35;
    
    float vignette = 1.0 - dist * 1.2;
    vignette = clamp(vignette, 0.0, 1.0);
    gradient *= vignette;
    
    return float4(gradient, 1.0);
}

fragment float4 fragment_glassmorphism(VertexOut in [[stage_in]],
                                      constant Uniforms& uniforms [[buffer(1)]]) {
    
    float3 lightDir1 = normalize(float3(1.0, 1.0, 1.0));
    float3 lightDir2 = normalize(float3(-0.5, 0.8, 0.5));
    float3 lightDir3 = normalize(float3(0.0, -1.0, 0.2));
    
    float3 normal = normalize(in.normal);
    float3 viewDir = normalize(-in.viewPos);
    
    float3 reflectDir1 = reflect(-lightDir1, normal);
    float3 reflectDir2 = reflect(-lightDir2, normal);
    
    float diffuse1 = max(dot(normal, lightDir1), 0.0) * 0.6;
    float diffuse2 = max(dot(normal, lightDir2), 0.0) * 0.4;
    float diffuse3 = max(dot(normal, lightDir3), 0.0) * 0.3;
    
    float specular1 = pow(max(dot(viewDir, reflectDir1), 0.0), 80.0);
    float specular2 = pow(max(dot(viewDir, reflectDir2), 0.0), 60.0);
    
    float2 noiseUV1 = in.texCoord * 8.0 + uniforms.time * 0.2;
    float2 noiseUV2 = in.texCoord * 12.0 - uniforms.time * 0.15;
    float2 noiseUV3 = in.texCoord * 6.0 + uniforms.time * 0.25;
    
    float noise1 = fbm(noiseUV1) * 0.4;
    float noise2 = smoothNoise(noiseUV2) * 0.3;
    float noise3 = fbm(noiseUV3) * 0.2;
    
    float combinedNoise = (noise1 + noise2 + noise3) / 3.0;
    
    float fresnel = pow(1.0 - max(dot(viewDir, normal), 0.0), 2.5);
    float fresnelInverse = 1.0 - fresnel;
    
    float distortionX = sin(in.texCoord.x * 15.0 + uniforms.time * 2.0) * 0.1;
    float distortionY = cos(in.texCoord.y * 12.0 + uniforms.time * 1.8) * 0.08;
    float distortionZ = sin((in.texCoord.x + in.texCoord.y) * 10.0 + uniforms.time * 1.5) * 0.06;
    
    float totalDistortion = distortionX + distortionY + distortionZ;
    
    float3 baseColor = float3(0.88, 0.94, 1.0);
    float3 rimColor = float3(0.3, 0.65, 1.0);
    float3 coreColor = float3(0.95, 0.98, 1.0);
    float3 highlightColor = float3(1.0, 1.0, 1.0);
    
    float3 primaryColor = mix(baseColor, rimColor, fresnel * 0.8);
    primaryColor = mix(primaryColor, coreColor, fresnelInverse * 0.4);
    primaryColor = mix(primaryColor, highlightColor, specular1 * 0.6);
    
    float totalDiffuse = diffuse1 + diffuse2 + diffuse3;
    primaryColor *= (0.3 + totalDiffuse * 0.7);
    
    primaryColor += specular1 * highlightColor * 0.8;
    primaryColor += specular2 * float3(0.8, 0.9, 1.0) * 0.4;
    
    primaryColor += combinedNoise * 0.18;
    primaryColor *= (1.0 + totalDistortion * 0.25);
    
    float edgeGlow = pow(fresnel, 1.5) * 0.4;
    primaryColor += edgeGlow * float3(0.6, 0.8, 1.0);
    
    float timeGlow = sin(uniforms.time * 2.0) * 0.1 + 0.9;
    primaryColor *= timeGlow;
    
    float alpha = 0.08 + fresnel * 0.45 + combinedNoise * 0.12;
    alpha += specular1 * 0.2;
    alpha += edgeGlow * 0.15;
    alpha = clamp(alpha, 0.06, 0.75);
    
    float3 finalColor = primaryColor * 1.6;
    finalColor = pow(finalColor, float3(0.9));
    
    finalColor = clamp(finalColor, 0.0, 2.0);
    
    return float4(finalColor, alpha);
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms& uniforms [[buffer(1)]]) {
    
    float pulse = sin(uniforms.time * 2.0) * 0.5 + 0.5;
    
    return float4(1.0, pulse, 0.0, 1.0);
}

vertex VertexOut vertex_fullscreen(VertexIn in [[stage_in]],
                                  constant Uniforms& uniforms [[buffer(1)]]) {
    VertexOut out;
    out.position = float4(in.position.xy, 0.0, 1.0);
    out.worldPos = in.position;
    out.normal = in.normal;
    out.texCoord = in.texCoord;
    return out;
}

fragment float4 fragment_test(VertexOut in [[stage_in]],
                             constant Uniforms& uniforms [[buffer(1)]]) {
    
    float pulse = sin(uniforms.time * 2.0) * 0.5 + 0.5;
    
    float3 color = float3(1.0, pulse, 0.0);
    
    return float4(color, 1.0);
}
