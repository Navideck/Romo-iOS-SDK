//
//  RMCoreMotionInterface.m
//  Romo3
//

#import "RMCoreMotionInterface.h"

#pragma mark Private Properties/Methods

@interface RMCoreMotionInterface()

@property (nonatomic, strong) CMMotionManager *IMUManager;

/**
 used for callback blocks when using IMU is in free-running sampling mode
 */
@property (nonatomic, strong) NSOperationQueue *IMUDataSamplingQueue;

// raw accelerometer, gyro data
@property (atomic, strong) CMAccelerometerData *rawAccelerometerData;
@property (atomic, strong) CMGyroData *rawGyroData;

// conditioned (sensor-fused and/or filtered) iDevice attitude,
// acceleration, and angular rotation rate, and gravity vectors
@property (atomic) CMAcceleration userAccelerationVector;
@property (atomic) CMAcceleration gravityAccelerationVector;
@property (atomic) CMAttitude *deviceAttitude;
@property (atomic) CMRotationRate deviceRotationRate;

@property (nonatomic, readwrite) float globalUpdatePeriod;

- (double) getGyroAxis:(RMCoreIMUAxis)axis;              // access particular axis
- (double) getRotationRateAxis:(RMCoreIMUAxis)axis;      // of raw gyro, filtered
- (double) getAttitudeAxis:(RMCoreIMUAxis)axis;          // rotation rate, or device attitude data

@end

@implementation RMCoreMotionInterface

- (id)init
{
    self = [super init];
    if (self) {
        _IMUDataSamplingQueue = [[NSOperationQueue alloc] init];
        _IMUDataSamplingQueue.name = @"com.Romotive.IMU-Sampling";
        
        _globalUpdatePeriod =  1.0 / DEFAULT_GLOBAL_IMU_FREQUENCY;
        _accelerometerUpdatePeriod = self.globalUpdatePeriod;
        _gyroUpdatePeriod = self.globalUpdatePeriod;
        _deviceMotionUpdatePeriod = self.globalUpdatePeriod;
    }
    return self;
}

- (void)dealloc
{
    [self stopIMU];
}

#pragma mark IMU Control Methods

// Enable IMU in free-running mode for raw sensor data access
- (void) startIMURawFreeRunning
{
    // make sure the sensor sampling frequencies have been updated
    [self applyIMUUpdatePeriods];
    
    // enabled Accelerometer if hardware is available
    if (self.isAccelerometerAvailable) {
        __weak RMCoreMotionInterface *weakSelf = self;
        [self.IMUManager startAccelerometerUpdatesToQueue:self.IMUDataSamplingQueue
                                              withHandler:^(CMAccelerometerData *data, NSError *error) {
                                                  if (!error && data) {
                                                      weakSelf.rawAccelerometerData = data;
                                                      [weakSelf.delegate freshAccelerometerDataAlertAtTime:@(data.timestamp)];
                                                  }
                                              }];
    }
    
    // enabled Gyro if hardware is available
    if (self.isGyroAvailable) {
        __weak RMCoreMotionInterface *weakSelf = self;
        [self.IMUManager startGyroUpdatesToQueue:self.IMUDataSamplingQueue
                                     withHandler:^(CMGyroData *data, NSError *error) {
                                         if (!error && data) {
                                             weakSelf.rawGyroData = data;
                                             [weakSelf.delegate freshGyroDataAlertAtTime:@(data.timestamp)];
                                         }
                                     }];
    }
}

// Enable IMU in free-running mode for fused/filtered sensor data access
// (without an absolute frame of reference)
- (void) startIMUConditionedFreeRunning
{
    // I believe this is the default reference frame which is used if
    // startDeviceMotionUpdates:toQueue: withHandler: were called
    [self startIMUConditionedFreeRunningUsingReferenceFrame:CMAttitudeReferenceFrameXArbitraryZVertical];
}

// This method does the actual business of enabling the IMU (via one of the
// above mehtods)
- (void) startIMUConditionedFreeRunningUsingReferenceFrame:(CMAttitudeReferenceFrame)refFrame
{
    // apply rate of callback to data handler
    [self applyIMUUpdatePeriods];
    
    __weak RMCoreMotionInterface *weakSelf = self;
    
    // this updates device attitude (roll, pitch, yaw), gravity vector, and user
    // acceleration vector (total acceleration minus gravity), rotation rate
    [self.IMUManager startDeviceMotionUpdatesUsingReferenceFrame:refFrame
                                                         toQueue:self.IMUDataSamplingQueue
                                                     withHandler:^(CMDeviceMotion *data, NSError *error) {
                                                         if (!error && data) {
                                                             weakSelf.deviceAttitude = data.attitude;
                                                             weakSelf.gravityAccelerationVector = data.gravity;
                                                             weakSelf.userAccelerationVector = data.userAcceleration;
                                                             weakSelf.deviceRotationRate = data.rotationRate;
                                                             
                                                             // notify the delegate that there's new data
                                                             [weakSelf.delegate freshDeviceMotionDataAlertAtTime:@(data.timestamp)];
                                                         }
                                                     }];
}

// Disabled the IMU
- (void)stopIMU
{
    if (_IMUManager) {
        [self.IMUManager stopAccelerometerUpdates];
        [self.IMUManager stopGyroUpdates];
        [self.IMUManager stopDeviceMotionUpdates];
        self.IMUManager = nil;
    }
}

// This method applies the sampling frequency changes (after loading the desired
// values for accelerometerUpdatePeriod, gyroUpdatePeriod, etc.)
- (void) applyIMUUpdatePeriods
{
    // apply store sampling periods
    self.IMUManager.accelerometerUpdateInterval =self.accelerometerUpdatePeriod;
    self.IMUManager.gyroUpdateInterval = self.gyroUpdatePeriod;
    self.IMUManager.deviceMotionUpdateInterval = self.deviceMotionUpdatePeriod;
    
    // if underlying IMU sensor periods are the same then set the global period
    if (self.accelerometerUpdatePeriod == self.gyroUpdatePeriod &&
        self.gyroUpdatePeriod == self.deviceMotionUpdatePeriod)
    {
        _globalUpdatePeriod = self.accelerometerUpdatePeriod;
    }
    // otherwise indicate that their is no consistent sampling rate
    else
    {
        _globalUpdatePeriod = 0;
    }
}

#pragma mark Data Getter Methods

// Access the given component (X, Y, Z) of the raw acceleration vector
// (includes device's acceleration as well as the acceleration caused by
// gravity)
- (double)accelerationForAxis:(RMCoreIMUAxis)axis
{
    double acceleration = 0;
    
    switch(axis) {
        case RMCoreIMUAxisX:
            // select axis...
            acceleration = self.rawAccelerometerData.acceleration.x;
            break;
        case RMCoreIMUAxisY:
            acceleration = self.rawAccelerometerData.acceleration.y;
            break;
        case RMCoreIMUAxisZ:
            acceleration = self.rawAccelerometerData.acceleration.z;
            break;
        default:
            break;
    }
    return acceleration;
}

// Access gyro data (raw angular rate) about the given axis (X, Y, Z)
// in units of radians.
- (double) angularRateInRadiansForAxis:(RMCoreIMUAxis)axis
{
    // straight call to root method provides radians
    return [self getGyroAxis: axis];
}

// Access gyro data (raw angular rate) about the given axis (X, Y, Z)
// in units of degrees.
- (double) angularRateInDegreesForAxis:(RMCoreIMUAxis)axis
{
    // call root method and convert units
    return RAD2DEG([self getGyroAxis:axis]);
}

// PRIVATE: Access most recent sample of raw gyro data for the given axis
// (X, Y, Z).  This method is used by the corresponding public methods which
// return data in specific units.
- (double) getGyroAxis: (RMCoreIMUAxis)axis
{
    double angularRate = 0;
    
    // select axis...
    switch(axis)
    {
            // ...and grab data
        case RMCoreIMUAxisX:
            angularRate = self.rawGyroData.rotationRate.x;
            break;
        case RMCoreIMUAxisY:
            angularRate = self.rawGyroData.rotationRate.y;
            break;
        case RMCoreIMUAxisZ:
            angularRate = self.rawGyroData.rotationRate.z;
            break;
        default:
            break;
    }
    
    return angularRate;
}

// Access attitude data (orientation in space) about the given axis (X, Y, Z)
// in units of radians
- (double) attitudeInRadiansForAxis: (RMCoreIMUAxis)axis
{
    // straight call to root method provides radians
    return [self getAttitudeAxis: axis];
}

// Access attitude data (orientation in space) about the given axis (X, Y, Z)
// in units of degrees
- (double) attitudeInDegreesForAxis: (RMCoreIMUAxis)axis
{
    // call root method and convert units
    return RAD2DEG([self getAttitudeAxis: axis]);
}

// PRIVATE: Access most recent sample of attitude data (device's orientation in
// space) for the given axis (X, Y, Z). This method is used by the corresponding
// public methods which return data in specific units.
- (double) getAttitudeAxis: (RMCoreIMUAxis)axis
{
    double angle = 0;
    
    // select axis...
    switch(axis)
    {
            // ...and grab data
        case RMCoreIMUAxisX:
            angle = self.deviceAttitude.pitch;
            break;
        case RMCoreIMUAxisY:
            angle = self.deviceAttitude.roll;
            break;
        case RMCoreIMUAxisZ:
            angle = self.deviceAttitude.yaw;
            break;
        default:
            break;
    }
    
    return angle;
}

// Access iDevice's attitude data (orientation in space) about the given axis
// (X, Y, Z, W) in quaternion form (http://en.wikipedia.org/wiki/Quaternion)
- (double) attitudeAsQuaternionForAxis: (RMCoreIMUAxis)axis;
{
    double quaternion = 0;
    
    // select axis...
    switch(axis)
    {
            // ...and grab data
        case RMCoreIMUAxisX:
            quaternion = self.deviceAttitude.quaternion.x;
            break;
        case RMCoreIMUAxisY:
            quaternion = self.deviceAttitude.quaternion.y;
            break;
        case RMCoreIMUAxisZ:
            quaternion = self.deviceAttitude.quaternion.z;
            break;
        case RMCoreIMUAxisW:
            quaternion = self.deviceAttitude.quaternion.w;
            break;
    }
    
    return quaternion;
}

// Access iDevice's attiude data (orientation in space) in quaternion form
- (CMQuaternion) attitude
{
    return self.deviceAttitude.quaternion;
}

// Access iDevice's attitude (orientation in space) data in matrix form.
- (CMRotationMatrix) attitudeAsRotationMatrix;
{
    return self.deviceAttitude.rotationMatrix;
}

// Access the given component (X, Y, Z) of the gravity vector
- (double) gravityVectorForAxis: (RMCoreIMUAxis)axis
{
    double gravity = 0;
    
    // select axis...
    switch(axis)
    {
            // ...and grab data
        case RMCoreIMUAxisX:
            gravity = self.gravityAccelerationVector.x;
            break;
        case RMCoreIMUAxisY:
            gravity = self.gravityAccelerationVector.y;
            break;
        case RMCoreIMUAxisZ:
            gravity = self.gravityAccelerationVector.z;
            break;
        default:
            break;
    }
    
    return gravity;
}

// Access the given component (X, Y, Z) of the iDevice's acceleration vector
// (with gravity removed)
- (double)userAccelerationVectorForAxis:(RMCoreIMUAxis)axis
{
    double acceleration = 0;
    
    // select axis...
    switch(axis) {
            // ...and grab data
        case RMCoreIMUAxisX:
            acceleration = self.userAccelerationVector.x;
            break;
        case RMCoreIMUAxisY:
            acceleration = self.userAccelerationVector.y;
            break;
        case RMCoreIMUAxisZ:
            acceleration = self.userAccelerationVector.z;
            break;
        default:
            break;
    }
    
    return acceleration;
}

// Access rotation rate data (filtered) about the given axis (X, Y, Z) in units
// of radians
- (double) rotationRateInRadiansForAxis:(RMCoreIMUAxis)axis
{
    // straight call to root method provides radians
    return [self getRotationRateAxis: axis];
}

// Access rotation rate data (filtered) about the given axis (X, Y, Z) in units
// of degrees
- (double) rotationRateInDegreesForAxis:(RMCoreIMUAxis)axis
{
    // call root method and convert units
    return RAD2DEG([self getRotationRateAxis: axis]);
}

// PRIVATE: Access most recent sample of angular rate data for the given axis
// (X, Y, Z). This method is used by the corresponding public methods which
// return data in specific units.
- (double) getRotationRateAxis:(RMCoreIMUAxis)axis
{
    double rotationRate = 0;
    
    // select axis...
    switch(axis) {
            // ...and grab data
        case RMCoreIMUAxisX:
            rotationRate = self.deviceRotationRate.x;
            break;
        case RMCoreIMUAxisY:
            rotationRate = self.deviceRotationRate.y;
            break;
        case RMCoreIMUAxisZ:
            rotationRate = self.deviceRotationRate.z;
            break;
        default:
            break;
    }
    
    return rotationRate;
}

#pragma mark Hardware Availability Test Methods

// Test if accelerometer, gyroscope are all enabled and ready to sample
- (BOOL) isAllRawSensorsActive
{
    if (([self isAccelerometerActive] || ![self isAccelerometerAvailable]) &&
        ([self isGyroActive] || ![self isGyroAvailable])) {
        return YES;
    } else {
        return NO;
    }
}

// Tests if iDevice has an accessible accelerometer
- (BOOL) isAccelerometerAvailable
{
    return self.IMUManager.isAccelerometerAvailable;
}

// Tests if accelerometer is enabled and ready to sample
- (BOOL) isAccelerometerActive
{
    return self.IMUManager.isAccelerometerActive;
}

// Tests if iDevice has an accessible gyroscope
- (BOOL) isGyroAvailable
{
    return self.IMUManager.isGyroAvailable;
}

// Tests if gyroscope is enabled and ready to sample
- (BOOL) isGyroActive
{
    return self.IMUManager.isGyroActive;
}

// Tests if iDevice can use deviceMotion (which essentially means it has a
// gyroscope)
- (BOOL) isDeviceMotionAvailable
{
    return self.IMUManager.isDeviceMotionAvailable;
}

// Tests if deviceMotion is enabled and ready to sample
- (BOOL) isDeviceMotionActive
{
    return self.IMUManager.isDeviceMotionActive;
}

- (CMMotionManager *)IMUManager
{
    if (!_IMUManager) {
        _IMUManager = [[CMMotionManager alloc] init];
    }
    return _IMUManager;
}

@end
