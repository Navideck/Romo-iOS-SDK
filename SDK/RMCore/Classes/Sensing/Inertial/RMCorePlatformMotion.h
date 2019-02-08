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
//  RMCorePlatformMotion.h
//  RMCore
//
//  Created by Romotive on 4/29/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
//==============================================================================
/** @file RMCorePlatformMotion.h
 @brief Private header for (mobility) Platform Motion module.  This is where 
 iDevice IMU data is taken in an turned into use data in the robot base's
 reference frame.
 */
 
#import <Foundation/Foundation.h>
#import "RMCoreMotionInterface.h"
#import "RobotMotionProtocol.h"

/**
 @brief An RMCorePlatformMotion calculates and stores inertial measurements
 in the robot's mobility platform's reference frame.
 */

@interface RMCorePlatformMotion : NSObject

/**
 Yaw rate of the platform around the gravity vector.
 */
@property (nonatomic, readonly) float yawRate;

/**
 Acceleration in platform's frame of reference 
 x: aligned with axis orthogonal to the side of the robot
 y: aligned with axis orthogonal to the front of the robot
 z: aligned with axis orthogonal to the bottom of robot
 */
@property (nonatomic, readonly) CMAcceleration acceleration;

/**
 Attitude of the platform.  Accuracy is depenedent on the platform being on 
 level ground when the reference was taken (via takeReferenceAttitude method).
 */
@property (nonatomic, readonly) RMCoreAttitude attitude;

/**
 Latest packet of IMU data.
 */
@property (nonatomic) RMCoreIMUData freshIMUData;

/**
 Sets the iDevice's current attitude as the reference attitude that is used to
 determine the attitude of the mobility platform.  It is intended that this
 reference is taken when the robot is situated on level ground.
 */
- (void)takeReferenceAttitude;

@end
