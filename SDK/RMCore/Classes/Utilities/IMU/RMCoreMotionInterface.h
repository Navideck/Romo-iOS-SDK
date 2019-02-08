//
//  RMCoreMotionAccessor.h
//  Romo3
//
//  Created on 12/7/12.
//  Copyright (c) 2012 Romotive Inc. All rights reserved.
//
// This class is used to access the iDevice's IMU (Intertial Measurement Unit)
// through Apple's CoreMotion framework.  The IMU consists of a three-axis
// accelerometer, three-axis gyroscope. The raw data from each of these sensors may be accessed
// directly or a conditioned form of the data may be accessed.  The conditioned
// data is the result of sensor fusion and/or filtering that is performed by the
// CoreMotion framework.  For example, the device's attitude is provided by
// filtering gyroscope and accelerometer data together.
//
// Data can be accessed manually via a polling technique or at regular intervals
// through a callback system.  If using the callback system the IMUDataUpdate
// protocol must be adopted so that the user of the class can be alerted each
// time new data is available.  Each time new data is available the relavent
// delegate method is provided with a timestamp of when the data was
// sampled. The frequency at which the sensors are updated (or at least the
// frequency at which the callback block is alerted) can be adjusted between 1
// and 100 Hz (maybe faster in future hardware) and is controlled through public
// properties.  When new data is available it is accessed through the public get
// methods.  Public methods are also provided for testing the device to see
// which IMU sensors are available and when they are active (have been enabled
// and are ready to provide data).

#import <Foundation/Foundation.h>
#import <CoreMotion/CoreMotion.h>
#import <RMShared/RMMath.h>

@class RMCoreMotionInterface;

typedef enum {
    RMCoreIMUAxisX, // notation, X, Y, and Z are standard Euclidean
    RMCoreIMUAxisY,
    RMCoreIMUAxisZ,
    RMCoreIMUAxisW, // W-axis is part of quaternion
} RMCoreIMUAxis;

typedef struct {
    CMAcceleration accelerometer;
    CMRotationRate gyroscope;
    
    CMAcceleration deviceAcceleration;
    CMAcceleration gravity;
    CMRotationRate rotationRate;
    CMQuaternion attitude;
} RMCoreIMUData;

#define DEFAULT_GLOBAL_IMU_FREQUENCY        20 // (Hz) Default IMU sampling frequency

@protocol IMUDataUpdate;

@interface RMCoreMotionInterface : NSObject

@property (nonatomic, weak) NSObject<IMUDataUpdate> *delegate;
@property (nonatomic) float accelerometerUpdatePeriod;      // time (s) between samples
@property (nonatomic) float gyroUpdatePeriod;               // of each IMU sub-sensor
@property (nonatomic) float deviceMotionUpdatePeriod;       //
@property (nonatomic, readonly) float globalUpdatePeriod;   // this value is set when all
// the IMU sub-sensors are set
// consistently

// enable IMU in either manually polling mode (user must request each sensor
// sample or in free-running mode (sensor continuously calls back at a fix
// sampling rate).  raw data come from the IMU's underlying sensors (gyro,
// accelerometer).  conditioned date is raw data that has
// been filtered and/or fused by DeviceMotion in order to make the IMU easier
// to use.
- (void)startIMURawFreeRunning;
- (void)startIMUConditionedFreeRunning;
- (void)startIMUConditionedFreeRunningUsingReferenceFrame:(CMAttitudeReferenceFrame)refFrame;

- (void)stopIMU;

// sampling rate control
- (void)applyIMUUpdatePeriods;                     // apply sampling rates

// data access methods
- (double)accelerationForAxis:(RMCoreIMUAxis)axis;           // get raw acceleration
- (double)angularRateInDegreesForAxis:(RMCoreIMUAxis)axis;          // get raw angular rate
- (double)angularRateInRadiansForAxis:(RMCoreIMUAxis)axis;
- (double)attitudeInDegreesForAxis:(RMCoreIMUAxis)axis;      // get device attitude in
- (double)attitudeInRadiansForAxis:(RMCoreIMUAxis)axis;      // one of a few formats
- (double)attitudeAsQuaternionForAxis:(RMCoreIMUAxis)axis;
- (CMQuaternion)attitude;
- (CMRotationMatrix)attitudeAsRotationMatrix;
- (double)gravityVectorForAxis:(RMCoreIMUAxis)axis;          // get gravity vector
- (double)userAccelerationVectorForAxis:(RMCoreIMUAxis)axis; // get acceleration vector
- (double)rotationRateInDegreesForAxis:(RMCoreIMUAxis)axis;  // get filtered angular rate
- (double)rotationRateInRadiansForAxis:(RMCoreIMUAxis)axis;

// hardware testing methods
- (BOOL)isAllRawSensorsActive;        // accel, gyro enabled?
- (BOOL)isAccelerometerAvailable;     // does iDevice have accelerometer?
- (BOOL)isAccelerometerActive;        // is acceleroeter enabled?
- (BOOL)isGyroAvailable;              // does iDevice have gyroscope?
- (BOOL)isGyroActive;                 // if gyroscope enabled?
- (BOOL)isDeviceMotionAvailable;      // does iDevice support conditioned data?
- (BOOL)isDeviceMotionActive;         // is conditioned data enabled

@end

@protocol IMUDataUpdate <NSObject>

// these functions will be called when a new data sample arrives, it is up
// to the user to retrieve the data before a new sample comes in (these are
// used when the IMU is being used in free-running mode, continuous update)
- (void)freshAccelerometerDataAlertAtTime:(NSNumber *)timestamp;
- (void)freshGyroDataAlertAtTime:(NSNumber *)timestamp;
- (void)freshDeviceMotionDataAlertAtTime:(NSNumber *)timestamp;

@end
