//
//  SKEngine.h
//  SKRender
//
//  Created by Dimitri ALMON on 16/06/2025.
//

#ifndef SKEngine_h
#define SKEngine_h

#import <Foundation/Foundation.h>
#import <MetalKit/MetalKit.h>
#import <CoreData/CoreData.h>
#import "SKMath.h"

@class SKRenderer;
@class SKScene;

@interface SKEngine : NSObject

@property (nonatomic, strong) SKRenderer *renderer;
@property (nonatomic, strong) SKScene *currentScene;
@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;

+ (instancetype)sharedEngine;
- (void)initializeWithView:(MTKView *)view context:(NSManagedObjectContext *)context;
- (void)update:(CFTimeInterval)deltaTime;

@end

#endif
