//
//  SKRenderer.h
//  SKRender
//
//  Created by Dimitri ALMON on 16/06/2025.
//

#ifndef SKRenderer_h
#define SKRenderer_h

#import <Foundation/Foundation.h>
#import <MetalKit/MetalKit.h>

@interface SKRenderer : NSObject <MTKViewDelegate>

@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;

- (instancetype)initWithView:(MTKView *)view;
- (void)updateStormParameters:(void *)parameters;
- (void)triggerManualLightning;

@end

#endif
