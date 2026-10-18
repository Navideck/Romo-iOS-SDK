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
//  DifferentialDriveProtocol.h
//  RMCore
//
//  Created by Romotive on 1/15/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
//==============================================================================
/** @file DifferentialDriveProtocol.h
 @brief Public header defining a protocol for controlling Differential Drive 
 robots within the RMCore framework.
 
 Contains a protocol for driving left and right motors on differential-drive 
 robots.
 */
#import <Foundation/Foundation.h>
#import "DriveProtocol.h"
#import "RMCoreMotor.h"

/**
 @brief A protocol implemented by RMCoreRobot instances that can support 
 Differential Drive commands.
 
 This protocol provides methods for interacting with a Differential Drive 
 robot. When an RMCoreRobot object is instantiated (and when it implements the
 DifferentialDriveProtocol), you may send the robot commands through this 
 protocol.
 
 Note: A differential drive robot has movement that is based
 on two separately driven wheels placed on either side of the robot. For 
 more information on differential drive robots, 
 <a href="http://en.wikipedia.org/wiki/Differential_wheeled_robot">check 
 out the wikipedia article.</a>
 */
@protocol DifferentialDriveProtocol <DriveProtocol>

/**
 A read-only object representing the left RMCoreMotor
 
 Read this property to access properties of the motor (e.g., power level, 
 current)
 */
@property (nonatomic, readonly) RMCoreMotor *leftDriveMotor;

/**
 A read-only object representing the right RMCoreMotor
 
 Read this property to access properties of the motor (e.g., power level,
 current)
 */
@property (nonatomic, readonly) RMCoreMotor *rightDriveMotor;

#pragma mark - Differential Drive Core Commands

/**
 Commands robot to drive with symmetric input power while attempting to
 to maintain initial heading.
 
 @param power Power value on the interval [-1.0, 1.0] (where -1.0 indicates
 backwards movement and 1.0 indicates forward movement).
 */
- (void)driveWithPower:(float)power;

/**
 Directly applies voltage to wheel motors propotional to the input power level
 provided.
 
 @param leftMotorPower A value on the interval [-1.0, 1.0] that drives the left 
 motor (-1.0 indicates fully backwards and 1.0 indicates fully forwards).
 
 @param rightMotorPower A value on the interval [-1.0, 1.0] that drives the 
 right motor (where -1.0 indicates fully backwards and 1.0 indicates fully 
 forwards).
 */
- (void)driveWithLeftMotorPower:(float)leftMotorPower
                rightMotorPower:(float)rightMotorPower;

@end
