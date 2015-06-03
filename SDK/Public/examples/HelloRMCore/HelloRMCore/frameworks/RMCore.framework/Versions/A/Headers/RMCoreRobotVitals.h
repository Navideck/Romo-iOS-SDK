//==============================================================================
//                             _
//                            | | (_)
//   _ __ ___  _ __ ___   ___ | |_ ___   _____
//  | '__/ _ \| '_ ` _ \ / _ \| __| \ \ / / _ \
//  | | | (_) | | | | | | (_) | |_| |\ V /  __/
//  |_|  \___/|_| |_| |_|\___/ \__|_| \_/ \___|
//
//==============================================================================
//
//  RMCoreRobotVitals.h
//  RMCore
//
//  Created by Romotive on 1/15/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
//==============================================================================
/** @file RMCoreRobotVitals.h
 @brief Public header for RMCoreRobotVitals, which handles queries to the 
 RMCoreRobot hardware's internal state.
 */
#import <Foundation/Foundation.h>

/**
 @brief The interface for querying the hardware about its internal state.
 
 This includes battery level, charging status, model name/number, 
 serial number, firmware version, hardware revision, and 
 manufacturer (Romotive!). Every RMCoreRobot instance has an associated 
 RMCoreRobotVitals object.
 */
@interface RMCoreRobotVitals : NSObject 

/**
 The robot's battery level
 Values are on the interval [0,1] (1 = fully charged)
 */
@property (nonatomic, readonly) float batteryLevel;

/**
 A boolean value representing the robot's charging state
 */
@property (nonatomic, readonly, getter=isCharging) BOOL charging;

@end
