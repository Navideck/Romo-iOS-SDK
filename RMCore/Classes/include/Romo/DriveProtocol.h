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
//  DriveProtocol.h
//  RMCore
//
//  Created by Romotive on 1/15/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
//==============================================================================
/** @file DriveProtocol.h
 @brief Public header for defining the DriveProtocol, along with a few helpful
 macros.
 */
#import <Foundation/Foundation.h>
#import <CoreMotion/CMAttitude.h>

#pragma mark - Types

/**
 The items in this enumeration are used to keep track of the current command
 drive action
 */
typedef enum {
    RMCoreDriveCommandStop        = 0,
    RMCoreDriveCommandForward     = 1,
    RMCoreDriveCommandBackward    = 2,
    RMCoreDriveCommandWithPower   = 3,
    RMCoreDriveCommandWithHeading = 4,
    RMCoreDriveCommandWithRadius  = 5,
    RMCoreDriveCommandTurn        = 6
} RMCoreDriveCommand;

/**
 The items in this enumeration signal the drive module what it should do after
 the target heading has been reached at the end of a turn-to heading command.
 */
typedef enum {
    RMCoreTurnFinishingActionStopDriving   = 0,
    RMCoreTurnFinishingActionDriveForward  = 1,
    RMCoreTurnFinishingActionDriveBackward = 2
} RMCoreTurnFinishingAction;

/**
 Block that is intended to be used as callback when the robot has completed a
 command that involved moving to a certain heading (orientation).

 @param success Whether the robot successfully executed the turn command
 (NO if the turn was aborted).
 
 @param heading The heading the robot actually ended up at when the turn
 completed.
 */
typedef void (^RMCoreTurncompletion)(BOOL success, float heading);

#pragma mark - Special Drive Constants

/** Macro defining the radius of infinity */
#define RM_DRIVE_RADIUS_STRAIGHT 9999

/** Macro for defining the radius to turn in place */
#define RM_DRIVE_RADIUS_TURN_IN_PLACE 0

/** Macro that defines a speed value indicating the robot cannot determine its
 speed */
#define RM_DRIVE_SPEED_UNKNOWN 9999

/** Macro that defines the maximum and minimum robot headings (degrees) */
#define RM_MAX_HEADING 180
#define RM_MIN_HEADING -180

/**
 NSNotification posted from a robot, when drive speed changes
 */
extern NSString *const RMCoreRobotDriveSpeedDidChangeNotification;

/**
 @brief The protocol for directly interfacing with the high-level motions
 of a driveable robot.

 When an RMCoreRobot object is instantiated (and when it implements
 DriveProtocol), you may send the robot drive commands and query its state
 based on the methods contained in this protocol.
 */
@protocol DriveProtocol <NSObject>

/**
 Read-only property that indicates whether or not the robot is currently
 driving.
 */
@property (nonatomic, readonly, getter=isDriving) BOOL driving;

/**
 Read-only property that indicates the speed that the robot is instructed
 to drive at. If the speed is unknown, RM_DRIVE_SPEED_UNKNOWN is returned.
 (An example is when low-level commands are issued that don't necessarily
 correspond to a high-level speed)
 */
@property (nonatomic, readonly) float speed;

/**
 Read-only property that indicates what the most recent drive command issued
 is.
 */
@property (nonatomic, readonly) RMCoreDriveCommand driveCommand;

#pragma mark - Driving Straight

/**
 Commands robot to drive forward with input speed (meters / second) while
 attempting to maintain initial heading.

 @param speed Speed value (in m/s) on the interval [0, inf]
 */
- (void)driveForwardWithSpeed:(float)speed;

/**
 Commands robot to drive backwards with input speed (m/s)while attempting to
 to maintain initial heading.

 @param speed Speed value (in m/s) on the interval [0, inf]
 */
- (void)driveBackwardWithSpeed:(float)speed;

#pragma mark - Stop Driving

/**
 Immediately commands the robot to stop driving
 */
- (void)stopDriving;

#pragma mark - Turning

/**
 Commands robot to drive with the input speed (m/s) on an arc of the input
 radius (m).

 Note: Due to hardware limitations the robot's actual speed and radius
 will vary.

 @param radius The radius at which the robot should turn, on the interval
 [-Inf, Inf]
     - RM_DRIVE_RADIUS_TURN_IN_PLACE causes robot to turn-in-place.
     - RM_DRIVE_RADIUS_STRAIGHT causes robot to drive straight and actively
     hold its heading.
     - Positive radii cause robot to arc counter-clocwise when robot is
     driving forwards.

 @param speed How fast the robot should move in meters / second. Negative
 speeds cause the robot to drive backwards.
 */
- (void)driveWithRadius:(float)radius
                  speed:(float)speed;

/**
 Commands robot to drive until it rotates through the given angle.  Robot will
 drive with the specified radius.  The optimal speed and direction is
 automatically calculated such that the turn completes as fast as possible with
 minimal risk of overshooting the target heading. Stops the robot when finished.

 @param angle The angle (in degrees) that is to be turned through [-180, 180]
 - Positive angles correspond to the robot turning counter-clocwise.

 @param radius The radius at which the robot should drive, on the interval
 ~[-.75, .75]
 - RM_DRIVE_RADIUS_TURN_IN_PLACE causes robot to turn-in-place.

 @param completion Optional callback when target heading is reached or turn is 
 aborted.
 */

- (void)turnByAngle:(float)angle
         withRadius:(float)radius
         completion:(RMCoreTurncompletion)completion;

/**
 Commands robot to drive until it rotates through the given angle.  Robot will
 drive with the specified radius.  The optimal speed and direction is
 automatically calculated such that the turn completes as fast as possible with
 minimal risk of overshooting the target heading.

 @param angle The angle (in degrees) that is to be turned through [-180, 180]
 - Positive angles correspond to the robot turning counter-clocwise.

 @param radius The radius at which the robot should drive, on the interval
 ~[-.75, .75]
 - RM_DRIVE_RADIUS_TURN_IN_PLACE causes robot to turn-in-place.

 @param finishingAction Dictates what should happen immediately after the target
 heading is reached (e.g. continue driving straight on target heading)

 @param completion Optional callback when target heading is reached or turn is 
 aborted.
 */

- (void)turnByAngle:(float)angle
         withRadius:(float)radius
    finishingAction:(RMCoreTurnFinishingAction)finishingAction
         completion:(RMCoreTurncompletion)completion;

/**
 Commands robot to drive until it rotates through the given angle.  Robot will
 drive with the specified radius and speed.  The direction is dictated by the
 sign of the angle (where positive angles cause counter-clockwise rotation).

 @param angle The angle (in degrees) that is to be turned through [-180, 180]
 - Positive angles correspond to the robot turning counter-clocwise.

 @param radius The radius at which the robot should drive, on the interval
 ~[-.75, .75]
 - RM_DRIVE_RADIUS_TURN_IN_PLACE causes robot to turn-in-place.
 - Positive radii cause robot to arc counter-clocwise when robot is driving
 forwards

 @param speed How fast the robot should move in meters / second. Negative
 speeds cause the robot to drive backwards.

 @param finishingAction Dictates what should happen immediately after the target
 heading is reached (e.g. continue driving straight on target heading)

 @param completion Optional callback when target heading is reached or turn is 
 aborted.
 */
- (void)turnByAngle:(float)angle
         withRadius:(float)radius
              speed:(float)speed
    finishingAction:(RMCoreTurnFinishingAction)finishingAction
         completion:(RMCoreTurncompletion)completion;

/**
 Commands robot to drive until it reaches the target heading.  Robot will drive
 with the specified radius.  The optimal speed and direction is automatically
 calculated such that the turn completes as fast as possible with minimal risk
 of overshooting the target heading.

 @param targetHeading The absolute heading (in degrees) that is the target 
 [-180, 180]

 @param radius The radius at which the robot should drive, on the interval
 ~[-.75, .75]
 - RM_DRIVE_RADIUS_TURN_IN_PLACE causes robot to turn-in-place.

 @param finishingAction Dictates what should happen immediately after the target
 heading is reached (e.g. continue driving straight on target heading)

 @param completion Optional callback when target heading is reached or turn is 
 aborted.
 */
- (void)turnToHeading:(float)targetHeading
           withRadius:(float)radius
      finishingAction:(RMCoreTurnFinishingAction)finishingAction
           completion:(RMCoreTurncompletion)completion;

/**
 Commands robot to drive until it reaches the target heading.  Robot will drive
 with the specified radius and speed.

 @param targetHeading The absolute heading (in degrees) that is the target 
 [-180, 180]

 @param radius The radius at which the robot should drive, on the interval
 [-Inf, Inf]
     - RM_DRIVE_RADIUS_TURN_IN_PLACE causes robot to turn-in-place.
     - Positive radii cause robot to arc counter-clocwise when robot is driving
     forwards, unless forceTurnDirection is YES

 @param speed How fast the robot should move in meters / second. Negative
 speeds cause the robot to drive backwards.

 @param forceShortestTurn A flag indicating if the sign of the radius/speed
 should determine the direction to turn, or if the shortest turn direction
 should be used.

 @param finishingAction Dictates what should happen immediately after the target
 heading is reached (e.g. continue driving straight on target heading)

 @param completion Optional callback when target heading is reached or turn is 
 aborted.
 */
- (void)turnToHeading:(float)targetHeading
           withRadius:(float)radius
                speed:(float)speed
    forceShortestTurn:(BOOL)forceShortestTurn
      finishingAction:(RMCoreTurnFinishingAction)finishingAction
           completion:(RMCoreTurncompletion)completion;

@end
