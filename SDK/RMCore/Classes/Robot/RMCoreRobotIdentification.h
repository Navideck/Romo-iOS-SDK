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
//  RMCoreRobotIdentification.h
//  RMCore
//
//  Created by Romotive on 4/16/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
//==============================================================================
/** @file RMCoreRobotIdentification.h
 @brief Public header for RMCoreRobotIdentification, which stores the robot's
 identification information, such as serial number.
 */
#import <Foundation/Foundation.h>

/**
 @brief An object that stores the robot's identification information, like 
 model number, serial number, firmware version, etc.
 */
@interface RMCoreRobotIdentification : NSObject
/**
 The robot's commercial name, e.g. Romo
 */
@property (nonatomic, readonly) NSString *name;

/**
 The robot product's model number, e.g. 3A
 */
@property (nonatomic, readonly) NSString *modelNumber;

/**
 The version number of the firmware running on the robot
 */
@property (nonatomic, readonly) NSString *firmwareVersion;

/**
 The version number of the robot's circuit board
 */
@property (nonatomic, readonly) NSString *hardwareVersion;

/**
 The version number of the robot's bootloader
 */
@property (nonatomic, readonly) NSString *bootloaderVersion;

/**
 The robot's unique serial number
 */
@property (nonatomic, readonly) NSString *serialNumber;

/**
 The name of the manufacturer of the primary hardware
 */
@property (nonatomic, readonly) NSString *manufacturer;

@end
