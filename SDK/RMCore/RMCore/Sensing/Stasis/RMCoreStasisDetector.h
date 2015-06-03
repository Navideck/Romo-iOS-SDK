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
//  RMCoreStasisDetector.h
//  RMCore
//
//  Created by Romotive on 10/03/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
//==============================================================================
/** @file RMCoreStasisDetector.h
 @brief Private header for fused stasis detection module.
 */

#import <Foundation/Foundation.h>
#import "RMCoreRobot.h"

/**
 @brief An RMCoreStasisDetector object fuses different stasis detector 
 sub-modules and provides a single stasis/no-stasis output
  */
@interface RMCoreStasisDetector : NSObject

@property (nonatomic, weak) RMCoreRobot <RobotMotionProtocol, DriveProtocol> *robot;

@end
