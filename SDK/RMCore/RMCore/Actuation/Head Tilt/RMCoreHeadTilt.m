//
//  RMCoreHeadTilt.m
//  RMCore
//

#import "RMCoreHeadTilt.h"
#import "RMCoreControllerPID.h"
#import "RMCoreMotor_Internal.h"
#import <RMShared/RMMath.h>

// furthest we can be off from desired angle
#define RM_TILT_TO_ANGLE_MAX_DISCREPANCY 2.0

// longest duration of time we can attempt to tilt for
#define maxTiltRunTime 2.2

typedef void (^BoolBlock)(BOOL);

@interface RMCoreHeadTilt () {
    RMCoreControllerPID *_headTiltPid;
    BoolBlock _completion;
    
    RMCoreMotor *_tiltMotor;
}

@end

@implementation RMCoreHeadTilt

- (id)init
{
    self = [super init];
    if (self) {
        // initialize
        _tilting = NO;
    }
    return self;
}

- (void)setRobot:(RMCoreRobot<HeadTiltProtocol, RobotMotionProtocol> *)robot
{
    _robot = robot;
    _tiltMotor = robot.tiltMotor;
}

- (void)tiltWithMotorPower:(float)motorPower
{
    if (motorPower != 0){
        // apply command directly and set indicator flag
        _tiltMotor.powerLevel = motorPower;
        _tilting = YES;
        [[NSNotificationCenter defaultCenter] postNotificationName:RMCoreRobotHeadTiltSpeedDidChangeNotification
                                                            object:self.robot
                                                          userInfo:nil];
    } else {
        // use method so that stopping is done properly
        [self stopTilting];
    }
    
    // update the reference attitude used by the robot attitude tracker module
    [_robot takeDeviceReferenceAttitude];
}

- (void)tiltByAngle:(float)angle completion:(void (^)(BOOL))completion
{
    [self tiltToAngle:(self.headAngle + angle) completion:completion];
}

- (void)tiltToAngle:(float)angle completion:(void (^)(BOOL))completion
{
    // If we're already tilting, stop that timer
    [self stopTilting];
    
    _completion = completion;
    
    // If our angle is outside the bounds of hardware and we're trying to tilt further outside those bounds, don't tilt
    // This means that if you're on a slope, you can tilt away from that displacement but not back in the direction you came from
    if ((angle > self.headAngle && self.headAngle > self.robot.maximumHeadTiltAngle) || (angle < self.headAngle && self.headAngle < self.robot.minimumHeadTiltAngle)) {
        if (completion) {
            completion(NO);
        }
    } else {
        // If we're reasonably sure we're on flat ground, clamp our desired angle to between the maximum and minimum specified by hardware
        // However, if the head angle is not within the bounds of hardware, there's a good chance we're not on flat ground
        // And so we should just try to tilt to the requested angle
        double desiredAngle = angle;
        if (self.headAngle < self.robot.maximumHeadTiltAngle && self.headAngle > self.robot.minimumHeadTiltAngle) {
            desiredAngle = CLAMP(self.robot.minimumHeadTiltAngle, angle, self.robot.maximumHeadTiltAngle);
        }
        double startTime = currentTime();
        
        // Set up a closed-loop controller to get us quickly & accurately to our desired angle
        __weak RMCoreHeadTilt *weakSelf = self;
        
        float (^inputSource)() = ^float{
            return weakSelf.headAngle;
        };
        
        __block BOOL isCompleted = NO;

        void (^outputSink)(float, RMControllerPIDState *) = ^(float PIDControllerOutput, RMControllerPIDState *contollerState) {
            if (isCompleted) {
                return;
            }

            float headAngle = weakSelf.headAngle;
            double runTime = currentTime() - startTime;

            // Check that we haven't been trying for too long & that we aren't close enough
            if (ABS(headAngle - desiredAngle) > RM_TILT_TO_ANGLE_MAX_DISCREPANCY && runTime < maxTiltRunTime) {
                _tiltMotor.powerLevel = CLAMP(-1.0, PIDControllerOutput, 1.0);
            } else {
                // Ensure that we don't run this controller again after we've completed
                isCompleted = YES;
                _completion = nil;

                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakSelf stopTilting];

                    if (completion) {
                        // If we reached our angle, return success
                        BOOL success = ABS(headAngle - desiredAngle) < RM_TILT_TO_ANGLE_MAX_DISCREPANCY;
                        completion(success);
                    }
                });
            }
        };

        _headTiltPid = [[RMCoreControllerPID alloc] initWithFrequency:12.0
                                                         proportional:0.11
                                                             integral:0.0
                                                           derivative:0.0
                                                             setpoint:desiredAngle
                                                          inputSource:inputSource
                                                           outputSink:outputSink];
        
        // start controller and set indicator flag
        _headTiltPid.enabled = YES;
        _tilting = YES;
        [[NSNotificationCenter defaultCenter] postNotificationName:RMCoreRobotHeadTiltSpeedDidChangeNotification
                                                            object:self.robot
                                                          userInfo:nil];
        
        // alert user if command issued without IMU being active
        if (!self.robot.isRobotMotionEnabled) {
            NSString *warningString =  @"WARNING: 'Tilt Head To/By' command "
            "called with RobotMotion disabled; head output is unpredictable";
            
            NSLog(@"%@", warningString);
        }
    }
}

- (void)stopTilting
{
    if (_headTiltPid) {
        [self disableClosedLoopControllers];
        if (_completion) {
            _completion(NO);
        }
    }
    
    _tiltMotor.powerLevel = 0.0;
    _tilting = NO;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:RMCoreRobotHeadTiltSpeedDidChangeNotification
                                                        object:self.robot
                                                      userInfo:nil];
}

- (double)headAngle
{
    // Use the arctan of these gravity vectors to find the angle (in degrees) of the device
    
    double currentAngle = RAD2DEG(-atan2(_robot.deviceGravity.y,
                                         _robot.deviceGravity.z ) );
    if (currentAngle < 0) {
        currentAngle += 360.0;
    }
    return currentAngle;
}

#pragma mark - Private methods

// ensure controller doesn't remain active
- (void)disableClosedLoopControllers
{
    // turn off closed-loop controller
    _headTiltPid.enabled = NO;
    _headTiltPid = nil;
}

@end
