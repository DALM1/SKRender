#import "SKEngine.h"
#import "../Rendering/SKRenderer.h"
#import "../Scene/SKScene.h"

@implementation SKEngine

+ (instancetype)sharedEngine {
    static SKEngine *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (void)initializeWithView:(MTKView *)view context:(NSManagedObjectContext *)context {
    self.device = view.device;
    self.context = context;
    self.renderer = [[SKRenderer alloc] initWithView:view];
    self.currentScene = [[SKScene alloc] init];
    
    NSLog(@"SKEngine initialized successfully");
}

- (void)update:(CFTimeInterval)deltaTime {
    [self.currentScene update:deltaTime];
}

- (void)render {
    [self.renderer renderScene:self.currentScene];
}

@end
