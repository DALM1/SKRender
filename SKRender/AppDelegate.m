//
//  AppDelegate.m
//  SKRender
//
//  Created by Dimitri ALMON on 16/06/2025.
//

#import "AppDelegate.h"
#import <QuartzCore/QuartzCore.h>

@interface AppDelegate ()
- (void)save;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"NSQuitAlwaysKeepsWindows"];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"ApplePersistenceIgnoreState"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [self setupLightningStormEffects];
    
    NSLog(@"⚡ Lightning Storm application launched");
}

- (void)setupLightningStormEffects {
    for (NSWindow *window in [NSApplication sharedApplication].windows) {
        [self applyLightningStormToWindow:window];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(windowDidBecomeKey:)
                                                 name:NSWindowDidBecomeKeyNotification
                                               object:nil];
}

- (void)applyLightningStormToWindow:(NSWindow *)window {
    if (!window) return;
    
    window.titlebarAppearsTransparent = YES;
    window.titleVisibility = NSWindowTitleHidden;
    window.styleMask |= NSWindowStyleMaskFullSizeContentView;
    
    window.backgroundColor = [NSColor colorWithRed:0.01 green:0.01 blue:0.04 alpha:0.9];
    
    if (@available(macOS 10.14, *)) {
        window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    }
    
    window.contentView.wantsLayer = YES;
    window.contentView.layer.cornerRadius = 12.0;
    window.contentView.layer.masksToBounds = NO;
    
    window.contentView.layer.borderWidth = 2.0;
    window.contentView.layer.borderColor = [NSColor colorWithRed:0.3 green:0.6 blue:1.0 alpha:0.4].CGColor;
    
    window.contentView.layer.shadowColor = [NSColor colorWithRed:0.4 green:0.7 blue:1.0 alpha:0.8].CGColor;
    window.contentView.layer.shadowOpacity = 0.6;
    window.contentView.layer.shadowRadius = 25.0;
    window.contentView.layer.shadowOffset = CGSizeMake(0, -10);
    
    [self animateLightningStorm:window];
    
    NSLog(@"⚡ Lightning storm applied to window: %@", window.title);
}

- (void)animateLightningStorm:(NSWindow *)window {
    CAKeyframeAnimation *lightningFlash = [CAKeyframeAnimation animationWithKeyPath:@"shadowOpacity"];
    lightningFlash.values = @[@(0.3), @(1.0), @(0.4), @(0.9), @(0.3), @(0.3), @(0.3), @(0.3)];
    lightningFlash.keyTimes = @[@(0.0), @(0.05), @(0.1), @(0.12), @(0.2), @(0.4), @(0.7), @(1.0)];
    lightningFlash.duration = 3.5;
    lightningFlash.repeatCount = HUGE_VALF;
    lightningFlash.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    
    [window.contentView.layer addAnimation:lightningFlash forKey:@"lightningFlash"];
    
    CAKeyframeAnimation *electricBorder = [CAKeyframeAnimation animationWithKeyPath:@"borderColor"];
    NSArray *electricColors = @[
        (id)[NSColor colorWithRed:0.2 green:0.4 blue:0.8 alpha:0.3].CGColor,
        (id)[NSColor colorWithRed:0.9 green:0.95 blue:1.0 alpha:0.9].CGColor,
        (id)[NSColor colorWithRed:0.5 green:0.7 blue:1.0 alpha:0.6].CGColor,
        (id)[NSColor colorWithRed:0.8 green:0.9 blue:1.0 alpha:0.8].CGColor,
        (id)[NSColor colorWithRed:0.2 green:0.4 blue:0.8 alpha:0.3].CGColor
    ];
    electricBorder.values = electricColors;
    electricBorder.keyTimes = @[@(0.0), @(0.05), @(0.1), @(0.12), @(1.0)];
    electricBorder.duration = 3.5;
    electricBorder.repeatCount = HUGE_VALF;
    electricBorder.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    
    [window.contentView.layer addAnimation:electricBorder forKey:@"electricBorder"];
    
    CABasicAnimation *stormGlow = [CABasicAnimation animationWithKeyPath:@"shadowRadius"];
    stormGlow.fromValue = @(15.0);
    stormGlow.toValue = @(35.0);
    stormGlow.duration = 2.0;
    stormGlow.autoreverses = YES;
    stormGlow.repeatCount = HUGE_VALF;
    stormGlow.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    
    [window.contentView.layer addAnimation:stormGlow forKey:@"stormGlow"];
    
    CAKeyframeAnimation *thunderRumble = [CAKeyframeAnimation animationWithKeyPath:@"shadowOffset"];
    NSArray *rumbleOffsets = @[
        [NSValue valueWithSize:NSMakeSize(0, -10)],
        [NSValue valueWithSize:NSMakeSize(-2, -12)],
        [NSValue valueWithSize:NSMakeSize(1, -8)],
        [NSValue valueWithSize:NSMakeSize(-1, -11)],
        [NSValue valueWithSize:NSMakeSize(0, -10)]
    ];
    thunderRumble.values = rumbleOffsets;
    thunderRumble.keyTimes = @[@(0.0), @(0.05), @(0.1), @(0.12), @(1.0)];
    thunderRumble.duration = 3.5;
    thunderRumble.repeatCount = HUGE_VALF;
    
    [window.contentView.layer addAnimation:thunderRumble forKey:@"thunderRumble"];
}

- (void)windowDidBecomeKey:(NSNotification *)notification {
    NSWindow *window = notification.object;
    [self applyLightningStormToWindow:window];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [self save];
    NSLog(@"⚡ Lightning Storm application terminating");
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return NO;
}

- (void)application:(NSApplication *)application didFailToRestoreWindowWithIdentifier:(NSString *)identifier state:(NSCoder *)state error:(NSError *)error {
}

- (BOOL)application:(NSApplication *)application restoreWindowWithIdentifier:(NSString *)identifier state:(NSCoder *)state {
    return NO;
}

#pragma mark - Core Data stack

@synthesize persistentContainer = _persistentContainer;

- (NSPersistentContainer *)persistentContainer {
    @synchronized (self) {
        if (_persistentContainer == nil) {
            _persistentContainer = [[NSPersistentContainer alloc] initWithName:@"SKRender"];
            [_persistentContainer loadPersistentStoresWithCompletionHandler:^(NSPersistentStoreDescription *storeDescription, NSError *error) {
                if (error != nil) {
                    abort();
                }
            }];
        }
    }
    return _persistentContainer;
}

#pragma mark - Core Data Saving and Undo support

- (void)save {
    NSManagedObjectContext *context = self.persistentContainer.viewContext;

    if (![context commitEditing]) {
        return;
    }

    NSError *error = nil;
    if (context.hasChanges && ![context save:&error]) {
        [[NSApplication sharedApplication] presentError:error];
    }
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window {
    return self.persistentContainer.viewContext.undoManager;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    NSManagedObjectContext *context = self.persistentContainer.viewContext;

    if (![context commitEditing]) {
        return NSTerminateCancel;
    }

    if (!context.hasChanges) {
        return NSTerminateNow;
    }

    NSError *error = nil;
    if (![context save:&error]) {
        BOOL result = [sender presentError:error];
        if (result) {
            return NSTerminateCancel;
        }

        NSString *question = NSLocalizedString(@"Could not save changes while quitting. Quit anyway?", @"Quit without saves error question message");
        NSString *info = NSLocalizedString(@"Quitting now will lose any changes you have made since the last successful save", @"Quit without saves error question info");
        NSString *quitButton = NSLocalizedString(@"Quit anyway", @"Quit anyway button title");
        NSString *cancelButton = NSLocalizedString(@"Cancel", @"Cancel button title");
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:question];
        [alert setInformativeText:info];
        [alert addButtonWithTitle:quitButton];
        [alert addButtonWithTitle:cancelButton];

        NSInteger answer = [alert runModal];

        if (answer == NSAlertSecondButtonReturn) {
            return NSTerminateCancel;
        }
    }

    return NSTerminateNow;
}

@end
