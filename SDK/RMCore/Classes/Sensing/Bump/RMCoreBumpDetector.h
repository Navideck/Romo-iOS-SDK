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
//  RMCoreBumpDetector.h
//  RMCore
//
//  Created by Romotive on 09/28/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
//==============================================================================
/** @file RMCoreBumpDetector.h
 @brief Private header for bump detection module.  
 */

#import <Foundation/Foundation.h>
#import "RMCoreRobot.h"
#import "RMCoreRobotMotion.h"


#define UPDATE_FREQUENCY          20      // Hz, sensing rate

/**
 @brief An RMCoreBumpDetector object detects when the robot bumps into somthing.
  */
@interface RMCoreBumpDetector : NSObject

@property (nonatomic, weak) RMCoreRobot <RobotMotionProtocol, DriveProtocol> *robot;

@end