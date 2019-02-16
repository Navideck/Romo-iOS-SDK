//
//  AppDelegate.m
//  RMControl
//
//  Created on 8/20/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
#import "RMControlAppDelegate.h"

#import <CoreData/CoreData.h>

#import "RMSessionManager.h"
#import "RMSession.h"
#import <Romo/UIApplication+Environment.h>
#import "RMWiFiDriveRemoteVC.h"
#import "RMSoundEffect.h"
#import "RMRealtimeAudio.h"
#import "RMAnalytics.h"

#import "RMControlSelectionVC.h"

void uncaughtExceptionHandler(NSException *exception) {
    NSLog(@"CRASH: %@", exception);
    NSLog(@"Stack Trace: %@", [exception callStackSymbols]);
}

@implementation RMControlAppDelegate

// Synthesize core data objects
@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
#ifdef DEBUG
    NSSetUncaughtExceptionHandler(&uncaughtExceptionHandler);
#endif
    
    [UIApplication setEnvironmentVariableDefaultValue:@"romotive-telepresence.herokuapp.com" forKey:@"ROMO_TELEPRESENCE_SERVER"];
    [UIApplication setEnvironmentVariableDefaultValue:nil forKey:@"ROMO_LOG_SERVER"];
    [UIApplication setEnvironmentVariableDefaultValue:@"NO" forKey:@"XcodeColors"];
    
    // Load analytics reporting
    [RMAnalytics sharedInstance];
    
    [[RMSessionManager shared] startListeningForRomos];
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor blackColor];
    
//    self.window.rootViewController = [[RMRomoChooserVC alloc] init];
    
//    self.window.rootViewController = [[RMDriveSelectionViewController alloc] initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll
//                                                                               navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal
//                                                                                             options:@{UIPageViewControllerOptionSpineLocationKey:@(UIPageViewControllerSpineLocationMax)}];
    
    self.window.rootViewController = [[RMControlSelectionVC alloc] initWithCollectionViewLayout:[RMControlSelectionVC standardLayout]];
    
    [self.window makeKeyAndVisible];

    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:soundEffectsEnabledKey];
    [[RMRealtimeAudio sharedInstance] startup];

    UIView *blackShade = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    blackShade.backgroundColor = [UIColor blackColor];
    [self.window.rootViewController.view addSubview:blackShade];
    [UIView animateWithDuration:0.35
                     animations:^{
                         blackShade.alpha = 0.0;
                     } completion:^(BOOL finished) {
                         [blackShade removeFromSuperview];
                     }];
    
    return YES;
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    [[RMSessionManager shared] startListeningForRomos];
    [[RMRealtimeAudio sharedInstance] startup];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    [[RMSessionManager shared] stopListeningForRomos];
    [[RMSessionManager shared].activeSession stop];
    [[RMRealtimeAudio sharedInstance] shutdown];
}

#pragma mark - Faking Robot Controller

- (id)robotController
{
    return nil;
}

#pragma mark - Core Data stack
// Returns the managed object context for the application.
// If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
//------------------------------------------------------------------------------
- (NSManagedObjectContext *)managedObjectContext
{
    if (!_managedObjectContext) {
        NSPersistentStoreCoordinator *coordinator = self.persistentStoreCoordinator;
        if (coordinator != nil) {
            _managedObjectContext = [[NSManagedObjectContext alloc] init];
            [_managedObjectContext setPersistentStoreCoordinator:coordinator];
        }
    }
    return _managedObjectContext;
}

// Returns the managed object model for the application.
// If the model doesn't already exist, it is created from the application's model.
//------------------------------------------------------------------------------
- (NSManagedObjectModel *)managedObjectModel
{
    if (!_managedObjectModel) {
        NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"RomoControlContacts" withExtension:@"momd"];
        
        _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    }
    return _managedObjectModel;
}

// Returns the persistent store coordinator for the application.
// If the coordinator doesn't already exist, it is created and the application's store added to it.
//------------------------------------------------------------------------------
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (!_persistentStoreCoordinator) {
        NSURL *storeURL = [self dbUrl];
        
        NSError *error = nil;
        _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.managedObjectModel];
        if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
            /*
             Replace this implementation with code to handle the error appropriately.
             
             abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
             
             Typical reasons for an error here include:
             * The persistent store is not accessible;
             * The schema for the persistent store is incompatible with current managed object model.
             Check the error message to determine what the actual problem was.
             
             
             If the persistent store is not accessible, there is typically something wrong with the file path. Often, a file URL is pointing into the application's resources directory instead of a writeable directory.
             
             If you encounter schema incompatibility errors during development, you can reduce their frequency by:
             * Simply deleting the existing store:
             [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil]
             
             * Performing automatic lightweight migration by passing the following dictionary as the options parameter:
             @{NSMigratePersistentStoresAutomaticallyOption:@YES, NSInferMappingModelAutomaticallyOption:@YES}
             
             Lightweight migration will only work for a limited set of schema changes; consult "Core Data Model Versioning and Data Migration Programming Guide" for details.
             
             */
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }
    
    return _persistentStoreCoordinator;
}

//------------------------------------------------------------------------------
- (NSURL *)dbUrl
{
    NSURL *url = [[[NSFileManager defaultManager] URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] firstObject];
    return [url URLByAppendingPathComponent:@"RomoControlContacts.sqlite"];;
}

@end
