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
//  RMCoreRobotRomo3.h
//  RMCore
//
//  Created by Romotive on 1/15/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
//==============================================================================
/** @file RMCoreRobotRomo3.h
 @brief Public header defining the ROMO3A implementation of a RMCoreRobot
 */
#import "RMCoreRobot.h"
#import "DifferentialDriveProtocol.h"
#import "RobotMotionProtocol.h"

/** Distance between left & right tracks (meters) */
#define TRACK_SPACING      0.10

/** Top linear speed (meters / second) */
#define RM_MAX_DRIVE_SPEED 1.00

/**
 @brief An RMCoreRobotRomo3 is a subclass of RMCoreRobot that defines which
 protocols are supported by ROMO3A.
 
 ROMO3A conforms to DifferentialDriveProtocol (which inherits from 
 DriveProtocol), HeadTiltProtocol, and LEDProtocol.
 */
@interface RMCoreRobotRomo3 : RMCoreRobot <DifferentialDriveProtocol, HeadTiltProtocol, LEDProtocol, RobotMotionProtocol>

@end