//
//  ViewController.m
//  SKRender
//
//  Created by Dimitri ALMON on 16/06/2025.
//

#import "ViewController.h"
#import "Core/SKEngine.h"
#import "Rendering/SKRenderer.h"
#import <QuartzCore/QuartzCore.h>

@interface ViewController ()
@property (nonatomic, strong) SKRenderer *renderer;
@property (nonatomic, strong) MTKView *metalView;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSLog(@"=== Glassmorphism Window Setup ===");
    
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (!device) {
        NSLog(@"⚫️ No Metal device");
        return;
    }
    
    self.metalView = [[MTKView alloc] initWithFrame:self.view.bounds device:device];
    self.metalView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.metalView.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    self.metalView.depthStencilPixelFormat = MTLPixelFormatDepth32Float;
    self.metalView.preferredFramesPerSecond = 60;
    self.metalView.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0);
    
    [self.view addSubview:self.metalView];
    
    [self setupWindowEffects];
    
    self.renderer = [[SKRenderer alloc] initWithView:self.metalView];
    if (!self.renderer) {
        NSLog(@"⚫️ Failed to create renderer");
        return;
    }
    
    self.metalView.delegate = self.renderer;
    
    [[SKEngine sharedEngine] initializeWithView:self.metalView context:nil];
    NSLog(@"⚪️ Full glassmorphism scene ready");
}

- (void)setupWindowEffects {
    NSWindow *window = self.view.window;
    if (!window) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setupWindowEffects];
        });
        return;
    }
    
    window.titlebarAppearsTransparent = YES;
    window.titleVisibility = NSWindowTitleHidden;
    window.styleMask |= NSWindowStyleMaskFullSizeContentView;
    
    window.backgroundColor = [NSColor colorWithRed:0.02 green:0.05 blue:0.12 alpha:0.95];
    
    if (@available(macOS 10.14, *)) {
        window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    }
    
    NSVisualEffectView *effectView = [[NSVisualEffectView alloc] initWithFrame:self.view.bounds];
    effectView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    effectView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    effectView.state = NSVisualEffectStateActive;
    
    if (@available(macOS 10.14, *)) {
        effectView.material = NSVisualEffectMaterialUnderWindowBackground;
    }
    
    [self.view addSubview:effectView positioned:NSWindowBelow relativeTo:self.metalView];
    
    NSLog(@"⚪️ Window glassmorphism effects applied");
}

- (void)viewDidAppear {
    [super viewDidAppear];
    
    NSLog(@"=== Glassmorphism Scene Active ===");
    [self.metalView setNeedsDisplay:YES];
    
    [self setupWindowAnimations];
}

- (void)setupWindowAnimations {
    NSWindow *window = self.view.window;
    if (!window) return;
    
    window.contentView.wantsLayer = YES;
    
    CABasicAnimation *windowGlow = [CABasicAnimation animationWithKeyPath:@"shadowOpacity"];
    windowGlow.fromValue = @(0.0);
    windowGlow.toValue = @(0.8);
    windowGlow.duration = 2.0;
    windowGlow.autoreverses = YES;
    windowGlow.repeatCount = HUGE_VALF;
    
    window.contentView.layer.shadowColor = [NSColor colorWithRed:0.3 green:0.6 blue:1.0 alpha:1.0].CGColor;
    window.contentView.layer.shadowRadius = 20.0;
    window.contentView.layer.shadowOffset = CGSizeMake(0, -5);
    
    [window.contentView.layer addAnimation:windowGlow forKey:@"windowGlow"];
    
    NSLog(@"⚪️ Window glow animation started");
}

- (void)viewWillLayout {
    [super viewWillLayout];
    
    if (self.metalView) {
        self.metalView.frame = self.view.bounds;
    }
}

@end
