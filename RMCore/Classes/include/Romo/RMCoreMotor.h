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
//  RMCoreMotor.h
//  RMCore
//
//  Created by Romotive on 1/15/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
//==============================================================================
/** @file RMCoreMotor.h
 @brief Public header for defining the RMCoreMotor interface and the types of 
 logical axes for motors.
 */
#import <Foundation/Foundation.h>

/** A simple helper type for reasoning about different motor axes */
typedef uint8_t RMCoreMotorAxis;

/**
 @brief An RMCoreMotor object provides an interface to the internal state and 
 configuration of a motor.
 
 This interface is exclusively read-only properties that peek into a particular 
 motor's state, including:
    - Motor axis
    - PWM scalar
    - Power level
    - Current draw
 */
@interface RMCoreMotor : NSObject

/**
 The axis (RMCoreMotorAxis) that this motor is configured in
 */
@property (nonatomic, readonly) RMCoreMotorAxis motorAxis;

/**
 The PWM scalar of the motor (the maximum native integer value to send to 
 the motor)
 
    For ROMO3A, this is 255
 */
@property (nonatomic, readonly) unsigned int pwmScalar;

/**
 The power level of the motor (in the range [-1.0, 1.0])
 */
@property (nonatomic, readonly) float powerLevel;

/**
 Flag indicating whether a motor current reading is available to read
 */
@property (nonatomic, readonly) BOOL motorCurrentAvailable;

/**
 The current draw of the motor (in Amperes)
 
 Note: only read this after motorCurrentAvailable is YES
 */
@property (nonatomic, readonly) float motorCurrent;

@end
