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
//  RMCoreRobot.h
//  RMCore
//
//  Created by Romotive on 1/15/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
//==============================================================================
/** @file RMCoreRobot.h
 @brief Public header defining RMCoreRobot
 */
#import <Foundation/Foundation.h>
#import "DriveProtocol.h"
#import "HeadTiltProtocol.h"
#import "LEDProtocol.h"
#import "RobotMotionProtocol.h"
#import "RMCoreRobotIdentification.h"
#import "RMCoreRobotVitals.h"

/**
 @brief An RMCoreRobot object is a generic representation of a robot. It 
 contains the robot's vitals and properties about the robot (whether it's 
 connected, what type of commands it will respond to). A specific robot 
 implementation will be a subclass of RMCoreRobot (e.g., RMCoreRobotRomo3).
 */
@interface RMCoreRobot : NSObject

/**
 The identification object containing the robot's hardware identification information.
 */
@property (nonatomic, readonly) RMCoreRobotIdentification *identification;

/**
 The vitals object containing the robot's internal state (e.g., battery level,
 charging state).
 */
@property (nonatomic, readonly) RMCoreRobotVitals *vitals;

/**
 Read-only property indicating whether the RMCoreRobot is connected.
 */
@property (nonatomic, readonly, getter=isConnected) BOOL connected;

/**
  Read-only property indicating whether the RMCoreRobot is drivable.
 */
@property (nonatomic, readonly, getter=isDrivable) BOOL drivable;

/**
 Read-only property indicating whether the RMCoreRobot has a head tilt.
 */
@property (nonatomic, readonly, getter=isHeadTiltable) BOOL headTiltable;

/**
 Read-only property indicating whether the RMCoreRobot has LED capabilities.
 */
@property (nonatomic, readonly, getter=isLEDEquipped) BOOL LEDEquipped;

/**
 Read-only property indicating whether the RMCoreRobot has IMU capabilities.
 */
@property (nonatomic, readonly, getter=isIMUEquipped) BOOL IMUEquipped;

/**
 Immediately stops all motion of every motor.
 */
- (void)stopAllMotion;

@end

