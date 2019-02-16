//
//  RMCoreRobotMotion.m
//  RMCore
//

#import "RMCoreRobotMotion.h"
#import <CoreMotion/CoreMotion.h>

@interface RMCoreRobotMotion()

// Private Properties

// structure to hold all raw & conditioned IMU data
@property (nonatomic) RMCoreIMUData IMUData;

// set of flag to indicate with IMU sub-blocks have fresh data
@property (nonatomic) BOOL isAccelerometerUpdated;
@property (nonatomic) BOOL isGyroscopeUpdated;
@property (nonatomic) BOOL isDeviceMotionUpdated;
@property (nonatomic) BOOL isIMUDataUpdated;

@property (nonatomic, readwrite) BOOL ready;

@end

@implementation RMCoreRobotMotion

// Initialize instance
- (id) init
{
    // init superclass
    self = [super init];
    
    if (self)
    {
        // Romotive IMU interface to CoreMotion framework
        _IMU = [[RMCoreMotionInterface alloc] init];
        
        // set this instance receive IMU data updates
        _IMU.delegate = self;
        
        // define sub-modules for tracking IMU data from iDevice's perspective
        // and from mobility platform's perspective
        _iDevice = [[RMCoreDeviceMotion alloc] init];
        _platform = [[RMCorePlatformMotion alloc] init];
        
        // initialze state
        _enabled = NO;
        _ready = NO;
        _isIMUDataUpdated = NO;
        _dataUpdateRate = RM_IMU_DEFAULT_UPDATE_FREQUENCY;
    }
    
    return self;
}

- (void)dealloc
{
    self.enabled = NO;
}

#pragma mark - RobotMotion

// Enable/Disable IMU
- (void)setEnabled:(BOOL)enabled
{
    if (enabled != _enabled) {
        _enabled = enabled;
        if (enabled == YES) {
            // make sure refresh rate remains set within bounds
            self.dataUpdateRate = _dataUpdateRate;
            
            // set IMU refresh periods to match data update rate
            self.IMU.deviceMotionUpdatePeriod = 1.0 / self.dataUpdateRate;
            self.IMU.accelerometerUpdatePeriod = 1.0 / self.dataUpdateRate;
            self.IMU.gyroUpdatePeriod = 1.0 / self.dataUpdateRate;

            [self.IMU startIMUConditionedFreeRunning];
            [self.IMU startIMURawFreeRunning];
        } else {
            // diable IMU
            [self.IMU stopIMU];
        }
    }
}

// Set RobotMotion (/IMU) refresh rate (Hz)
- (void)setDataUpdateRate:(float)dataUpdateRate
{
    _dataUpdateRate = CLAMP(RM_IMU_MIN_UPDATE_FREQUENCY,
                            dataUpdateRate,
                            RM_IMU_MAX_UPDATE_FREQUENCY);
}

// Tests to see if fresh data has been received from all active IMU sub-blocks
- (BOOL)isIMUDataUpdated
{
    static BOOL internalReady = NO;
    
    if (internalReady) {
        if ((self.isAccelerometerUpdated || !self.IMU.isAccelerometerActive) &&
           (self.isGyroscopeUpdated || !self.IMU.isGyroActive) &&
           (self.isDeviceMotionUpdated || !self.IMU.isDeviceMotionActive)) {
            return YES;
        } else {
            return NO;
        }
    }
    
    // this block tests to make sure the IMU is up and running (which takes a 
    // few seconds for some reason).  Before the IMU is ready it will return 
    // either 0.0 or nan when you ask it for data.  This block checks that 
    // gravity is not 0.0 on all axes (and is not nan anywhere), provided that 
    // the accelerometer is active.
    //
    // WARNING: If the accelerometer is not active RobotMotion will never work!
    if (([self.IMU isAccelerometerActive] == NO) ||
       
       // data should never be nan
       (isnan(self.IMUData.gravity.x) ||
        isnan(self.IMUData.gravity.y) ||
        isnan(self.IMUData.gravity.z) ) ||

       // gravity can't be zero on all axes (warning: RobotMotion will not
       // work in outer space!)
       (self.IMUData.gravity.x == 0. &&
        self.IMUData.gravity.y == 0. &&
        self.IMUData.gravity.z == 0. ) )
    {
        // IMU isn't ready, so clear the flags that indicate that good data has 
        // been received
        [self resetDataFlags];
        return NO;
    }
    
    // if we made it here the IMU is sourcing good data
    internalReady = YES;

    // but wait one cycle before saying the data is good to go because the
    // accelerometers may have gotten good data before the other IMU axes
    [self resetDataFlags];
    return NO;
}

// Send fresh IMU data along to iDevice & mobility platform motion modules
// for final processing
- (void)pushIMUData
{
       // if a complete fresh set of data has been received...
    if (self.isIMUDataUpdated)
    {
        if (!self.ready) {
            // need pass this data along here so that it's available for call
            // to takeReferenceAttitude (below).  It's good that this data is
            // pass along again after this block because that allows the
            // platform to use the newly taken reference to set the attitude.
            self.iDevice.freshIMUData = self.IMUData;
            self.platform.freshIMUData = self.IMUData;
            
            [self.platform takeReferenceAttitude];
        }
        
        // pass data long to iDevice/platformMotion sub-modules
        self.iDevice.freshIMUData = self.IMUData;
        self.platform.freshIMUData = self.IMUData;

        // reset flags
        [self resetDataFlags];
        
        self.ready = YES;
    }
}

// reset all the flags that indicated fresh IMU data is queued
- (void)resetDataFlags
{
    self.isAccelerometerUpdated = NO;
    self.isGyroscopeUpdated = NO;
    self.isDeviceMotionUpdated = NO;
    self.isIMUDataUpdated = NO;
}

#pragma mark - <IMUDataUpdate> Protocol

// method to be called when there is new accelerometer data available
- (void)freshAccelerometerDataAlertAtTime:(NSNumber *)timestamp
{
    // get data
    _IMUData.accelerometer.x = [self.IMU accelerationForAxis:RMCoreIMUAxisX];
    _IMUData.accelerometer.y = [self.IMU accelerationForAxis:RMCoreIMUAxisY];
    _IMUData.accelerometer.z = [self.IMU accelerationForAxis:RMCoreIMUAxisZ];

    // set status flag and attempt to pass data along to interested parties
    self.isAccelerometerUpdated = YES;
    [self pushIMUData];
}

// method to be called when there is new gyroscope data available
- (void) freshGyroDataAlertAtTime: (NSNumber *)timestamp
{
    // get data
    _IMUData.gyroscope.x = [self.IMU angularRateInDegreesForAxis:RMCoreIMUAxisX];
    _IMUData.gyroscope.y = [self.IMU angularRateInDegreesForAxis:RMCoreIMUAxisY];
    _IMUData.gyroscope.z = [self.IMU angularRateInDegreesForAxis:RMCoreIMUAxisZ];

    // set status flag and attempt to pass data along to interested parties
    self.isGyroscopeUpdated = YES;
    [self pushIMUData];
}

// method to be called when there is new Device Motion data available
- (void) freshDeviceMotionDataAlertAtTime: (NSNumber *)timestamp
{
    // get data
    _IMUData.attitude = [self.IMU attitude];
    
    _IMUData.gravity.x = [self.IMU gravityVectorForAxis:RMCoreIMUAxisX];
    _IMUData.gravity.y = [self.IMU gravityVectorForAxis:RMCoreIMUAxisY];
    _IMUData.gravity.z = [self.IMU gravityVectorForAxis:RMCoreIMUAxisZ];
    
    _IMUData.deviceAcceleration.x = [self.IMU userAccelerationVectorForAxis:RMCoreIMUAxisX];
    _IMUData.deviceAcceleration.y = [self.IMU userAccelerationVectorForAxis:RMCoreIMUAxisY];
    _IMUData.deviceAcceleration.z = [self.IMU userAccelerationVectorForAxis:RMCoreIMUAxisZ];
    
    _IMUData.rotationRate.x = [self.IMU rotationRateInDegreesForAxis:RMCoreIMUAxisX];
    _IMUData.rotationRate.y = [self.IMU rotationRateInDegreesForAxis:RMCoreIMUAxisY];
    _IMUData.rotationRate.z = [self.IMU rotationRateInDegreesForAxis:RMCoreIMUAxisZ];
    
    // set status flag and attempt to pass data along to interested parties
    self.isDeviceMotionUpdated = YES;
    [self pushIMUData];
}

@end
