#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <CoreData/CoreData.h>

@class SKRenderer, SKScene;

@interface SKEngine : NSObject

@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) SKRenderer *renderer;
@property (nonatomic, strong) SKScene *currentScene;
@property (nonatomic, strong) NSManagedObjectContext *context;

+ (instancetype)sharedEngine;
- (void)initializeWithView:(MTKView *)view context:(NSManagedObjectContext *)context;
- (void)update:(CFTimeInterval)deltaTime;
- (void)render;

@end
