//
//  RMCoreTestAppDelegate.m
//  RMCoreTest
//
//  Created by Dan Kane on 6/26/12.
//  Copyright (c) 2012 DK Technologies. All rights reserved.
//

#import "RMCoreTestAppDelegate.h"
#import "MasterViewController.h"

@implementation RMCoreTestAppDelegate

@synthesize window = _window;
@synthesize navigationController = _navigationController;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    masterViewController = [[MasterViewController alloc] initWithNibName:@"MasterViewController" bundle:nil];
    self.navigationController = [[UINavigationController alloc] initWithRootViewController:masterViewController];
    self.window.rootViewController = self.navigationController;
    [self.window makeKeyAndVisible];
    
    [RMCore setDelegate:self];
    
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    
    return YES;
}

- (void)robotDidConnect:(RMCoreRobot *)robot
{
    if ([robot isKindOfClass:[RMCoreRobotRomo3 class]]) {
        self.robot = (RMCoreRobotRomo3 *)robot;
        self.robot.robotMotionEnabled = YES;
        [self updateInfo];
    }
}

- (void)robotDidDisconnect:(RMCoreRobot *)robot
{
    self.robot = nil;
    [self.navigationController popToRootViewControllerAnimated:YES];
    [self updateInfo];
}

- (void)updateInfo
{
    if (self.robot) {
        [masterViewController updateInfoName:self.robot.identification.name
                                manufacturer:self.robot.identification.manufacturer
                                 modelNumber:self.robot.identification.modelNumber
                                serialNumber:self.robot.identification.serialNumber
                                 firmwareRev:self.robot.identification.firmwareVersion
                                 hardwareRev:self.robot.identification.hardwareVersion
                               bootloaderRev:self.robot.identification.bootloaderVersion];
    } else {
        [masterViewController updateInfoName:@"Not Connected"
                                manufacturer:@"-"
                                 modelNumber:@"-"
                                serialNumber:@"-"
                                 firmwareRev:@"-"
                                 hardwareRev:@"-"
                               bootloaderRev:@"-"];
    }
}

@end
