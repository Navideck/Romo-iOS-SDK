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
//  RMCore.h
//  RMCore
//
//  Created by Romotive on 1/15/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
//==============================================================================
/** @file RMCore.h
 @brief Public header for creating and interfacing with an RMCore object.
 
 Contains a simple RMCore interface for connecting and disconnecting to robots,
 as well as an RMCoreDelegate protocol for receiving events about state changes 
 in connectivity.
 */
#import <Foundation/Foundation.h>

#import "DriveProtocol.h"
#import "DifferentialDriveProtocol.h"
#import "HeadTiltProtocol.h"
#import "LEDProtocol.h"
#import "RobotMotionProtocol.h"
#import "RMCoreLEDs.h"
#import "RMCoreMotor.h"
#import "RMCoreRobot.h"
#import "RMCoreRobotRomo3.h"
#import "RMCoreRobotVitals.h"
#import "RMCoreRobotIdentification.h"
#import "RMCoreControllerPID.h"

@protocol RMCoreDelegate;

/**
 @brief RMCore is the public interface for connecting to Romotive robots.
 
 By implementing the RMCoreDelegate protocol and setting the RMCore delegate 
 to the appropriate class, messages are received regarding connection 
 and disconnection events.
 */
@interface RMCore : NSObject

/**
 The delegate to which RMCore will send all events regarding robot 
 connection and disconnection.
 */
+ (void)setDelegate:(id<RMCoreDelegate>)delegate;

/**
 A method for getting the delegate.
 
 @return RMCore's class-level delegate.
 */
+ (id<RMCoreDelegate>)delegate;

/**
 A method for getting a list of the currently connected robots.
 
 @return An array of the currently connected robots.
 */
+ (NSArray *)connectedRobots;

/**
 To be used exclusively for development. It simulates the connection of a
 Romo3 robot, and immediately notifies RMCore's delegate and posts a notification.
 */
+ (void)connectToSimulatedRobot;
+ (void)disconnectFromSimulatedRobot;

@end

/**
 @brief A protocol for receiving messages from an RMCore object.
 
 This protocol handles receiving all messages from RMCore. Currently includes 
 connection to robots and disconnection from robots.
 */
@protocol RMCoreDelegate <NSObject>

/**
 Delegate method that is triggered when the iDevice is connected to a robot.
 */
- (void)robotDidConnect:(RMCoreRobot *)robot;

/**
 Delegate method that is triggered when the iDevice is disconnected from a 
 robot.
 */
- (void)robotDidDisconnect:(RMCoreRobot *)robot;

@end

/**
 NSNotification posted from a robot, when the robot disconnects.
 */
extern NSString *const RMCoreRobotDidConnectNotification;

/**
 NSNotification posted from a robot, when the robot disconnects.
 */
extern NSString *const RMCoreRobotDidDisconnectNotification;
