//
//  RMTrainingRuntimeRobotController.h
//  Romo
//

#import <UIKit/UIKit.h>
#import "RMActivityRobotController.h"

@class RMMission;
@class RMCharacter;
@class RMCoreRobotRomo3;

@protocol RMRuntimeRobotControllerDelegate;

@interface RMRuntimeRobotController : RMActivityRobotController

@property (nonatomic, weak) id<RMRuntimeRobotControllerDelegate, RMActivityRobotControllerDelegate> delegate;

/** The mission to be ran */
@property (nonatomic, strong) RMMission *mission;

@end

@protocol RMRuntimeRobotControllerDelegate <NSObject>

/**
 Called once every method has been ran at least once. 
 Execution of the mission hasn't necessarily finished, but all events have been fully ran.
 */
- (void)runtimeFinishedRunningAllScripts:(RMRuntimeRobotController *)runtime;

/** 
 If the mission is time-based, let our delegate know when that time has passed
 */
- (void)runtimeDidTimeout:(RMRuntimeRobotController *)runtime;

/**
 Passes robot disconnects that occur during runtime to the delegate
 */
- (void)runtimeDisconnectedFromRobot:(RMRuntimeRobotController *)runtime;

/**
 Passes flips that occur during runtime to the delegate
 */
- (void)runtime:(RMRuntimeRobotController *)runtime robotDidFlipToOrientation:(RMRobotOrientation)orientation;

- (void)runtimeDidEnterBackground:(RMRuntimeRobotController *)runtime;

@end