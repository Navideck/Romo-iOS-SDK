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
//  RMCoreDeviceMotion.h
//  RMCore
//
//  Created by Romotive on 4/29/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
//==============================================================================
/** @file RMCoreDeviceMotion.h
 @brief Private header for Device Motion module.  This is where data that's in
 the iDevice's reference frame ends up.
 */

#import <Foundation/Foundation.h>
#import "RMCoreMotionInterface.h"

/**
 @brief An RMCoreDeviceMotion object stores data from the iDevice's IMU.
 
 The data in this module pertains directly to the iDevice (and not necessarily 
 the mobility platform, or, robot as a whole).
 */
@interface RMCoreDeviceMotion : NSObject

// raw IMU sensor data
@property (nonatomic) CMAcceleration accelerometer;
@property (nonatomic) CMRotationRate gyroscope;

// conditioned IMU data (see RobotMotion Protocol for explanation of each)
@property (nonatomic) CMAcceleration deviceAcceleration;
@property (nonatomic) CMAcceleration gravity;
@property (nonatomic) CMRotationRate rotationRate;
@property (nonatomic) CMQuaternion attitude;

// the latest packet of IMU data
@property (nonatomic) RMCoreIMUData freshIMUData;

@end
