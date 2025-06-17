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
    
    NSLog(@"=== Lightning Storm Scene Setup ===");
    
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (!device) {
        NSLog(@"❌ No Metal device");
        return;
    }
    
    self.metalView = [[MTKView alloc] initWithFrame:self.view.bounds device:device];
    self.metalView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.metalView.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    self.metalView.depthStencilPixelFormat = MTLPixelFormatDepth32Float;
    self.metalView.preferredFramesPerSecond = 60;
    self.metalView.clearColor = MTLClearColorMake(0.02, 0.02, 0.05, 1.0);
    
    [self.view addSubview:self.metalView];
    
    [self setupStormWindowEffects];
    
    self.renderer = [[SKRenderer alloc] initWithView:self.metalView];
    if (!self.renderer) {
        NSLog(@"❌ Failed to create storm renderer");
        return;
    }
    
    self.metalView.delegate = self.renderer;
    
    [[SKEngine sharedEngine] initializeWithView:self.metalView context:nil];
    NSLog(@"⚡ Lightning storm scene ready");
}

- (void)setupStormWindowEffects {
    NSWindow *window = self.view.window;
    if (!window) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setupStormWindowEffects];
        });
        return;
    }
    
    window.titlebarAppearsTransparent = YES;
    window.titleVisibility = NSWindowTitleHidden;
    window.styleMask |= NSWindowStyleMaskFullSizeContentView;
    
    window.backgroundColor = [NSColor colorWithRed:0.01 green:0.01 blue:0.04 alpha:0.95];
    
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
    
    NSLog(@"⚡ Storm window effects applied");
}

- (void)viewDidAppear {
    [super viewDidAppear];
    
    NSLog(@"=== Lightning Storm Active ===");
    [self.metalView setNeedsDisplay:YES];
    
    [self setupLightningWindowAnimations];
}

- (void)setupLightningWindowAnimations {
    NSWindow *window = self.view.window;
    if (!window) return;
    
    window.contentView.wantsLayer = YES;
    
    CABasicAnimation *electricGlow = [CABasicAnimation animationWithKeyPath:@"shadowOpacity"];
    electricGlow.fromValue = @(0.2);
    electricGlow.toValue = @(1.0);
    electricGlow.duration = 0.1;
    electricGlow.autoreverses = YES;
    electricGlow.repeatCount = HUGE_VALF;
    electricGlow.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    
    window.contentView.layer.shadowColor = [NSColor colorWithRed:0.4 green:0.7 blue:1.0 alpha:1.0].CGColor;
    window.contentView.layer.shadowRadius = 30.0;
    window.contentView.layer.shadowOffset = CGSizeMake(0, -8);
    
    [window.contentView.layer addAnimation:electricGlow forKey:@"electricGlow"];
    
    CABasicAnimation *borderFlash = [CABasicAnimation animationWithKeyPath:@"borderColor"];
    borderFlash.fromValue = (id)[NSColor colorWithRed:0.2 green:0.4 blue:0.8 alpha:0.3].CGColor;
    borderFlash.toValue = (id)[NSColor colorWithRed:0.8 green:0.9 blue:1.0 alpha:0.9].CGColor;
    borderFlash.duration = 0.15;
    borderFlash.autoreverses = YES;
    borderFlash.repeatCount = HUGE_VALF;
    borderFlash.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    
    window.contentView.layer.borderWidth = 2.0;
    window.contentView.layer.cornerRadius = 12.0;
    window.contentView.layer.masksToBounds = NO;
    
    [window.contentView.layer addAnimation:borderFlash forKey:@"borderFlash"];
    
    CAKeyframeAnimation *thunderFlash = [CAKeyframeAnimation animationWithKeyPath:@"shadowOpacity"];
    thunderFlash.values = @[@(0.3), @(1.0), @(0.5), @(1.0), @(0.3)];
    thunderFlash.keyTimes = @[@(0.0), @(0.1), @(0.15), @(0.2), @(1.0)];
    thunderFlash.duration = 4.0;
    thunderFlash.repeatCount = HUGE_VALF;
    thunderFlash.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    
    [window.contentView.layer addAnimation:thunderFlash forKey:@"thunderFlash"];
    
    NSLog(@"⚡ Lightning window animations started");
}

- (void)viewWillLayout {
    [super viewWillLayout];
    
    if (self.metalView) {
        self.metalView.frame = self.view.bounds;
    }
}

@end
