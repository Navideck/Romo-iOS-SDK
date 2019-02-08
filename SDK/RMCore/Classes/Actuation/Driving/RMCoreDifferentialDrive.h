//
//  RMCoreDifferentialDrive.h
//  Romo3
//
// RMCoreDifferentialDrive provides the most fundamental high-level commands
// needed to control the mobility of a differential drive robot.  Even
// higher-level, more abstact commands may be available at a level above this
// module.
//

#import <Foundation/Foundation.h>
#import "RMCoreRobot.h"
#import "RMCoreRobot_Internal.h"
#import "DifferentialDriveProtocol.h"
#import "RobotMotionProtocol.h"

#pragma mark - System Paramaters

// robot heading ("absolute" yaw angle) controller parameters
#define HEADING_CONTROLLER_P            .61  // default proportional gain
#define HEADING_CONTROLLER_I            0.   // default integral gain
#define HEADING_CONTROLLER_D            .19  // default derivative gain
#define HEADING_CONTROLLER_FREQUENCY    20   // controller's frequency
#define IMU_SETTLE_TIME                 .200 // (s)
#define STRAIGHT_DRIVE_TOLERANCE        1    // degrees, with +/- robot is
                                             // considered on-heading

// robot yaw-rate controller parameters
#define RADIUS_CONTROLLER_P             .20  // default proportional gain
#define RADIUS_CONTROLLER_I             0.12 // default integral gain
#define RADIUS_CONTROLLER_D             0.003// default derivative gain
#define RADIUS_CONTROLLER_FREQUENCY     20   // controller's frequency

// turn-to controller paramters
#define TURN_TO_CONTROLLER_FREQUENCY    20   // controller's frequency

#pragma mark - RMCoreDifferentialDrive

@interface RMCoreDifferentialDrive : NSObject

@property (nonatomic, weak) RMCoreRobot<DifferentialDriveProtocol,
                                        RobotMotionProtocol> *robot;
@property (nonatomic) float wheelSpacing;
@property (nonatomic, readonly, getter=isDriving) BOOL driving;

#pragma mark - Core Differential Drive Methods

/**
 * Commands robot to drive with the input speed (m/s) on an arc of the input
 * radius (m).  Providing RM_DRIVE_RADIUS_STRAIGHT macro as input radius will cause
 * robot to drive straight and actively hold its heading.
 *  Values are on the interval [-inf, inf].
 *  Negative speeds cause robot to drive backwards.
 *  Positive radii cause robot to arc counter-clocwise when robot is driving
 *  forwards.
 *  Radius = 0 causes robot to turn-in-place (or use RM_DRIVE_RADIUS_TURN_IN_PLACE)
 *
 *  Note: Due to hardware limitations the robot's actual speed and radius
 *        will vary.
 */
- (void)driveWithRadius:(float)radius speed:(float)speed;

// See DriveProtocol.h for definitions
- (void)turnToHeading:(float)targetHeading
           withRadius:(float)radius
                speed:(float)speed
    forceShortestTurn:(BOOL)forceShortestTurn
      finishingAction:(RMCoreTurnFinishingAction)finishingAction
           completion:(RMCoreTurncompletion)completion;

// See DriveProtocol.h for definitions
- (void)turnToHeading:(float)targetHeading
           withRadius:(float)radius
      finishingAction:(RMCoreTurnFinishingAction)finishingAction
           completion:(RMCoreTurncompletion)completion;

// See DriveProtocol.h for definitions
- (void)turnByAngle:(float)angle
         withRadius:(float)radius
              speed:(float)speed
    finishingAction:(RMCoreTurnFinishingAction)finishingAction
         completion:(RMCoreTurncompletion)completion;

// See DriveProtocol.h for definitions
- (void)turnByAngle:(float)angle
         withRadius:(float)radius
    finishingAction:(RMCoreTurnFinishingAction)finishingAction
         completion:(RMCoreTurncompletion)completion;

/**
 * Commands robot to drive with the input power and while maintaining its
 * heading.
 *  Power value on the interval [-1.,1.] (-1. = max backward power)
 */
- (void)driveWithHeading:(float)heading power:(float)power;

/**
 * Commands robot to drive with the input speed (m/s) to given heading (and
 * then continue on that heading)
 *  Power value on the interval [-inf.,inf.] (negative speeds drive backwards)
 *
 *  Note: Due to hardware limitations the robot's actual speed will vary.
 */
- (void)driveWithHeading:(float)heading speed:(float)speed;

/**
 * Directly applies voltage to wheel motors propotional to input power level
 * provided.
 *  Values are on the interval [-1.,1.] (-1.= power backwards).
 */
- (void)driveWithLeftMotorPower:(float)leftMotorPower
                rightMotorPower:(float)rightMotorPower;

/**
 * Commands robot to drive with symmetric input power while attempting to
 * to maintain initial heading.
 *  Power value on the interval [-1., 1.]
 */
- (void)driveWithPower:(float)power;

@end
