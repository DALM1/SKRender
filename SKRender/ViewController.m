//
//  ViewController.m
//  SKRender
//
//  Created by Dimitri ALMON on 16/06/2025.
//

#import "ViewController.h"
#import "Core/SKEngine.h"
#import "Rendering/SKRenderer.h"
#import "Controls/SKStormController.h"
#import <QuartzCore/QuartzCore.h>
#import <ImageIO/ImageIO.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

// Callback function for CGDataProviderReleaseDataCallback
void releaseData(void *info, const void *data, size_t size) {
    free((void *)data);
}

@interface ViewController () <SKStormControllerDelegate>

@property (nonatomic, strong) SKRenderer *renderer;
@property (nonatomic, strong) MTKView *metalView;
@property (nonatomic, strong) NSView *controlPanel;
@property (nonatomic, strong) NSScrollView *controlScrollView;

@property (nonatomic, strong) NSSlider *lightningIntensitySlider;
@property (nonatomic, strong) NSSlider *lightningFrequencySlider;
@property (nonatomic, strong) NSSlider *rainIntensitySlider;
@property (nonatomic, strong) NSSlider *windSpeedSlider;
@property (nonatomic, strong) NSSlider *stormIntensitySlider;
@property (nonatomic, strong) NSSlider *flashDurationSlider;
@property (nonatomic, strong) NSSlider *branchFactorSlider;
@property (nonatomic, strong) NSSlider *electricGlowSlider;

@property (nonatomic, strong) NSColorWell *lightningColorWell;
@property (nonatomic, strong) NSColorWell *skyTintColorWell;

@property (nonatomic, strong) NSButton *manualLightningButton;
@property (nonatomic, strong) NSPopUpButton *presetButton;
@property (nonatomic, strong) NSButton *resetButton;
@property (nonatomic, strong) NSButton *toggleControlsButton;

@property (nonatomic, strong) NSButton *recordGifButton;
@property (nonatomic, strong) NSSlider *gifDurationSlider;
@property (nonatomic, strong) NSSlider *gifFrameRateSlider;
@property (nonatomic, strong) NSTextField *recordingStatusLabel;

@property (nonatomic, assign) BOOL controlsVisible;
@property (nonatomic, assign) BOOL isRecordingGif;
@property (nonatomic, strong) NSMutableArray *capturedFrames;
@property (nonatomic, strong) NSTimer *gifCaptureTimer;
@property (nonatomic, assign) NSTimeInterval gifStartTime;
@property (nonatomic, assign) float gifDuration;
@property (nonatomic, assign) float gifFrameRate;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self setupMetalView];
    [self setupRenderer];
    [self setupControlPanel];
    [self setupStormController];
    [self initializeGifProperties];

    self.controlsVisible = YES;
}

- (void)dealloc {
    [self.gifCaptureTimer invalidate];
    self.gifCaptureTimer = nil;
}

- (void)initializeGifProperties {
    self.isRecordingGif = NO;
    self.capturedFrames = [[NSMutableArray alloc] init];
    self.gifDuration = 5.0f;
    self.gifFrameRate = 15.0f;
}

- (void)setupMetalView {
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (!device) {
        return;
    }

    self.metalView = [[MTKView alloc] initWithFrame:self.view.bounds device:device];
    self.metalView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.metalView.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    self.metalView.depthStencilPixelFormat = MTLPixelFormatDepth32Float;
    self.metalView.preferredFramesPerSecond = 60;
    self.metalView.clearColor = MTLClearColorMake(0.02, 0.02, 0.05, 1.0);
    self.metalView.framebufferOnly = NO;

    [self.view addSubview:self.metalView];
    [self setupStormWindowEffects];
}

- (void)setupRenderer {
    self.renderer = [[SKRenderer alloc] initWithView:self.metalView];
    if (!self.renderer) {
        return;
    }

    self.metalView.delegate = self.renderer;
    [[SKEngine sharedEngine] initializeWithView:self.metalView context:nil];
}

- (void)setupControlPanel {
    NSRect controlFrame = NSMakeRect(20, 20, 300, self.view.bounds.size.height - 80);

    self.controlScrollView = [[NSScrollView alloc] initWithFrame:controlFrame];
    self.controlScrollView.hasVerticalScroller = YES;
    self.controlScrollView.hasHorizontalScroller = NO;
    self.controlScrollView.autohidesScrollers = NO;
    self.controlScrollView.borderType = NSNoBorder;
    self.controlScrollView.backgroundColor = [NSColor clearColor];
    self.controlScrollView.wantsLayer = YES;
    self.controlScrollView.layer.cornerRadius = 12.0;
    self.controlScrollView.layer.borderWidth = 1.0;
    self.controlScrollView.layer.borderColor = [NSColor colorWithRed:0.3 green:0.6 blue:1.0 alpha:0.4].CGColor;
    self.controlScrollView.layer.backgroundColor = [NSColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.7].CGColor;

    self.controlPanel = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 280, 750)];
    self.controlPanel.wantsLayer = YES;
    self.controlPanel.layer.backgroundColor = [NSColor clearColor].CGColor;

    self.controlScrollView.documentView = self.controlPanel;

    [self.view addSubview:self.controlScrollView];

    [self setupControlElements];
}

- (void)setupControlElements {
    CGFloat y = 710;
    CGFloat spacing = 35;

    NSTextField *titleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, y, 240, 25)];
    titleLabel.stringValue = @"Lightning Storm Controls";
    titleLabel.editable = NO;
    titleLabel.bordered = NO;
    titleLabel.backgroundColor = [NSColor clearColor];
    titleLabel.textColor = [NSColor whiteColor];
    titleLabel.font = [NSFont boldSystemFontOfSize:16];
    titleLabel.alignment = NSTextAlignmentCenter;
    [self.controlPanel addSubview:titleLabel];
    y -= spacing;

    self.lightningIntensitySlider = [self createSliderWithLabel:@"Lightning Intensity" frame:NSMakeRect(20, y, 240, 25) min:0.0 max:2.0 value:0.8];
    y -= spacing;

    self.lightningFrequencySlider = [self createSliderWithLabel:@"Lightning Frequency" frame:NSMakeRect(20, y, 240, 25) min:0.0 max:2.0 value:0.6];
    y -= spacing;

    self.rainIntensitySlider = [self createSliderWithLabel:@"Rain Intensity" frame:NSMakeRect(20, y, 240, 25) min:0.0 max:2.0 value:0.7];
    y -= spacing;

    self.windSpeedSlider = [self createSliderWithLabel:@"Wind Speed" frame:NSMakeRect(20, y, 240, 25) min:0.0 max:2.0 value:0.5];
    y -= spacing;

    self.stormIntensitySlider = [self createSliderWithLabel:@"Storm Intensity" frame:NSMakeRect(20, y, 240, 25) min:0.0 max:2.0 value:0.8];
    y -= spacing;

    self.flashDurationSlider = [self createSliderWithLabel:@"Flash Duration" frame:NSMakeRect(20, y, 240, 25) min:0.01 max:1.0 value:0.15];
    y -= spacing;

    self.branchFactorSlider = [self createSliderWithLabel:@"Branch Factor" frame:NSMakeRect(20, y, 240, 25) min:0.0 max:1.0 value:0.4];
    y -= spacing;

    self.electricGlowSlider = [self createSliderWithLabel:@"Electric Glow" frame:NSMakeRect(20, y, 240, 25) min:0.0 max:3.0 value:0.9];
    y -= spacing;

    NSTextField *colorLabel1 = [self createLabel:@"Lightning Color" frame:NSMakeRect(20, y, 130, 20)];
    [self.controlPanel addSubview:colorLabel1];
    self.lightningColorWell = [[NSColorWell alloc] initWithFrame:NSMakeRect(160, y, 60, 20)];
    self.lightningColorWell.color = [NSColor colorWithRed:0.9 green:0.95 blue:1.0 alpha:1.0];
    self.lightningColorWell.target = self;
    self.lightningColorWell.action = @selector(lightningColorChanged:);
    [self.controlPanel addSubview:self.lightningColorWell];
    y -= spacing;

    NSTextField *colorLabel2 = [self createLabel:@"Sky Tint" frame:NSMakeRect(20, y, 130, 20)];
    [self.controlPanel addSubview:colorLabel2];
    self.skyTintColorWell = [[NSColorWell alloc] initWithFrame:NSMakeRect(160, y, 60, 20)];
    self.skyTintColorWell.color = [NSColor colorWithRed:0.05 green:0.08 blue:0.2 alpha:1.0];
    self.skyTintColorWell.target = self;
    self.skyTintColorWell.action = @selector(skyTintChanged:);
    [self.controlPanel addSubview:self.skyTintColorWell];
    y -= spacing;

    self.manualLightningButton = [[NSButton alloc] initWithFrame:NSMakeRect(20, y, 240, 30)];
    self.manualLightningButton.title = @"MANUAL LIGHTNING";
    self.manualLightningButton.bezelStyle = NSBezelStyleRounded;
    self.manualLightningButton.target = self;
    self.manualLightningButton.action = @selector(triggerManualLightning:);
    [self.controlPanel addSubview:self.manualLightningButton];
    y -= spacing + 5;

    NSTextField *gifSectionLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, y, 240, 20)];
    gifSectionLabel.stringValue = @"GIF Recording";
    gifSectionLabel.editable = NO;
    gifSectionLabel.bordered = NO;
    gifSectionLabel.backgroundColor = [NSColor clearColor];
    gifSectionLabel.textColor = [NSColor colorWithRed:0.8 green:0.9 blue:1.0 alpha:1.0];
    gifSectionLabel.font = [NSFont boldSystemFontOfSize:14];
    gifSectionLabel.alignment = NSTextAlignmentCenter;
    [self.controlPanel addSubview:gifSectionLabel];
    y -= 25;

    self.gifDurationSlider = [self createSliderWithLabel:@"GIF Duration (seconds)" frame:NSMakeRect(20, y, 240, 25) min:1.0 max:30.0 value:5.0];
    y -= spacing;

    self.gifFrameRateSlider = [self createSliderWithLabel:@"Frame Rate (fps)" frame:NSMakeRect(20, y, 240, 25) min:5.0 max:30.0 value:15.0];
    y -= spacing;

    self.recordGifButton = [[NSButton alloc] initWithFrame:NSMakeRect(20, y, 240, 30)];
    self.recordGifButton.title = @"START GIF RECORDING";
    self.recordGifButton.bezelStyle = NSBezelStyleRounded;
    self.recordGifButton.target = self;
    self.recordGifButton.action = @selector(toggleGifRecording:);
    [self.controlPanel addSubview:self.recordGifButton];
    y -= 35;

    self.recordingStatusLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, y, 240, 20)];
    self.recordingStatusLabel.stringValue = @"Ready to record";
    self.recordingStatusLabel.editable = NO;
    self.recordingStatusLabel.bordered = NO;
    self.recordingStatusLabel.backgroundColor = [NSColor clearColor];
    self.recordingStatusLabel.textColor = [NSColor colorWithRed:0.6 green:0.8 blue:0.6 alpha:1.0];
    self.recordingStatusLabel.font = [NSFont systemFontOfSize:11];
    self.recordingStatusLabel.alignment = NSTextAlignmentCenter;
    [self.controlPanel addSubview:self.recordingStatusLabel];
    y -= 30;

    self.presetButton = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(20, y, 150, 25)];
    [self.presetButton addItemWithTitle:@"Select Preset"];
    [self.presetButton addItemWithTitle:@"Gentle Storm"];
    [self.presetButton addItemWithTitle:@"Violent Storm"];
    [self.presetButton addItemWithTitle:@"Purple Storm"];
    self.presetButton.target = self;
    self.presetButton.action = @selector(presetSelected:);
    [self.controlPanel addSubview:self.presetButton];

    self.resetButton = [[NSButton alloc] initWithFrame:NSMakeRect(180, y, 60, 25)];
    self.resetButton.title = @"Reset";
    self.resetButton.bezelStyle = NSBezelStyleRounded;
    self.resetButton.target = self;
    self.resetButton.action = @selector(resetControls:);
    [self.controlPanel addSubview:self.resetButton];

    self.toggleControlsButton = [[NSButton alloc] initWithFrame:NSMakeRect(self.view.bounds.size.width - 60, self.view.bounds.size.height - 40, 40, 25)];
    self.toggleControlsButton.title = @"Settings";
    self.toggleControlsButton.bezelStyle = NSBezelStyleRounded;
    self.toggleControlsButton.target = self;
    self.toggleControlsButton.action = @selector(toggleControls:);
    [self.view addSubview:self.toggleControlsButton];
}

- (NSSlider *)createSliderWithLabel:(NSString *)label frame:(NSRect)frame min:(double)min max:(double)max value:(double)value {
    NSTextField *labelField = [self createLabel:label frame:NSMakeRect(frame.origin.x, frame.origin.y + 15, frame.size.width, 15)];
    [self.controlPanel addSubview:labelField];

    NSSlider *slider = [[NSSlider alloc] initWithFrame:NSMakeRect(frame.origin.x, frame.origin.y, frame.size.width, 20)];
    slider.minValue = min;
    slider.maxValue = max;
    slider.doubleValue = value;
    slider.continuous = YES;
    slider.target = self;
    slider.action = @selector(sliderChanged:);
    [self.controlPanel addSubview:slider];

    return slider;
}

- (NSTextField *)createLabel:(NSString *)text frame:(NSRect)frame {
    NSTextField *label = [[NSTextField alloc] initWithFrame:frame];
    label.stringValue = text;
    label.editable = NO;
    label.bordered = NO;
    label.backgroundColor = [NSColor clearColor];
    label.textColor = [NSColor whiteColor];
    label.font = [NSFont systemFontOfSize:12];
    return label;
}

- (void)setupStormController {
    SKStormController *controller = [SKStormController sharedController];
    controller.delegate = self;
}

- (void)sliderChanged:(NSSlider *)sender {
    SKStormController *controller = [SKStormController sharedController];

    if (sender == self.lightningIntensitySlider) {
        [controller setLightningIntensity:sender.floatValue];
    } else if (sender == self.lightningFrequencySlider) {
        [controller setLightningFrequency:sender.floatValue];
    } else if (sender == self.rainIntensitySlider) {
        [controller setRainIntensity:sender.floatValue];
    } else if (sender == self.windSpeedSlider) {
        [controller setWindSpeed:sender.floatValue];
    } else if (sender == self.stormIntensitySlider) {
        [controller setStormIntensity:sender.floatValue];
    } else if (sender == self.flashDurationSlider) {
        [controller setFlashDuration:sender.floatValue];
    } else if (sender == self.branchFactorSlider) {
        [controller setBranchFactor:sender.floatValue];
    } else if (sender == self.electricGlowSlider) {
        [controller setElectricGlow:sender.floatValue];
    } else if (sender == self.gifDurationSlider) {
        self.gifDuration = sender.floatValue;
    } else if (sender == self.gifFrameRateSlider) {
        self.gifFrameRate = sender.floatValue;
    }
}

- (void)lightningColorChanged:(NSColorWell *)sender {
    NSColor *color = [sender.color colorUsingColorSpace:[NSColorSpace deviceRGBColorSpace]];
    if (color) {
        vector_float3 colorVec = {color.redComponent, color.greenComponent, color.blueComponent};
        [[SKStormController sharedController] setLightningColor:colorVec];
    }
}

- (void)skyTintChanged:(NSColorWell *)sender {
    NSColor *color = [sender.color colorUsingColorSpace:[NSColorSpace deviceRGBColorSpace]];
    if (color) {
        vector_float3 colorVec = {color.redComponent, color.greenComponent, color.blueComponent};
        [[SKStormController sharedController] setSkyTint:colorVec];
    }
}

- (void)triggerManualLightning:(NSButton *)sender {
    [[SKStormController sharedController] triggerManualLightning];
}

- (void)presetSelected:(NSPopUpButton *)sender {
    NSString *presetName = sender.selectedItem.title;
    if (![presetName isEqualToString:@"Select Preset"]) {
        [[SKStormController sharedController] loadPreset:presetName];
        [self updateControlsFromParameters];
    }
}

- (void)resetControls:(NSButton *)sender {
    [[SKStormController sharedController] resetToDefaults];
    [self updateControlsFromParameters];
}

- (void)toggleControls:(NSButton *)sender {
    self.controlsVisible = !self.controlsVisible;

    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.3;
        self.controlScrollView.animator.alphaValue = self.controlsVisible ? 1.0 : 0.0;
    } completionHandler:nil];

    self.toggleControlsButton.title = self.controlsVisible ? @"Settings" : @"Show";
}

- (void)updateControlsFromParameters {
    StormParameters params = [SKStormController sharedController].currentParameters;

    self.lightningIntensitySlider.floatValue = params.lightningIntensity;
    self.lightningFrequencySlider.floatValue = params.lightningFrequency;
    self.rainIntensitySlider.floatValue = params.rainIntensity;
    self.windSpeedSlider.floatValue = params.windSpeed;
    self.stormIntensitySlider.floatValue = params.stormIntensity;
    self.flashDurationSlider.floatValue = params.flashDuration;
    self.branchFactorSlider.floatValue = params.branchFactor;
    self.electricGlowSlider.floatValue = params.electricGlow;

    self.lightningColorWell.color = [NSColor colorWithRed:params.lightningColor.x
                                                   green:params.lightningColor.y
                                                    blue:params.lightningColor.z
                                                   alpha:1.0];

    self.skyTintColorWell.color = [NSColor colorWithRed:params.skyTint.x
                                                 green:params.skyTint.y
                                                  blue:params.skyTint.z
                                                 alpha:1.0];

    self.gifDurationSlider.floatValue = self.gifDuration;
    self.gifFrameRateSlider.floatValue = self.gifFrameRate;
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
}

- (void)viewDidAppear {
    [super viewDidAppear];
    [self.metalView setNeedsDisplay:YES];
    [self setupLightningWindowAnimations];
}

- (void)setupLightningWindowAnimations {
    NSWindow *window = self.view.window;
    if (!window) return;

    window.contentView.wantsLayer = YES;

    CAKeyframeAnimation *lightningFlash = [CAKeyframeAnimation animationWithKeyPath:@"shadowOpacity"];
    lightningFlash.values = @[@(0.3), @(1.0), @(0.4), @(0.9), @(0.3)];
    lightningFlash.keyTimes = @[@(0.0), @(0.05), @(0.1), @(0.12), @(1.0)];
    lightningFlash.duration = 3.5;
    lightningFlash.repeatCount = HUGE_VALF;

    window.contentView.layer.shadowColor = [NSColor colorWithRed:0.4 green:0.7 blue:1.0 alpha:1.0].CGColor;
    window.contentView.layer.shadowRadius = 30.0;
    window.contentView.layer.shadowOffset = NSMakeSize(0, -8);

    [window.contentView.layer addAnimation:lightningFlash forKey:@"lightningFlash"];
}

- (void)viewWillLayout {
    [super viewWillLayout];

    if (self.metalView) {
        self.metalView.frame = self.view.bounds;
    }

    if (self.controlScrollView) {
        NSRect newFrame = self.controlScrollView.frame;
        newFrame.size.height = self.view.bounds.size.height - 80;
        self.controlScrollView.frame = newFrame;
    }

    if (self.toggleControlsButton) {
        NSRect buttonFrame = self.toggleControlsButton.frame;
        buttonFrame.origin.x = self.view.bounds.size.width - 60;
        buttonFrame.origin.y = self.view.bounds.size.height - 40;
        self.toggleControlsButton.frame = buttonFrame;
    }
}

- (void)stormController:(SKStormController *)controller didUpdateParameters:(void *)params {
    if (self.renderer) {
        [self.renderer updateStormParameters:params];
    }
}

- (void)stormControllerDidTriggerLightning:(SKStormController *)controller {
    if (self.renderer) {
        [self.renderer triggerManualLightning];
    }
}

#pragma mark - GIF Recording Methods

- (void)toggleGifRecording:(NSButton *)sender {
    if (self.isRecordingGif) {
        [self stopGifRecording];
    } else {
        [self startGifRecording];
    }
}

- (void)startGifRecording {
    self.isRecordingGif = YES;
    self.gifStartTime = CACurrentMediaTime();
    [self.capturedFrames removeAllObjects];

    self.recordGifButton.title = @"STOP RECORDING";
    self.recordingStatusLabel.stringValue = @"Recording...";
    self.recordingStatusLabel.textColor = [NSColor colorWithRed:1.0 green:0.6 blue:0.6 alpha:1.0];

    float captureInterval = 1.0f / self.gifFrameRate;
    self.gifCaptureTimer = [NSTimer scheduledTimerWithTimeInterval:captureInterval
                                                           target:self
                                                         selector:@selector(gifCaptureTimerFired:)
                                                         userInfo:nil
                                                          repeats:YES];
}

- (void)stopGifRecording {
    self.isRecordingGif = NO;
    [self.gifCaptureTimer invalidate];
    self.gifCaptureTimer = nil;

    self.recordGifButton.title = @"START GIF RECORDING";
    self.recordingStatusLabel.stringValue = @"Processing...";
    self.recordingStatusLabel.textColor = [NSColor colorWithRed:1.0 green:0.8 blue:0.4 alpha:1.0];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self createGifFromFrames];
    });
}

- (void)gifCaptureTimerFired:(NSTimer *)timer {
    NSTimeInterval currentTime = CACurrentMediaTime();
    if (currentTime - self.gifStartTime >= self.gifDuration) {
        [self stopGifRecording];
        return;
    }

    [self captureFrame];
}

- (void)captureFrame {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.metalView.currentDrawable || !self.metalView.currentDrawable.texture) return;

        id<MTLTexture> sourceTexture = self.metalView.currentDrawable.texture;
        NSUInteger width = sourceTexture.width;
        NSUInteger height = sourceTexture.height;
        NSUInteger bytesPerRow = 4 * width;
        NSUInteger length = bytesPerRow * height;

        void *bytes = malloc(length);
        if (!bytes) return;

        [sourceTexture getBytes:bytes
                    bytesPerRow:bytesPerRow
                     fromRegion:MTLRegionMake2D(0, 0, width, height)
                    mipmapLevel:0];

        CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, bytes, length, releaseData);

        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

        CGImageRef cgImage = CGImageCreate(width, height, 8, 32, bytesPerRow,
                                         colorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little,
                                         provider, NULL, false, kCGRenderingIntentDefault);

        if (cgImage) {
            [self.capturedFrames addObject:(__bridge id)cgImage];
            CGImageRelease(cgImage);
        }

        CGColorSpaceRelease(colorSpace);
        CGDataProviderRelease(provider);
    });
}

- (void)createGifFromFrames {
    if (self.capturedFrames.count == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.recordingStatusLabel.stringValue = @"No frames captured";
            self.recordingStatusLabel.textColor = [NSColor colorWithRed:1.0 green:0.4 blue:0.4 alpha:1.0];
        });
        return;
    }

    NSSavePanel *savePanel = [NSSavePanel savePanel];
    if (@available(macOS 11.0, *)) {
        savePanel.allowedContentTypes = @[UTTypeGIF];
    } else {
        savePanel.allowedFileTypes = @[@"gif"];
    }
    savePanel.nameFieldStringValue = @"storm_animation.gif";

    dispatch_async(dispatch_get_main_queue(), ^{
        [savePanel beginWithCompletionHandler:^(NSModalResponse result) {
            if (result == NSModalResponseOK) {
                NSURL *fileURL = savePanel.URL;
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    [self writeGifToURL:fileURL];
                });
            } else {
                self.recordingStatusLabel.stringValue = @"Save cancelled";
                self.recordingStatusLabel.textColor = [NSColor colorWithRed:0.8 green:0.8 blue:0.4 alpha:1.0];
            }
        }];
    });
}

- (void)writeGifToURL:(NSURL *)fileURL {
    CFStringRef gifType;
    if (@available(macOS 11.0, *)) {
        gifType = (__bridge CFStringRef)UTTypeGIF.identifier;
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        gifType = kUTTypeGIF;
#pragma clang diagnostic pop
    }

    CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)fileURL,
                                                                       gifType, self.capturedFrames.count, NULL);
    if (!destination) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.recordingStatusLabel.stringValue = @"Failed to create GIF";
            self.recordingStatusLabel.textColor = [NSColor colorWithRed:1.0 green:0.4 blue:0.4 alpha:1.0];
        });
        return;
    }

    float frameDuration = 1.0f / self.gifFrameRate;
    NSDictionary *frameProperties = @{
        (__bridge NSString *)kCGImagePropertyGIFDictionary: @{
            (__bridge NSString *)kCGImagePropertyGIFDelayTime: @(frameDuration)
        }
    };

    NSDictionary *gifProperties = @{
        (__bridge NSString *)kCGImagePropertyGIFDictionary: @{
            (__bridge NSString *)kCGImagePropertyGIFLoopCount: @0
        }
    };

    CGImageDestinationSetProperties(destination, (__bridge CFDictionaryRef)gifProperties);

    for (id imageRef in self.capturedFrames) {
        CGImageDestinationAddImage(destination, (__bridge CGImageRef)imageRef, (__bridge CFDictionaryRef)frameProperties);
    }

    BOOL success = CGImageDestinationFinalize(destination);
    CFRelease(destination);

    dispatch_async(dispatch_get_main_queue(), ^{
        if (success) {
            self.recordingStatusLabel.stringValue = @"GIF saved successfully!";
            self.recordingStatusLabel.textColor = [NSColor colorWithRed:0.6 green:1.0 blue:0.6 alpha:1.0];
        } else {
            self.recordingStatusLabel.stringValue = @"Failed to save GIF";
            self.recordingStatusLabel.textColor = [NSColor colorWithRed:1.0 green:0.4 blue:0.4 alpha:1.0];
        }

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.recordingStatusLabel.stringValue = @"Ready to record";
            self.recordingStatusLabel.textColor = [NSColor colorWithRed:0.6 green:0.8 blue:0.6 alpha:1.0];
        });
    });
}

@end

