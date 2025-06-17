//
//  AppDelegate.h
//  SKRender
//
//  Created by Dimitri ALMON on 16/06/2025.
//

#ifndef AppDelegate_h
#define AppDelegate_h

#import <Cocoa/Cocoa.h>
#import <CoreData/CoreData.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (readonly, strong) NSPersistentContainer *persistentContainer;

@end

#endif
