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

struct LightningVertexIn {
    float3 position [[attribute(0)]];
    float intensity [[attribute(1)]];
    float branchFactor [[attribute(2)]];
    float timeOffset [[attribute(3)]];
};

struct LightningVertexOut {
    float4 position [[position]];
    float intensity;
    float branchFactor;
    float timeOffset;
    float3 worldPos;
};

struct ControlledStormUniforms {
    float4x4 modelViewProjectionMatrix;
    float4x4 normalMatrix;
    float time;
    float lightningIntensity;
    float lightningFrequency;
    float rainIntensity;
    float windSpeed;
    float stormIntensity;
    float3 lightningColor;
    float3 skyTint;
    float flashDuration;
    float branchFactor;
    float electricGlow;
    float manualLightningTrigger;
};

vertex VertexOut vertex_main(VertexIn in [[stage_in]],
                            constant ControlledStormUniforms& uniforms [[buffer(1)]]) {
    VertexOut out;
    
    out.position = uniforms.modelViewProjectionMatrix * float4(in.position, 1.0);
    out.worldPos = in.position;
    out.normal = normalize((uniforms.normalMatrix * float4(in.normal, 0.0)).xyz);
    out.texCoord = in.texCoord;
    out.viewPos = (uniforms.normalMatrix * float4(in.position, 1.0)).xyz;
    
    return out;
}

vertex BackgroundVertexOut vertex_background(BackgroundVertexIn in [[stage_in]],
                                           constant ControlledStormUniforms& uniforms [[buffer(1)]]) {
    BackgroundVertexOut out;
    out.position = float4(in.position, 0.0, 1.0);
    out.texCoord = in.texCoord;
    return out;
}

vertex LightningVertexOut vertex_lightning(LightningVertexIn in [[stage_in]],
                                          constant ControlledStormUniforms& uniforms [[buffer(1)]]) {
    LightningVertexOut out;
    
    float3 animatedPos = in.position;
    float windEffect = sin(uniforms.time * uniforms.windSpeed * 2.0 + in.position.x * 0.1) * uniforms.windSpeed * 0.5;
    animatedPos.x += windEffect;
    
    out.position = uniforms.modelViewProjectionMatrix * float4(animatedPos, 1.0);
    out.intensity = in.intensity * uniforms.lightningIntensity;
    out.branchFactor = in.branchFactor * uniforms.branchFactor;
    out.timeOffset = in.timeOffset;
    out.worldPos = animatedPos;
    
    return out;
}

vertex VertexOut vertex_rain(VertexIn in [[stage_in]],
                            constant ControlledStormUniforms& uniforms [[buffer(1)]]) {
    VertexOut out;
    
    float3 animatedPos = in.position;
    float rainSpeed = 8.0 + uniforms.rainIntensity * 12.0;
    float windDrift = sin(uniforms.time * uniforms.windSpeed + in.position.x * 0.2) * uniforms.windSpeed * 2.0;
    
    animatedPos.y -= fmod(uniforms.time * rainSpeed + in.texCoord.x * 20.0, 40.0);
    animatedPos.x += windDrift;
    
    out.position = uniforms.modelViewProjectionMatrix * float4(animatedPos, 1.0);
    out.worldPos = animatedPos;
    out.normal = in.normal;
    out.texCoord = in.texCoord;
    out.viewPos = (uniforms.normalMatrix * float4(animatedPos, 1.0)).xyz;
    
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

fragment float4 fragment_storm_background(BackgroundVertexOut in [[stage_in]],
                                         constant ControlledStormUniforms& uniforms [[buffer(1)]]) {
    float2 uv = in.texCoord;
    float2 center = float2(0.5, 0.5);
    
    float3 darkSky = uniforms.skyTint * 0.8;
    float3 stormClouds = uniforms.skyTint * 2.0;
    float3 lightningGlow = uniforms.lightningColor * uniforms.electricGlow;
    
    float cloudSpeed = uniforms.windSpeed * 0.1;
    float2 cloudUV1 = uv * (2.0 + uniforms.stormIntensity) + uniforms.time * cloudSpeed;
    float2 cloudUV2 = uv * (4.0 + uniforms.stormIntensity * 2.0) - uniforms.time * cloudSpeed * 0.7;
    float2 cloudUV3 = uv * (6.0 + uniforms.stormIntensity * 3.0) + uniforms.time * cloudSpeed * 1.3;
    
    float clouds1 = fbm(cloudUV1) * 0.6;
    float clouds2 = fbm(cloudUV2) * 0.4;
    float clouds3 = smoothNoise(cloudUV3) * 0.3;
    
    float totalClouds = (clouds1 + clouds2 + clouds3) / 3.0;
    totalClouds = pow(totalClouds, 1.2 + uniforms.stormIntensity * 0.5);
    
    float3 skyColor = mix(darkSky, stormClouds, totalClouds * uniforms.stormIntensity);
    
    float lightningFlash = uniforms.lightningIntensity + uniforms.manualLightningTrigger;
    float flashDistance = distance(uv, float2(0.3 + sin(uniforms.time) * 0.2, 0.7));
    float lightningEffect = lightningFlash * (1.0 / (1.0 + flashDistance * 6.0));
    
    skyColor += lightningGlow * lightningEffect * uniforms.electricGlow;
    
    float2 electricUV = uv * 15.0 + uniforms.time * uniforms.lightningFrequency * 3.0;
    float electricNoise = smoothNoise(electricUV) * lightningFlash * uniforms.electricGlow * 0.15;
    skyColor += electricNoise * lightningGlow;
    
    skyColor *= uniforms.stormIntensity * 0.8 + 0.2;
    
    float vignette = 1.0 - distance(uv, center) * 0.6;
    vignette = clamp(vignette, 0.0, 1.0);
    skyColor *= vignette;
    
    return float4(skyColor, 1.0);
}

fragment float4 fragment_lightning(LightningVertexOut in [[stage_in]],
                                  constant ControlledStormUniforms& uniforms [[buffer(1)]]) {
    
    float timePhase = uniforms.time * uniforms.lightningFrequency + in.timeOffset;
    float visibility = sin(timePhase * 15.0) * 0.5 + 0.5;
    visibility *= uniforms.lightningIntensity;
    
    if (uniforms.manualLightningTrigger > 0.0) {
        visibility = max(visibility, uniforms.manualLightningTrigger);
    }
    
    float electricPulse = sin(timePhase * 25.0 + uniforms.electricGlow * 10.0) * 0.3 + 0.7;
    electricPulse *= uniforms.electricGlow;
    
    float3 coreColor = float3(1.0, 1.0, 1.0);
    float3 userColor = uniforms.lightningColor;
    
    float branchIntensity = 1.0 - in.branchFactor;
    float3 lightningColor = mix(userColor, coreColor, branchIntensity * 0.8);
    lightningColor = mix(lightningColor, userColor * 0.8, in.branchFactor * 0.4);
    
    lightningColor *= in.intensity * electricPulse * visibility;
    
    float fresnel = pow(1.0 - abs(sin(timePhase * 18.0)), 2.0);
    lightningColor += fresnel * userColor * uniforms.electricGlow * 0.6;
    
    float glowIntensity = in.intensity * visibility * uniforms.electricGlow * 2.5;
    lightningColor *= glowIntensity;
    
    float alpha = in.intensity * visibility * uniforms.electricGlow * (0.4 + electricPulse * 0.6);
    alpha = clamp(alpha, 0.0, 1.0);
    
    return float4(lightningColor, alpha);
}

fragment float4 fragment_rain(VertexOut in [[stage_in]],
                             constant ControlledStormUniforms& uniforms [[buffer(1)]]) {
    
    float3 viewDir = normalize(-in.viewPos);
    float3 normal = normalize(in.normal);
    
    float fresnel = pow(1.0 - max(dot(viewDir, normal), 0.0), 1.2);
    
    float dropletSpeed = 5.0 + uniforms.rainIntensity * 8.0;
    float dropletNoise = smoothNoise(in.texCoord * 80.0 + uniforms.time * dropletSpeed);
    
    float3 rainColor = float3(0.6, 0.8, 1.0);
    float3 baseColor = rainColor * (0.3 + fresnel * 0.7) * uniforms.rainIntensity;
    
    float lightningReflection = (uniforms.lightningIntensity + uniforms.manualLightningTrigger) * fresnel * uniforms.electricGlow;
    baseColor += lightningReflection * uniforms.lightningColor * 0.8;
    
    baseColor *= (0.7 + dropletNoise * 0.5);
    
    float alpha = (0.1 + fresnel * 0.2) * uniforms.rainIntensity;
    alpha += lightningReflection * 0.4;
    alpha *= (0.6 + dropletNoise * 0.4);
    alpha = clamp(alpha, 0.0, 0.8);
    
    return float4(baseColor, alpha);
}

fragment float4 fragment_glassmorphism(VertexOut in [[stage_in]],
                                      constant ControlledStormUniforms& uniforms [[buffer(1)]]) {
    
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
    
    float animSpeed = uniforms.windSpeed * 0.3;
    float2 noiseUV1 = in.texCoord * (6.0 + uniforms.stormIntensity * 4.0) + uniforms.time * animSpeed;
    float2 noiseUV2 = in.texCoord * (10.0 + uniforms.stormIntensity * 6.0) - uniforms.time * animSpeed * 0.8;
    float2 noiseUV3 = in.texCoord * (4.0 + uniforms.stormIntensity * 2.0) + uniforms.time * animSpeed * 1.2;
    
    float noise1 = fbm(noiseUV1) * 0.4;
    float noise2 = smoothNoise(noiseUV2) * 0.3;
    float noise3 = fbm(noiseUV3) * 0.2;
    
    float combinedNoise = (noise1 + noise2 + noise3) / 3.0;
    
    float fresnel = pow(1.0 - max(dot(viewDir, normal), 0.0), 2.0 + uniforms.stormIntensity);
    float fresnelInverse = 1.0 - fresnel;
    
    float distortionStrength = uniforms.windSpeed * 0.2 + uniforms.stormIntensity * 0.1;
    float distortionX = sin(in.texCoord.x * 12.0 + uniforms.time * 2.0) * distortionStrength;
    float distortionY = cos(in.texCoord.y * 10.0 + uniforms.time * 1.5) * distortionStrength;
    float distortionZ = sin((in.texCoord.x + in.texCoord.y) * 8.0 + uniforms.time * 1.2) * distortionStrength;
    
    float totalDistortion = distortionX + distortionY + distortionZ;
    
    float3 baseColor = float3(0.85, 0.92, 0.98);
    float3 rimColor = uniforms.skyTint * 3.0 + float3(0.2, 0.4, 0.8);
    float3 coreColor = float3(0.92, 0.96, 1.0);
    float3 highlightColor = uniforms.lightningColor;
    
    float3 primaryColor = mix(baseColor, rimColor, fresnel * 0.7);
    primaryColor = mix(primaryColor, coreColor, fresnelInverse * 0.5);
    primaryColor = mix(primaryColor, highlightColor, specular1 * 0.4);
    
    float totalDiffuse = diffuse1 + diffuse2 + diffuse3;
    primaryColor *= (0.2 + totalDiffuse * 0.8);
    
    primaryColor += specular1 * highlightColor * uniforms.electricGlow * 0.6;
    primaryColor += specular2 * uniforms.lightningColor * 0.3;
    
    primaryColor += combinedNoise * 0.2;
    primaryColor *= (1.0 + totalDistortion * 0.3);
    
    float edgeGlow = pow(fresnel, 1.2) * uniforms.electricGlow * 0.5;
    primaryColor += edgeGlow * uniforms.lightningColor;
    
    float lightningInfluence = (uniforms.lightningIntensity + uniforms.manualLightningTrigger) * 0.3;
    primaryColor += lightningInfluence * uniforms.lightningColor * fresnel;
    
    float timeGlow = sin(uniforms.time * 1.5) * 0.1 + 0.9;
    primaryColor *= timeGlow;
    
    float alpha = 0.06 + fresnel * (0.4 + uniforms.electricGlow * 0.2) + combinedNoise * 0.15;
    alpha += specular1 * 0.25;
    alpha += edgeGlow * 0.2;
    alpha += lightningInfluence * 0.3;
    alpha = clamp(alpha, 0.04, 0.85);
    
    float3 finalColor = primaryColor * (1.4 + uniforms.electricGlow * 0.4);
    finalColor = pow(finalColor, float3(0.85));
    
    finalColor = clamp(finalColor, 0.0, 2.5);
    
    return float4(finalColor, alpha);
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant ControlledStormUniforms& uniforms [[buffer(1)]]) {
    
    float pulse = sin(uniforms.time * 2.0) * 0.5 + 0.5;
    
    return float4(1.0, pulse, 0.0, 1.0);
}

fragment float4 fragment_background(BackgroundVertexOut in [[stage_in]],
                                   constant ControlledStormUniforms& uniforms [[buffer(1)]]) {
    float2 uv = in.texCoord;
    float2 center = float2(0.5, 0.5);
    float dist = distance(uv, center);
    
    float3 color1 = uniforms.skyTint * 2.0;
    float3 color2 = uniforms.skyTint * 4.0;
    float3 color3 = uniforms.skyTint * 6.0;
    float3 color4 = uniforms.skyTint * 3.0;
    
    float animSpeed = uniforms.windSpeed * 0.5;
    float t1 = sin(uniforms.time * animSpeed + dist * 3.0) * 0.5 + 0.5;
    float t2 = cos(uniforms.time * animSpeed * 0.6 + uv.x * 4.0) * 0.5 + 0.5;
    float t3 = sin(uniforms.time * animSpeed * 1.4 + uv.y * 5.0) * 0.5 + 0.5;
    
    float3 gradient = mix(color1, color2, t1);
    gradient = mix(gradient, color3, t2 * 0.3);
    gradient = mix(gradient, color4, t3 * 0.2);
    
    float noiseScale = 2.0 + uniforms.stormIntensity * 4.0;
    float2 noiseUV1 = uv * noiseScale + uniforms.time * animSpeed;
    float2 noiseUV2 = uv * (noiseScale * 1.5) - uniforms.time * animSpeed * 0.8;
    float2 noiseUV3 = uv * (noiseScale * 2.0) + uniforms.time * animSpeed * 1.2;
    
    float noise1 = fbm(noiseUV1) * 0.3;
    float noise2 = fbm(noiseUV2) * 0.2;
    float noise3 = fbm(noiseUV3) * 0.15;
    
    gradient += (noise1 + noise2 + noise3) * uniforms.stormIntensity;
    
    float orbSpeed = uniforms.windSpeed * 0.7;
    float orb1 = 0.02 / distance(uv, float2(0.3 + sin(uniforms.time * orbSpeed) * 0.2, 0.7 + cos(uniforms.time * orbSpeed * 0.7) * 0.15));
    float orb2 = 0.015 / distance(uv, float2(0.8 + cos(uniforms.time * orbSpeed * 0.8) * 0.25, 0.3 + sin(uniforms.time * orbSpeed * 0.6) * 0.2));
    float orb3 = 0.025 / distance(uv, float2(0.6 + sin(uniforms.time * orbSpeed * 0.5) * 0.3, 0.5 + cos(uniforms.time * orbSpeed * 0.9) * 0.25));
    
    gradient += orb1 * uniforms.lightningColor * uniforms.electricGlow * 0.4;
    gradient += orb2 * (uniforms.lightningColor * 0.7 + float3(0.3, 0.0, 0.7)) * uniforms.electricGlow * 0.3;
    gradient += orb3 * (uniforms.lightningColor * 0.8 + float3(0.0, 0.3, 0.5)) * uniforms.electricGlow * 0.45;
    
    float vignette = 1.0 - dist * (1.0 + uniforms.stormIntensity * 0.5);
    vignette = clamp(vignette, 0.0, 1.0);
    gradient *= vignette;
    
    return float4(gradient, 1.0);
}
