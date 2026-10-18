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
//  LEDProtocol.h
//  RMCore
//
//  Created by Romotive on 1/15/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
//==============================================================================
/** @file LEDProtocol.h
 @brief Public header describing the LEDProtocol
 */
#import <Foundation/Foundation.h>
#import "RMCoreLEDs.h"

/**
 @brief Protocol that provides access to the robot's RMCoreLEDs
 
 This protocol simply gives access to a read-only instance of RMCoreLEDs, the 
 direct interface to controlling the LEDs on an RMCoreRobot. Note that although 
 this instance is read-only, its members are accessed directly to control
 the LED.
 */
@protocol LEDProtocol <NSObject>

/**
 Read-only property for getting the RMCoreLEDs object
 */
@property (nonatomic, readonly) RMCoreLEDs *LEDs;

@end
