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

struct StormUniforms {
    float4x4 modelViewProjectionMatrix;
    float4x4 normalMatrix;
    float time;
    float lightningIntensity;
    float stormPhase;
    float flashTiming;
};

vertex VertexOut vertex_main(VertexIn in [[stage_in]],
                            constant StormUniforms& uniforms [[buffer(1)]]) {
    VertexOut out;
    
    out.position = uniforms.modelViewProjectionMatrix * float4(in.position, 1.0);
    out.worldPos = in.position;
    out.normal = normalize((uniforms.normalMatrix * float4(in.normal, 0.0)).xyz);
    out.texCoord = in.texCoord;
    out.viewPos = (uniforms.normalMatrix * float4(in.position, 1.0)).xyz;
    
    return out;
}

vertex BackgroundVertexOut vertex_background(BackgroundVertexIn in [[stage_in]],
                                           constant StormUniforms& uniforms [[buffer(1)]]) {
    BackgroundVertexOut out;
    out.position = float4(in.position, 0.0, 1.0);
    out.texCoord = in.texCoord;
    return out;
}

vertex LightningVertexOut vertex_lightning(LightningVertexIn in [[stage_in]],
                                          constant StormUniforms& uniforms [[buffer(1)]]) {
    LightningVertexOut out;
    
    out.position = uniforms.modelViewProjectionMatrix * float4(in.position, 1.0);
    out.intensity = in.intensity;
    out.branchFactor = in.branchFactor;
    out.timeOffset = in.timeOffset;
    out.worldPos = in.position;
    
    return out;
}

vertex VertexOut vertex_rain(VertexIn in [[stage_in]],
                            constant StormUniforms& uniforms [[buffer(1)]]) {
    VertexOut out;
    
    float3 animatedPos = in.position;
    animatedPos.y -= fmod(uniforms.time * 8.0 + in.texCoord.x * 10.0, 30.0);
    
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
                                         constant StormUniforms& uniforms [[buffer(1)]]) {
    float2 uv = in.texCoord;
    float2 center = float2(0.5, 0.5);
    
    float3 darkSky = float3(0.02, 0.02, 0.08);
    float3 stormClouds = float3(0.08, 0.08, 0.15);
    float3 lightningGlow = float3(0.4, 0.6, 1.0);
    
    float2 cloudUV1 = uv * 3.0 + uniforms.time * 0.05;
    float2 cloudUV2 = uv * 5.0 - uniforms.time * 0.03;
    float2 cloudUV3 = uv * 8.0 + uniforms.time * 0.08;
    
    float clouds1 = fbm(cloudUV1) * 0.6;
    float clouds2 = fbm(cloudUV2) * 0.4;
    float clouds3 = smoothNoise(cloudUV3) * 0.3;
    
    float totalClouds = (clouds1 + clouds2 + clouds3) / 3.0;
    totalClouds = pow(totalClouds, 1.5);
    
    float3 skyColor = mix(darkSky, stormClouds, totalClouds);
    
    float lightningFlash = uniforms.lightningIntensity;
    float flashDistance = distance(uv, float2(0.3 + sin(uniforms.time) * 0.2, 0.7));
    float lightningEffect = lightningFlash * (1.0 / (1.0 + flashDistance * 8.0));
    
    skyColor += lightningGlow * lightningEffect * 0.8;
    
    float2 electricUV = uv * 15.0 + uniforms.time * 2.0;
    float electricNoise = smoothNoise(electricUV) * lightningFlash * 0.1;
    skyColor += electricNoise * lightningGlow;
    
    float stormIntensity = sin(uniforms.time * 0.3) * 0.2 + 0.8;
    skyColor *= stormIntensity;
    
    float vignette = 1.0 - distance(uv, center) * 0.8;
    vignette = clamp(vignette, 0.0, 1.0);
    skyColor *= vignette;
    
    return float4(skyColor, 1.0);
}

fragment float4 fragment_lightning(LightningVertexOut in [[stage_in]],
                                  constant StormUniforms& uniforms [[buffer(1)]]) {
    
    float timePhase = uniforms.time + in.timeOffset;
    float visibility = sin(timePhase * 15.0) * 0.5 + 0.5;
    visibility *= uniforms.lightningIntensity;
    
    float electricPulse = sin(timePhase * 30.0) * 0.3 + 0.7;
    
    float3 coreColor = float3(1.0, 1.0, 1.0);
    float3 electricBlue = float3(0.3, 0.7, 1.0);
    float3 electricPurple = float3(0.6, 0.3, 1.0);
    
    float branchIntensity = 1.0 - in.branchFactor;
    float3 lightningColor = mix(electricBlue, coreColor, branchIntensity);
    lightningColor = mix(lightningColor, electricPurple, in.branchFactor * 0.3);
    
    lightningColor *= in.intensity * electricPulse * visibility;
    
    float fresnel = pow(1.0 - abs(sin(timePhase * 20.0)), 2.0);
    lightningColor += fresnel * float3(0.8, 0.9, 1.0) * 0.4;
    
    float glowIntensity = in.intensity * visibility * 2.0;
    lightningColor *= glowIntensity;
    
    float alpha = in.intensity * visibility * (0.6 + electricPulse * 0.4);
    alpha = clamp(alpha, 0.0, 1.0);
    
    return float4(lightningColor, alpha);
}

fragment float4 fragment_rain(VertexOut in [[stage_in]],
                             constant StormUniforms& uniforms [[buffer(1)]]) {
    
    float3 viewDir = normalize(-in.viewPos);
    float3 normal = normalize(in.normal);
    
    float fresnel = pow(1.0 - max(dot(viewDir, normal), 0.0), 1.5);
    
    float dropletNoise = smoothNoise(in.texCoord * 100.0 + uniforms.time * 5.0);
    
    float3 rainColor = float3(0.6, 0.8, 1.0);
    float3 baseColor = rainColor * (0.4 + fresnel * 0.6);
    
    float lightningReflection = uniforms.lightningIntensity * fresnel * 0.8;
    baseColor += lightningReflection * float3(0.9, 0.95, 1.0);
    
    baseColor *= (0.8 + dropletNoise * 0.4);
    
    float alpha = 0.15 + fresnel * 0.25 + lightningReflection * 0.3;
    alpha *= (0.7 + dropletNoise * 0.3);
    alpha = clamp(alpha, 0.0, 0.6);
    
    return float4(baseColor, alpha);
}

fragment float4 fragment_glassmorphism(VertexOut in [[stage_in]],
                                      constant StormUniforms& uniforms [[buffer(1)]]) {
    
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
                             constant StormUniforms& uniforms [[buffer(1)]]) {
    
    float pulse = sin(uniforms.time * 2.0) * 0.5 + 0.5;
    
    return float4(1.0, pulse, 0.0, 1.0);
}

fragment float4 fragment_background(BackgroundVertexOut in [[stage_in]],
                                   constant StormUniforms& uniforms [[buffer(1)]]) {
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
