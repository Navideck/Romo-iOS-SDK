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
//  RobotMotionProtocol.h
//  RMCore
//
//  Created by Romotive on 4/3/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
//==============================================================================
/** @file RobotMotionProtocol.h
 @brief Public header defining protocol for working with the IMU.
*/

#import <Foundation/Foundation.h>
#import <CoreMotion/CoreMotion.h>

/**
 @struct RMCoreAttitude
 @brief This struct is used for storing a (roll, pitch, yaw) attitude triplet.
 */
typedef struct
{
    /** 
    Rotation about axis parallel to direction of forward motion (degrees).
     */
    float roll;
    /**
     Rotation about the axis normal to the direction of forward motion (degrees).
     */
     float pitch;
    /**
     Rotation about the axis normal to the ground (degrees).
     */
    float yaw;
} RMCoreAttitude;

/**
 The default frequency that the IMU will update, Hz
 */
#define RM_IMU_DEFAULT_UPDATE_FREQUENCY    20

/**
 The maximum frequency that the IMU will update, Hz
 Trying to set -robotMotionDataUpdateRate to higher frequencies will be capped here
 */
#define RM_IMU_MAX_UPDATE_FREQUENCY        60

/**
 The minumum frequency that the IMU will update, Hz
 Trying to set -robotMotionDataUpdateRate to lower frequencies will be capped here
 */
#define RM_IMU_MIN_UPDATE_FREQUENCY         1

/**
 @brief Protocol that provides access to the iDevice's IMU.  
 
 The protocol allows for starting and stopping the IMU, setting its update
 frequency, and accessings the data from the IMU as well as post-processed data
 that is based off IMU data.
 */
@protocol RobotMotionProtocol <NSObject>

#pragma mark RobotMotion Setup

/**
 Set to YES to start RobotMotion module
 If not explicitly changed, runs at RM_IMU_DEFAULT_UPDATE_FREQUENCY
 */
@property (nonatomic, getter=isRobotMotionEnabled) BOOL robotMotionEnabled;

/**
 Indicates if RobotMotion module is ready to be used.  If this flag returns NO
 then all requests for data from RobotMotion will return zero.
 */
@property (nonatomic, readonly, getter=isRobotMotionReady) BOOL robotMotionReady;

/**
 Set refresh rate of IMU (Hz).
 Defaults to RM_IMU_DEFAULT_UPDATE_FREQUENCY
 Clamped between RM_IMU_MIN_UPDATE_FREQUENCY and RM_IMU_MAX_UPDATE_FREQUENCY
 */
@property (nonatomic) float robotMotionDataUpdateRate;

#pragma mark - Platform Motion Setup/Data

/**
 @brief Sets the iDevice's current attitude as the reference attitude that is 
 used to determine the attitude of the mobility platform.
 
 It is intended that this reference is taken when the robot is situated on level 
 ground.  It should not be called before RobotMotionReady has been set to YES by 
 RMCore (automatically done internally).
 
 @return Returns YES if RobotMotion was ready and reference attitude was able to
 be set.  If NO is returned platformAttitude should _not_ be used.
 */
- (BOOL)takeDeviceReferenceAttitude;

/**
Yaw rate of the platform around the gravity vector.
*/
@property (nonatomic, readonly) float platformYawRate;

/**
 Platform acceleration along the direction of the gravity vector.
 */
@property (nonatomic, readonly) CMAcceleration platformAcceleration;

/**
 Attitude of the platform.  Accuracy is depenedent on the platform being on
 level ground when the reference was taken (via takeReferenceAttitude method).
 */
@property (nonatomic, readonly) RMCoreAttitude platformAttitude;

#pragma mark - Device Motion Data

/**
 iDevice's raw accelerometer data.
 */
@property (nonatomic) CMAcceleration deviceAccelerometer;

/**
 iDevice's raw gyroscope data.
 */
@property (nonatomic) CMRotationRate deviceGyroscope;

/**
 Acceleration of the iDevice (with gravity acceleration removed).
 */
@property (nonatomic) CMAcceleration deviceAcceleration;

/**
 Direction of the gravity vector.
 */
@property (nonatomic) CMAcceleration deviceGravity;

/**
 Angular rotation rate of the iDevice.
 */
@property (nonatomic) CMRotationRate deviceRotationRate;

/**
 iDevice's orienatation in space.
 */
@property (nonatomic) CMQuaternion deviceAttitude;

@end
