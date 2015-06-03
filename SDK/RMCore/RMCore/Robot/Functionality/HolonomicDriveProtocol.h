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
//  HolonomicDriveProtocol.h
//  RMCore
//
//  Created by Romotive on 4/6/2013.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
//==============================================================================
/** @file HolonomicDriveProtocol.h
 @brief Public header defining a protocol for controlling Holonomic (omni) Drive
 robots within the RMCore framework.
 
 Contains a protocol for driving with a specific x velocity, y velocity, and theta 
 angular velocity.
 */

#import <Foundation/Foundation.h>
#import "DriveProtocol.h"
#import "RMCoreMotor.h"

/**
 Twist structure for defining speeds in X, Y, and Theta.
 */
typedef struct {
    float xSpeed;
    float ySpeed;
    float thetaSpeed;
} Twist;

@protocol HolonomicDriveProtocol <DriveProtocol>

/**
 A read-only object representing the front left RMCoreMotor
 
 Read this property to access properties of the motor (e.g., power level,
 current)
 */
@property (nonatomic, readonly) RMCoreMotor *frontLeftDriveMotor;

/**
 A read-only object representing the front right RMCoreMotor
 
 Read this property to access properties of the motor (e.g., power level,
 current)
 */
@property (nonatomic, readonly) RMCoreMotor *frontRightDriveMotor;

/**
 A read-only object representing the rear left RMCoreMotor
 
 Read this property to access properties of the motor (e.g., power level,
 current)
 */
@property (nonatomic, readonly) RMCoreMotor *rearLeftDriveMotor;

/**
 A read-only object representing the rear right RMCoreMotor
 
 Read this property to access properties of the motor (e.g., power level,
 current)
 */
@property (nonatomic, readonly) RMCoreMotor *rearRightDriveMotor;

/**
 Drive with the specified Twist (x, y, and theta speeds).
*/
- (void)driveWithTwist:(Twist)twist;

@end
