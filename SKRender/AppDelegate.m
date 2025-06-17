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
    
    [self setupGlobalGlassmorphismEffects];
    
    NSLog(@"⚪️ Glassmorphism application launched");
}

- (void)setupGlobalGlassmorphismEffects {
    for (NSWindow *window in [NSApplication sharedApplication].windows) {
        [self applyGlassmorphismToWindow:window];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(windowDidBecomeKey:)
                                                 name:NSWindowDidBecomeKeyNotification
                                               object:nil];
}

- (void)applyGlassmorphismToWindow:(NSWindow *)window {
    if (!window) return;
    
    window.titlebarAppearsTransparent = YES;
    window.titleVisibility = NSWindowTitleHidden;
    window.styleMask |= NSWindowStyleMaskFullSizeContentView;
    
    window.backgroundColor = [NSColor colorWithRed:0.02 green:0.05 blue:0.12 alpha:0.85];
    
    if (@available(macOS 10.14, *)) {
        window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    }
    
    window.contentView.wantsLayer = YES;
    window.contentView.layer.cornerRadius = 12.0;
    window.contentView.layer.masksToBounds = NO;
    
    window.contentView.layer.borderWidth = 1.0;
    window.contentView.layer.borderColor = [NSColor colorWithRed:0.3 green:0.6 blue:1.0 alpha:0.3].CGColor;
    
    window.contentView.layer.shadowColor = [NSColor colorWithRed:0.2 green:0.5 blue:0.9 alpha:0.6].CGColor;
    window.contentView.layer.shadowOpacity = 0.5;
    window.contentView.layer.shadowRadius = 25.0;
    window.contentView.layer.shadowOffset = CGSizeMake(0, -10);
    
    [self animateWindowGlow:window];
    
    NSLog(@"⚪️ Glassmorphism applied to window: %@", window.title);
}

- (void)animateWindowGlow:(NSWindow *)window {
    CABasicAnimation *glowAnimation = [CABasicAnimation animationWithKeyPath:@"shadowOpacity"];
    glowAnimation.fromValue = @(0.3);
    glowAnimation.toValue = @(0.8);
    glowAnimation.duration = 3.0;
    glowAnimation.autoreverses = YES;
    glowAnimation.repeatCount = HUGE_VALF;
    glowAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    
    [window.contentView.layer addAnimation:glowAnimation forKey:@"shadowGlow"];
    
    CABasicAnimation *borderAnimation = [CABasicAnimation animationWithKeyPath:@"borderColor"];
    borderAnimation.fromValue = (id)[NSColor colorWithRed:0.3 green:0.6 blue:1.0 alpha:0.2].CGColor;
    borderAnimation.toValue = (id)[NSColor colorWithRed:0.5 green:0.8 blue:1.0 alpha:0.6].CGColor;
    borderAnimation.duration = 4.0;
    borderAnimation.autoreverses = YES;
    borderAnimation.repeatCount = HUGE_VALF;
    borderAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    
    [window.contentView.layer addAnimation:borderAnimation forKey:@"borderGlow"];
}

- (void)windowDidBecomeKey:(NSNotification *)notification {
    NSWindow *window = notification.object;
    [self applyGlassmorphismToWindow:window];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [self save];
    NSLog(@"⚪️ Glassmorphism application terminating");
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
