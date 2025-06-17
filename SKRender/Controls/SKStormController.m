//
//  SKStormController.m
//  SKRender
//
//  Created by Dimitri ALMON on 17/06/2025.
//

#import "SKStormController.h"

@interface SKStormController ()
@property (nonatomic, assign) StormParameters parameters;
@property (nonatomic, strong) NSMutableDictionary *presets;
@end

@implementation SKStormController

+ (instancetype)sharedController {
    static SKStormController *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        [self resetToDefaults];
        [self loadPresets];
    }
    return self;
}

- (void)resetToDefaults {
    _parameters = (StormParameters){
        .lightningIntensity = 0.8f,
        .lightningFrequency = 0.6f,
        .rainIntensity = 0.7f,
        .windSpeed = 0.5f,
        .stormIntensity = 0.8f,
        .lightningColor = {0.9f, 0.95f, 1.0f},
        .skyTint = {0.05f, 0.08f, 0.2f},
        .flashDuration = 0.15f,
        .branchFactor = 0.4f,
        .electricGlow = 0.9f
    };
    [self notifyDelegate];
}

- (void)loadPresets {
    self.presets = [[NSMutableDictionary alloc] init];
    
    NSDictionary *gentleStormDict = @{
        @"lightningIntensity": @(0.3f),
        @"lightningFrequency": @(0.2f),
        @"rainIntensity": @(0.4f),
        @"windSpeed": @(0.2f),
        @"stormIntensity": @(0.3f),
        @"lightningColorR": @(0.8f),
        @"lightningColorG": @(0.9f),
        @"lightningColorB": @(1.0f),
        @"skyTintR": @(0.1f),
        @"skyTintG": @(0.15f),
        @"skyTintB": @(0.3f),
        @"flashDuration": @(0.3f),
        @"branchFactor": @(0.2f),
        @"electricGlow": @(0.5f)
    };
    
    NSDictionary *violentStormDict = @{
        @"lightningIntensity": @(1.0f),
        @"lightningFrequency": @(1.0f),
        @"rainIntensity": @(1.0f),
        @"windSpeed": @(1.0f),
        @"stormIntensity": @(1.0f),
        @"lightningColorR": @(1.0f),
        @"lightningColorG": @(1.0f),
        @"lightningColorB": @(1.0f),
        @"skyTintR": @(0.02f),
        @"skyTintG": @(0.02f),
        @"skyTintB": @(0.1f),
        @"flashDuration": @(0.05f),
        @"branchFactor": @(0.8f),
        @"electricGlow": @(1.5f)
    };
    
    NSDictionary *purpleStormDict = @{
        @"lightningIntensity": @(0.9f),
        @"lightningFrequency": @(0.7f),
        @"rainIntensity": @(0.6f),
        @"windSpeed": @(0.4f),
        @"stormIntensity": @(0.8f),
        @"lightningColorR": @(0.8f),
        @"lightningColorG": @(0.4f),
        @"lightningColorB": @(1.0f),
        @"skyTintR": @(0.1f),
        @"skyTintG": @(0.05f),
        @"skyTintB": @(0.2f),
        @"flashDuration": @(0.2f),
        @"branchFactor": @(0.6f),
        @"electricGlow": @(1.2f)
    };
    
    [self.presets setObject:gentleStormDict forKey:@"Gentle"];
    [self.presets setObject:violentStormDict forKey:@"Violent"];
    [self.presets setObject:purpleStormDict forKey:@"Purple"];
}

- (StormParameters)currentParameters {
    return _parameters;
}

- (void)setLightningIntensity:(float)intensity {
    _parameters.lightningIntensity = fmaxf(0.0f, fminf(2.0f, intensity));
    [self notifyDelegate];
}

- (void)setLightningFrequency:(float)frequency {
    _parameters.lightningFrequency = fmaxf(0.0f, fminf(2.0f, frequency));
    [self notifyDelegate];
}

- (void)setRainIntensity:(float)intensity {
    _parameters.rainIntensity = fmaxf(0.0f, fminf(2.0f, intensity));
    [self notifyDelegate];
}

- (void)setWindSpeed:(float)speed {
    _parameters.windSpeed = fmaxf(0.0f, fminf(2.0f, speed));
    [self notifyDelegate];
}

- (void)setStormIntensity:(float)intensity {
    _parameters.stormIntensity = fmaxf(0.0f, fminf(2.0f, intensity));
    [self notifyDelegate];
}

- (void)setLightningColor:(vector_float3)color {
    _parameters.lightningColor = color;
    [self notifyDelegate];
}

- (void)setSkyTint:(vector_float3)tint {
    _parameters.skyTint = tint;
    [self notifyDelegate];
}

- (void)setFlashDuration:(float)duration {
    _parameters.flashDuration = fmaxf(0.01f, fminf(1.0f, duration));
    [self notifyDelegate];
}

- (void)setBranchFactor:(float)factor {
    _parameters.branchFactor = fmaxf(0.0f, fminf(1.0f, factor));
    [self notifyDelegate];
}

- (void)setElectricGlow:(float)glow {
    _parameters.electricGlow = fmaxf(0.0f, fminf(3.0f, glow));
    [self notifyDelegate];
}

- (void)triggerManualLightning {
    if ([self.delegate respondsToSelector:@selector(stormControllerDidTriggerLightning:)]) {
        [self.delegate stormControllerDidTriggerLightning:self];
    }
}

- (void)loadPreset:(NSString *)presetName {
    NSDictionary *presetDict = [self.presets objectForKey:presetName];
    if (presetDict) {
        _parameters.lightningIntensity = [presetDict[@"lightningIntensity"] floatValue];
        _parameters.lightningFrequency = [presetDict[@"lightningFrequency"] floatValue];
        _parameters.rainIntensity = [presetDict[@"rainIntensity"] floatValue];
        _parameters.windSpeed = [presetDict[@"windSpeed"] floatValue];
        _parameters.stormIntensity = [presetDict[@"stormIntensity"] floatValue];
        _parameters.lightningColor = (vector_float3){
            [presetDict[@"lightningColorR"] floatValue],
            [presetDict[@"lightningColorG"] floatValue],
            [presetDict[@"lightningColorB"] floatValue]
        };
        _parameters.skyTint = (vector_float3){
            [presetDict[@"skyTintR"] floatValue],
            [presetDict[@"skyTintG"] floatValue],
            [presetDict[@"skyTintB"] floatValue]
        };
        _parameters.flashDuration = [presetDict[@"flashDuration"] floatValue];
        _parameters.branchFactor = [presetDict[@"branchFactor"] floatValue];
        _parameters.electricGlow = [presetDict[@"electricGlow"] floatValue];
        [self notifyDelegate];
    }
}

- (void)savePreset:(NSString *)presetName {
    NSDictionary *presetDict = @{
        @"lightningIntensity": @(_parameters.lightningIntensity),
        @"lightningFrequency": @(_parameters.lightningFrequency),
        @"rainIntensity": @(_parameters.rainIntensity),
        @"windSpeed": @(_parameters.windSpeed),
        @"stormIntensity": @(_parameters.stormIntensity),
        @"lightningColorR": @(_parameters.lightningColor.x),
        @"lightningColorG": @(_parameters.lightningColor.y),
        @"lightningColorB": @(_parameters.lightningColor.z),
        @"skyTintR": @(_parameters.skyTint.x),
        @"skyTintG": @(_parameters.skyTint.y),
        @"skyTintB": @(_parameters.skyTint.z),
        @"flashDuration": @(_parameters.flashDuration),
        @"branchFactor": @(_parameters.branchFactor),
        @"electricGlow": @(_parameters.electricGlow)
    };
    [self.presets setObject:presetDict forKey:presetName];
}

- (void)notifyDelegate {
    if ([self.delegate respondsToSelector:@selector(stormController:didUpdateParameters:)]) {
        [self.delegate stormController:self didUpdateParameters:&_parameters];
    }
}

@end
