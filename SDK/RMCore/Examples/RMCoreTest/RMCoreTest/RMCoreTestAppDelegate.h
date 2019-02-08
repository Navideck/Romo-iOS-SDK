//
//  RMCoreTestAppDelegate.h
//  RMCoreTest
//
//  Created by Dan Kane on 6/26/12.
//  Copyright (c) 2012 DK Technologies. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ExternalAccessory/ExternalAccessory.h"
#import <RMCore/RMCore.h>

@class MasterViewController;

@interface RMCoreTestAppDelegate : UIResponder <UIApplicationDelegate, RMCoreDelegate> {
    NSMutableData *data;
    
    MasterViewController *masterViewController;
    NSTimer *_updateTimer;
}

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) UINavigationController *navigationController;
@property (nonatomic, strong) RMCoreRobotRomo3 *robot;

@end
