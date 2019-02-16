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
//  HeadTiltProtocol.h
//  RMCore
//
//  Created by Romotive on 1/15/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
//==============================================================================
/** @file HeadTiltProtocol.h
 @brief Public header for defining the method of intera
 */
#import <Foundation/Foundation.h>
#import "RMCoreMotor.h"

/**
 NSNotification posted from a robot, when drive speed changes
 */
extern NSString *const RMCoreRobotHeadTiltSpeedDidChangeNotification;

/**
 @brief The protocol for directly interfacing with the up/down tilting degree 
 of freedom that controls the docked iDevice.
 
 This protocol provides methods for interacting with a robot containing a 
 tilting axis. When an RMCoreRobot object is instantiated (and when it 
 implements the HeadTiltProtocol), you may send the robot commands and query 
 the state of its head tilt through the functionality in this protocol.
 */
@protocol HeadTiltProtocol <NSObject>

/**
 Direct access to the RMCoreMotor object
 */
@property (nonatomic, readonly) RMCoreMotor *tiltMotor;

/**
 The current angle of the docked device (degrees)
 */
@property (nonatomic, readonly) double headAngle;

/**
 The farthest the head tilts forward (in degrees)
 
    70 degrees for ROMO3A
 */
@property (nonatomic, readonly) double minimumHeadTiltAngle;

/**
 The farthest the head tilts back (in degrees)
 
    130 degrees for ROMO3A
 */
@property (nonatomic, readonly) double maximumHeadTiltAngle;

/**
 Read-only property that indicates whether or not the robot head is currently
 tilting.
 */
@property (nonatomic, readonly, getter=isTilting) BOOL tilting;

/**
 Tilt the motor at a specified power
 
 @param motorPower Power value on the interval [-1.0, 1.0] (where -1.0 indicates
 upward gaze and 1.0 indicates downward gaze).
 */
- (void)tiltWithMotorPower:(float)motorPower;

/**
 Tilt the motor by a specified angle. This is relative to the current angle.
 
 @param angle The desired change in angle (degrees)
 @param completion Completion block with an indicator whether or not the robot 
 reached the desired angle
 */
- (void)tiltByAngle:(float)angle
         completion:(void (^)(BOOL success))completion;

/**
 Tilt the motor to a specific angle. This is absolute, and will be clamped
 on the range [minimumHeadTiltAngle, maximumHeadTiltAngle]
 
 @param angle The desired absolute position (degrees)
 @param completion Completion block with an indicator whether or not the robot
 reached the desired position
 */
- (void)tiltToAngle:(float)angle
         completion:(void (^)(BOOL success))completion;

/**
 Immediately halts the tilt motor
 */
- (void)stopTilting;

@end
