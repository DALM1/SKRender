//
//  SKStormController.h
//  SKRender
//
//  Created by Dimitri ALMON on 17/06/2025.
//

#ifndef SKStormController_h
#define SKStormController_h

#import <Foundation/Foundation.h>
#import <simd/simd.h>

@class SKStormController;

@protocol SKStormControllerDelegate <NSObject>
- (void)stormController:(SKStormController *)controller didUpdateParameters:(void *)params;
- (void)stormControllerDidTriggerLightning:(SKStormController *)controller;
@end

typedef struct {
    float lightningIntensity;
    float lightningFrequency;
    float rainIntensity;
    float windSpeed;
    float stormIntensity;
    vector_float3 lightningColor;
    vector_float3 skyTint;
    float flashDuration;
    float branchFactor;
    float electricGlow;
} StormParameters;

@interface SKStormController : NSObject

@property (nonatomic, weak) id<SKStormControllerDelegate> delegate;
@property (nonatomic, readonly) StormParameters currentParameters;

+ (instancetype)sharedController;

- (void)setLightningIntensity:(float)intensity;
- (void)setLightningFrequency:(float)frequency;
- (void)setRainIntensity:(float)intensity;
- (void)setWindSpeed:(float)speed;
- (void)setStormIntensity:(float)intensity;
- (void)setLightningColor:(vector_float3)color;
- (void)setSkyTint:(vector_float3)tint;
- (void)setFlashDuration:(float)duration;
- (void)setBranchFactor:(float)factor;
- (void)setElectricGlow:(float)glow;

- (void)triggerManualLightning;
- (void)resetToDefaults;

- (void)loadPreset:(NSString *)presetName;
- (void)savePreset:(NSString *)presetName;

@end

#endif
