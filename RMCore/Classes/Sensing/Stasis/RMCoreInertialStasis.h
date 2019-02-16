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
//  RMCoreInertialStasis.h
//  RMCore
//
//  Created by Romotive on 10/03/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
//==============================================================================
/** @file RMCoreInertialStasis.h
 @brief Private header for inertial stasis detection module.
 */

#import <Foundation/Foundation.h>
#import "RMCoreRobot.h"
#import "RMCoreRobotMotion.h"


#define UPDATE_FREQUENCY          20      // Hz, sensing rate

/**
 @brief An RMCoreInertialStasis object helps detects when the robot is stuck by
 using feedback from the IMU in conjunction with knowledge of the freshest drive
 command.
  */
@interface RMCoreInertialStasis : NSObject

@property (nonatomic, weak) RMCoreRobot <RobotMotionProtocol, DriveProtocol> *robot;

@end