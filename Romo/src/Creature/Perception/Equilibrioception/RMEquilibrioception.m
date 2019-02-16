//
//  RMEquilibrioception.m
//  Romo
//

#import "RMEquilibrioception.h"
#import <Romo/RMCore.h>
#import <Romo/RMCoreMovingAverage.h>
#import <Romo/RMMath.h>
#import <Romo/RMDispatchTimer.h>
#import <Romo/UIDevice+Romo.h>

NSString *const RMRobotDidFlipToOrientationNotification = @"RMRobotDidFlipToOrientationNotification";
NSString *const RMRobotDidStartClimbingNotification = @"RMRobotDidStartClimbingNotification";

#define SENSOR_UPDATE_RATE_FAST 24.0 // (Hz) speed of sensing loop on fast devices
#define SENSOR_UPDATE_RATE_SLOW 16.0 // (Hz) speed of sensing loop on slow devices

#define GRAVITY_BUFFER_TIME 1.0 // (s)
#define GRAVITY_BUFFER_SIZE ((int)(GRAVITY_BUFFER_TIME * self.updateFrequency))
#define GRAVITY_CURRENT_IDX (GRAVITY_BUFFER_SIZE - 1)

/** The minimum change in acceleration to trigger a shake */
static const float minimumShakeJerk = 0.65;

/** The maximum change in acceleraiton to indicate the end of a shake */
static const float maximumNoShakeJerk = 0.08;

/** Shakes must last this long to trigger */
static const float shakeDuration = 1.5;

/** Minimum time in between shake triggers */
static const float shakeTriggerTimeout = 2.0;

/**
 How slowly the leaky spin integrator leaks
 [0.0, 1.0]
 */
static const float leakySpinRate = 0.99;

/** How large the leaky spin integrator must become for the dizzy state to be triggered */
static const float integratedDizzyThreshold = 620;

static const float maximimTiltDeviation = 14.0; // degrees

static const int minimumConsecutiveClimbCount = 3;

typedef enum {
    RMRobotElevationStateUnknown  = 0,
    RMRobotElevationStatePutDown  = 1,
    RMRobotElevationStatePickedUp = 2,
} RMRobotElevationState;

@interface RMEquilibrioception () {
    CMAcceleration _gravityVectorBuffer[(int)(GRAVITY_BUFFER_TIME * SENSOR_UPDATE_RATE_FAST)];
    CMAcceleration _gravityVectorMoveBuffer[(int)(GRAVITY_BUFFER_TIME * SENSOR_UPDATE_RATE_FAST)];
}

@property (nonatomic, readonly, getter=isTilting) BOOL tilting;
@property (nonatomic, readonly, getter=isMoving) BOOL moving;

@property (nonatomic) RMRobotElevationState elevationState;
@property (nonatomic) RMRobotElevationState previousElevationState;
@property (nonatomic, strong) RMCoreMovingAverageSimple *zAccelerationFastMovingAverage;
@property (nonatomic, strong) RMCoreMovingAverageSimple *zAccelerationSlowMovingAverage;

@property (nonatomic) double leakySpinIntegrator;

@property (nonatomic, strong) RMDispatchTimer *sensingTimer;
@property (nonatomic) double updateFrequency;

@property (nonatomic) CMAcceleration previousAcceleration;
@property (nonatomic) BOOL startedShaking;
@property (nonatomic) double previousShakeTriggerTime;
@property (nonatomic, strong) NSTimer *shakeVerificationTimer;
@property (nonatomic, strong) NSTimer *noShakeVerificationTimer;

@property (nonatomic) double previousTiltTime;
@property (nonatomic) float actuatedHeadAngle;
@property (nonatomic) int consecutiveClimbCount;

- (void)romoRotatedToPitch:(CGFloat)pitch roll:(CGFloat)roll;

@end

@implementation RMEquilibrioception

- (id)init
{
    self = [super init];
    if (self) {
        self.updateFrequency = [UIDevice currentDevice].isFastDevice ? SENSOR_UPDATE_RATE_FAST : SENSOR_UPDATE_RATE_SLOW;
    }
    return self;
}

- (void)dealloc
{
    if (_sensingTimer) {
        [self.sensingTimer stopRunning];
    }
}

- (void)setRobot:(RMCoreRobot<RobotMotionProtocol, HeadTiltProtocol, DriveProtocol> *)robot
{
    if (robot != _robot) {
        _robot = robot;
        
        [self.sensingTimer stopRunning];
        self.sensingTimer = nil;
        
        if (robot) {
            __weak RMEquilibrioception *weakSelf = self;

            // average recent veritcal accleration
            if (!self.zAccelerationFastMovingAverage) {
                self.zAccelerationFastMovingAverage = [RMCoreMovingAverageSimple createFilterWithFrequency:20
                                                                                                windowSize:4
                                                                                               inputSource:^double {
                                                                                                   return [weakSelf getUpwardAcceleration];
                                                                                               }];
            }
            
            // average long-term vertical accelerations
            if (!self.zAccelerationSlowMovingAverage) {
                self.zAccelerationSlowMovingAverage = [RMCoreMovingAverageSimple createFilterWithFrequency:20
                                                                                                windowSize:60
                                                                                               inputSource:^double {
                                                                                                   return [weakSelf getUpwardAcceleration];
                                                                                               }];
            }
            
            self.elevationState = RMRobotElevationStatePutDown;
            self.previousElevationState = RMRobotElevationStatePutDown;
            self.previousShakeTriggerTime = currentTime();
            _orientation = RMRobotOrientationUpright;
            
            [self.sensingTimer startRunning];
        }
    }
}

- (BOOL)isDizzy
{
    return (ABS(self.leakySpinIntegrator) >= integratedDizzyThreshold);
}

#pragma mark - Private Methods

- (void)sense
{
    static CFTimeInterval robotNotMovingDelayTime = 0;
    static BOOL lockedFromMotion = NO;
    
    if (self.robot.isRobotMotionReady) {
        CMAcceleration gravity = self.robot.deviceGravity;
        
        float pitch = -atan2(gravity.y, gravity.z);
        if (pitch < 0) {
            pitch += 2*M_PI;
        }
        
        float roll = asinf(gravity.x);
        if (roll < 0) {
            roll += 2*M_PI;
        }
        
        self.leakySpinIntegrator = (leakySpinRate * self.leakySpinIntegrator) + (self.robot.platformYawRate / self.updateFrequency);

        [self romoRotatedToPitch:pitch roll:roll];

        // can't reliably sense up/down if robot is driving, this conditional
        // makes sure the robot has had a chance to come to a full rest before
        // up/down is tested (note: tilt test here is of automated (motorized)
        // tilting only)
        if(self.robot.isDriving || self.robot.isTilting)
        {
            lockedFromMotion = YES;
            robotNotMovingDelayTime = CACurrentMediaTime() + 0.2;
        }
        else if(lockedFromMotion)
        {
            if(CACurrentMediaTime() > robotNotMovingDelayTime)
            {
                // must reset filters, otherwise the effects of the very strong
                // accelerations that come form some romotions (angry, for
                // example) can linger for a long, long time
                [self.zAccelerationFastMovingAverage resetFilter];
                [self.zAccelerationSlowMovingAverage resetFilter];
                [self accelLowPassFilterWithInput:0 resetFilter:YES];
                
                lockedFromMotion = NO;
            }
        }
        else if(!self.tilting)
        {
            // this tilt tests for manual tilting (or motorized tilting) of the
            // head, since this test comes after the motorized-only test
            // (self.robot.isTilting) it effectively only test for manual tilt
            // (in which case there's no need to reset the filters, as above,
            // we just need to wait for the user to stop moving the head before
            // updating the up/down sensor)
            [self updateRomoPickUpPutDownVirtualSensor];
        }
        
        [self romoAccelerated:self.robot.deviceAcceleration];
    }
}

- (void)romoAccelerated:(CMAcceleration)acceleration
{
    // ensure there's a delay between shake triggers
    double time = currentTime();
    if (time - self.previousShakeTriggerTime > shakeTriggerTimeout) {
        if (!self.startedShaking && accelerationIsShake(self.previousAcceleration, acceleration, minimumShakeJerk)) {
            // if we haven't detected a shake but we currently pass, flip the flag and start a verification timer
            self.startedShaking = YES;
            
            // Kill the no-shake timer
            if (self.noShakeVerificationTimer) {
                [self.noShakeVerificationTimer invalidate];
                self.noShakeVerificationTimer = nil;
            }
            
            if (!self.shakeVerificationTimer) {
                self.shakeVerificationTimer = [NSTimer timerWithTimeInterval:shakeDuration
                                                                      target:self
                                                                    selector:@selector(handleShakeVerification:)
                                                                    userInfo:nil
                                                                     repeats:NO];
                [[NSRunLoop mainRunLoop] addTimer:self.shakeVerificationTimer forMode:NSRunLoopCommonModes];
            }
        } else if (self.startedShaking && !accelerationIsShake(self.previousAcceleration, acceleration, maximumNoShakeJerk)) {
            // if we were already shaking but we've settled below the threshold, try to invalidate the shake
            self.startedShaking = NO;

            if (!self.noShakeVerificationTimer) {
                self.noShakeVerificationTimer = [NSTimer timerWithTimeInterval:shakeDuration / 2.0
                                                                                 target:self
                                                                               selector:@selector(handleNoShakeVerification:)
                                                                               userInfo:nil
                                                                                repeats:NO];
                [[NSRunLoop mainRunLoop] addTimer:self.noShakeVerificationTimer forMode:NSRunLoopCommonModes];
            }
        }
    }
    self.previousAcceleration = acceleration;
}

// at least two axes must pass the threshold for absolute change in acceleration
BOOL accelerationIsShake(CMAcceleration last, CMAcceleration current, double threshold) {
	double deltaX = ABS(last.x - current.x);
    double deltaY = ABS(last.y - current.y);
    double deltaZ = ABS(last.z - current.z);
    
	return (deltaX > threshold && deltaY > threshold) || (deltaX > threshold && deltaZ > threshold) || (deltaY > threshold && deltaZ > threshold);
}

- (void)handleShakeVerification:(NSTimer *)shakeVerificationTimer
{
    self.previousShakeTriggerTime = currentTime();
    if ([self.delegate respondsToSelector:@selector(robotDidDetectShake)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate robotDidDetectShake];
        });
    }
    
    [self.noShakeVerificationTimer invalidate];
    self.noShakeVerificationTimer = nil;
    self.shakeVerificationTimer = nil;
}

- (void)handleNoShakeVerification:(NSTimer *)noShakeVerificationTimer
{
    [self.shakeVerificationTimer invalidate];
    self.shakeVerificationTimer = nil;
    self.noShakeVerificationTimer = nil;
}

- (void)romoRotatedToPitch:(CGFloat)pitch roll:(CGFloat)roll
{
    if (roll > DEG2RAD(250) && roll < DEG2RAD(310)) {
        self.orientation = RMRobotOrientationRightSide;
    } else if (roll > DEG2RAD(50) && roll < DEG2RAD(110)) {
        self.orientation = RMRobotOrientationLeftSide;
    } else if (pitch > DEG2RAD(190) && pitch < DEG2RAD(270)) {
        self.orientation = RMRobotOrientationBackSide;
    } else if (pitch >= DEG2RAD(275) || pitch < DEG2RAD(25)) {
        self.orientation = RMRobotOrientationFrontSide;
    } else {
        self.orientation = RMRobotOrientationUpright;
    }
    
    if (self.robot.isTilting) {
        // Time out for a brief amount of time after a tilt command to allow for deceleration
        self.previousTiltTime = currentTime() + 0.35;
        self.actuatedHeadAngle = self.robot.headAngle;
        self.consecutiveClimbCount = 0;
    }
    
    BOOL stillTilting = currentTime() <= self.previousTiltTime;
    if (!stillTilting) {
        // If we aren't sending tilt commands, check to see if our pitch is changing too much
        float headAngle = self.robot.headAngle;
        
        if (self.robot.isDriving) {
            if (ABS(headAngle - self.actuatedHeadAngle) > maximimTiltDeviation) {
                // If we're driving and tilted too far from our last actuated headAngle, then we must be climbing
                if (self.consecutiveClimbCount < minimumConsecutiveClimbCount) {
                    self.consecutiveClimbCount++;
                } else {
                    self.actuatedHeadAngle = headAngle;
                    self.consecutiveClimbCount = 0;
                    [self.delegate robotDidStartClimbing];
                    [[NSNotificationCenter defaultCenter] postNotificationName:RMRobotDidStartClimbingNotification object:nil];
                }
            } else {
                self.consecutiveClimbCount = MAX(0, self.consecutiveClimbCount--);
            }
        } else {
            // If we aren't driving, then our headAngle must have been moved externally (via a human, for example)
            self.actuatedHeadAngle = headAngle;
            self.consecutiveClimbCount = 0;
        }
    }

}

- (void)setOrientation:(RMRobotOrientation)orientation
{
    if (orientation != _orientation) {
        _orientation = orientation;
        if ([self.delegate respondsToSelector:@selector(robotDidFlipToOrientation:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate robotDidFlipToOrientation:self.orientation];
            });
            [[NSNotificationCenter defaultCenter] postNotificationName:RMRobotDidFlipToOrientationNotification object:self.robot userInfo:@{@"orientation" : @(orientation) }];
        }
    }
}

- (void)sendUpDownStateNotification
{
    if (self.elevationState == RMRobotElevationStatePickedUp && self.previousElevationState != RMRobotElevationStatePickedUp) {
        // if robot was just picked up...
        if ([self.delegate respondsToSelector:@selector(robotDidDetectPickup)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate robotDidDetectPickup];
            });
        }
    } else if (self.elevationState == RMRobotElevationStatePutDown && self.previousElevationState != RMRobotElevationStatePutDown) {
        // if robot was just put down...
        if ([self.delegate respondsToSelector:@selector(robotDidDetectPutDown)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate robotDidDetectPutDown];
            });
        }
    }
    
    self.previousElevationState = self.elevationState;
}

// calculate acceleration in vertical direction
- (double)getUpwardAcceleration
{
    return self.robot.platformAcceleration.z;
}

// test if two gravity vectors are (roughly) equivalent
- (BOOL)isGravityVector:(CMAcceleration)g1 equalToVector:(CMAcceleration)g2
{
    // in reality two gravity vectors will never be exactly the same, this is
    // the tolerance within which they will be considered equivalent
    const float kTolerance = .02;             // m/s^2
    
    // require that all axes be within tolerance
    if(fabs(g1.x - g2.x) > kTolerance)
    {
        return NO;
    }
    
    if(fabs(g1.y - g2.y) > kTolerance)
    {
        return NO;
    }
    
    if(fabs(g1.z - g2.z) > kTolerance)
    {
        return NO;
    }
    
    // vectors are equal!
    return YES;
}

// put next vector in gravity vector ring buffer
- (void)updateGravityBuffer
{
    // position in buffer
    static int count = 0;
    
    // straight fill
    if(count < GRAVITY_BUFFER_SIZE)
    {
        _gravityVectorBuffer[count] = [self.robot deviceGravity];
        count++;
    }
    // FIFO buffer: shift data left and add new value to the end of the buffer
    else
    {
        // number of bytes to move (convenience)
        int numBytes = (GRAVITY_BUFFER_SIZE - 1) * sizeof(_gravityVectorBuffer[0]);
        
        // slide data over
        memcpy(_gravityVectorMoveBuffer, (&_gravityVectorBuffer[1]), numBytes);
        memcpy(_gravityVectorBuffer, _gravityVectorMoveBuffer, numBytes);
        
        // tack on the new piece of data
        _gravityVectorBuffer[GRAVITY_CURRENT_IDX] = [self.robot deviceGravity];
    }
}

// determine the most recent iDevice orientation that was stable
- (CMAcceleration)getStableGravityVector
{
    // amount of time (s) required for stability
    const float kRequiredTime = 0.150;
    
    // associated sample count value
    const int kRequiredCount = MIN((kRequiredTime * self.updateFrequency), GRAVITY_BUFFER_SIZE);
    
    // start from end (most recent measurement)
    CMAcceleration compareVector = _gravityVectorBuffer[GRAVITY_CURRENT_IDX];
    
    // initialize result (this invalid vector is returned if no stable vector is
    // found)
    CMAcceleration stableGracityVector;
    stableGracityVector.x = 0.;
    stableGracityVector.y = 0.;
    stableGracityVector.z = 0.;
    
    int count = 1;
    
    // walk backwards through buffer (from newest data to oldest)
    for(int i = (GRAVITY_BUFFER_SIZE - 2); i >= 0; i--)
    {
        if([self isGravityVector:compareVector
                   equalToVector:_gravityVectorBuffer[i]] )
        {
            // equivalent vector found
            count++;
        }
        else
        {
            // reset to a new potentially stable vector and keep going
            compareVector = _gravityVectorBuffer[i];
            count = 1;
        }
        
        // stable vector found!
        if(count >= kRequiredCount)
        {
            stableGracityVector = _gravityVectorBuffer[i];
            break;
        }
    }
    
    return stableGracityVector;
}

// sense if iDevice's orientation is stable
- (BOOL)isGravityVectorStable
{
    // number of samples to test (it would be better if this were done based on
    // time instead of sample count)
    const int kSearchDepth = GRAVITY_BUFFER_SIZE;
    
    // look through the buffer and see if each element is the same as the most
    // current value
    for(int i = GRAVITY_BUFFER_SIZE - 2;
        i >= GRAVITY_BUFFER_SIZE - kSearchDepth;
        i--)
    {
        if(![self isGravityVector:_gravityVectorBuffer[GRAVITY_CURRENT_IDX]
                    equalToVector:_gravityVectorBuffer[i]] )
        {
            return NO;
        }
    }
    
    // iDevice orientation is stable
    return YES;
}

// sense if the iDevice is tilting on head-tilt axis
- (BOOL)isTilting
{
    const float kOnAxisThreshold = 0.1;          // deg/s
    const float kOffAxisThreshold = 10;          // deg/s
    
    // if the tilt motor is running
    if(self.robot.isTilting ||
       // or the phone is rotating around the pitch axis but not the roll and
       // yaw axes (implies that the user is moving the tilt by hand)
       (fabs([self.robot deviceRotationRate].x) > kOnAxisThreshold &&
        fabs([self.robot deviceRotationRate].y) < kOffAxisThreshold &&
        fabs([self.robot deviceRotationRate].z) < kOffAxisThreshold ) )
    {
        return YES;
    }
    
    return NO;
}

- (BOOL)isMoving
{
    const float kAccelerationThreshold = 0.05;          // m/s^2
    const float kGyroscopeThreshold = 2.0;              // deg/s
    
    if(fabs([self.robot deviceAcceleration].x) > kAccelerationThreshold ||
       fabs([self.robot deviceAcceleration].y) > kAccelerationThreshold ||
       fabs([self.robot deviceAcceleration].z) > kAccelerationThreshold ||
       fabs([self.robot deviceRotationRate].x) > kGyroscopeThreshold ||
       fabs([self.robot deviceRotationRate].y) > kGyroscopeThreshold ||
       fabs([self.robot deviceRotationRate].z) > kGyroscopeThreshold )
    {
        return YES;
    }

    return NO;
    
    // WARNING: This method used to use deviceGyroscope instead of
    //          deviceRotationRate.  The reason for this is that we want to
    //          detect motion without the latency caused by filtering.  We are
    //          now using deviceRotationRate because many 5 series iDevices
    //          currently (11/01/2013) have an issue with their gyros that
    //          result in bad raw data.  The bad data probably propogates
    //          to the filtered deviceRotationRate data but the filtering seems
    //          to be sufficient to bring the resting rotation rates back down
    //          to near the expected 0 deg/s.  This warning is to serve as a
    //          reminder that using deviceRotationRate is a work around, it
    //          doesn't really fix the core problem (which is Apple's).  Also,
    //          keep an eye out for other parts of our code that may not work
    //          right with some 5 series iDevices.
}

// sense if robot is accelerating upward
- (BOOL)isMovingVerticallyWithAcceleration:(float)acceleration
{
    double zAccel;     // acceleration in the vertical direction
    double zAccelLPF;  // low-pass filtered veritcal acceleration
    
    // this difference prevents us from having to assume that the
    // acceleration reports as zero when robot is stationary (which it
    // doesn't always... it's not stable)
    zAccel = [self.zAccelerationFastMovingAverage getFilterValue] - [self.zAccelerationSlowMovingAverage getFilterValue];

    // run through low-pass filter to clean signal up a bit
    zAccelLPF = [self accelLowPassFilterWithInput:zAccel resetFilter:NO];
    
    
    if(((acceleration >= 0) && (zAccelLPF > acceleration)) ||
       ((acceleration < 0) && (zAccelLPF < acceleration)) )
    {
        return YES;
    }

    return NO;
}

// detect if robot has been picked up or put down
- (void)updateRomoPickUpPutDownVirtualSensor
{
    // How it works:  The idea is that we "know" the robot is being picked up
    // when it accelerates upward for a sustained period of time.  We "know"
    // that it's put down when the iDevice's orientation is the same as it was
    // before it was picked up (as described by the relative direction of the
    // gravity vector), or when the iDevic's orientation becomes consistent for
    // a long time (indicating that the robot has been put down but in a new
    // orientation).
    //
    // Some issue: (1) Since the sensor/algorithm doesn't really measure
    // elevation it's possible to fool it.  All the little details and
    // complications in the state machine are there to limit the likelighood of
    // this happening.  (2) It's hard to differentiate between upward and
    // downward acceleration (over short durations) because when a person picks
    // up or puts down the robot the acceleration is generally not all in one
    // direction.  Typically there is initially a brief accelration in the
    // direction that is opposite the intended direction of motion.  I think
    // this is because there is a tendancy to pivot your wrist a little as you
    // pick it up or put it down (or something like that). (3) It's entirely
    // possible to trigger a false even by patting the robot's head.  This is
    // particularly possible if the phone is tilted all the way back in which
    // case it's easy to get it to accelerate up and down as the phone bounces
    // on the tilt pivot as it's patted.  This isn't a serious problem  right
    // now but if we add pat detection it may become a serious problem.
    
    // state transistion parameters
    const float kPickUpStabilityEndLength = 0.1;   // seconds
    const float kPutDownStabilityEndLength = 0.3;  // seconds
    const float kPickUpLockOutEndLength = 0.5;     // seconds
    const float kPutDownTimeoutLength = 1.5;       // seconds
    
    // state machine states
    enum
    {
        WAIT_FOR_VERT_MOTION_TRIGGER_UP,
        WAIT_FOR_SUSTAINED_MOTION_UP,
        WAIT_FOR_PICK_UP_COMPLETE,
        WAIT_FOR_VERT_MOTION_TRIGGER_DOWN,
        WAIT_FOR_PUT_DOWN,
        WAIT_FOR_PICK_UP_LOCK_OUT_END
    };
    
    // state transition timers
    static CFTimeInterval pickUpStableEndTime = 0;
    static CFTimeInterval putDownStableEndTime = 0;
    static CFTimeInterval putDownWaitTimeoutEndTime = 0;
    static CFTimeInterval pickUpLockOutEndTime = 0;
    static CMAcceleration referenceGravityVector;
    
    static int state = WAIT_FOR_VERT_MOTION_TRIGGER_UP;
    
    // find out if robot is accelating up/down right now (in theory the called
    // method tests for upward acceleration but point (2) in "Some Issues" above
    // explains why it's hard to disambiguate acceleration direction)
    BOOL isMovingUp = NO;
    BOOL isMovingDown = NO;
    
    isMovingUp = [self isMovingVerticallyWithAcceleration:.05];
    isMovingDown = [self isMovingVerticallyWithAcceleration:-.01];
        
    // add current gravity vector to the ring buffer
    [self updateGravityBuffer];
    
    switch (state)
    {
        case WAIT_FOR_VERT_MOTION_TRIGGER_UP:
        {
            // watch for an acceleration change, which suggest the robot
            // _may_ be being picked up
            if(isMovingUp)
            {
                // set the time at which "up" detection will be made (this
                // helps avoids small vibrations, like someone tapping the
                // top of the iDevice) from being detected as a pick up)
                pickUpStableEndTime = CACurrentMediaTime() +
                kPickUpStabilityEndLength;
                
                // store the more recent stable gravity vector as the
                // reference of the phone's orientation before this
                // potential pick up
                referenceGravityVector = [self getStableGravityVector];
                
                state = WAIT_FOR_SUSTAINED_MOTION_UP;
            }
            
            break;
        }
        case WAIT_FOR_SUSTAINED_MOTION_UP:
        {
            // if the robot has been accelerating for long enough then...
            if((CACurrentMediaTime() > pickUpStableEndTime))
            {
                // the robot has been picked up
                self.elevationState = RMRobotElevationStatePickedUp;
                
                // after this time we'll just have to assume that the robot
                // has been put down (this is a fail-safe that will prevent
                // a missed put-down detection from freezing up the system)
                putDownWaitTimeoutEndTime = CACurrentMediaTime() +
                kPutDownTimeoutLength;
                
                state = WAIT_FOR_PICK_UP_COMPLETE;
            }
            else if(!isMovingUp)
            {
                // if the robot stopped accelerating too quickly then we
                // have to give up without detecting a pick up
                self.elevationState = RMRobotElevationStateUnknown;
                
                state = WAIT_FOR_VERT_MOTION_TRIGGER_UP;
            }
            
            break;
        }
        case WAIT_FOR_PICK_UP_COMPLETE:
        {
            // the robot has been picked up but the user may still be
            // lifting, so wait for the acceleration to stops before
            // watching for a put-down event (a weakness here is that if
            // you pick up and put down in one smooth motion the put-down
            // will not be detected)
            if (!isMovingUp)
            {
                putDownWaitTimeoutEndTime = -1;
                putDownStableEndTime = -1;
                state = WAIT_FOR_VERT_MOTION_TRIGGER_DOWN;
            }
            
            break;
        }
        case WAIT_FOR_VERT_MOTION_TRIGGER_DOWN:
        {
            // sustained relatively large acceleration
            if(isMovingDown)
            {
                // adjust timeout timer because robot is being moved right
                // now
                putDownWaitTimeoutEndTime = CACurrentMediaTime() +
                kPutDownTimeoutLength;
                
                if(putDownStableEndTime < 0)
                {
                    putDownStableEndTime = CACurrentMediaTime() +
                    kPutDownStabilityEndLength;
                }
                // adequate downward motion; start looking for put-down
                else if(CACurrentMediaTime() > putDownStableEndTime)
                {
                    state = WAIT_FOR_PUT_DOWN;
                }
            }
            // small movements detected (user is probably holding robot)
            else if(self.isMoving)
            {
                // adjust timeout timer and sustained motion timer because
                // robot is likely still in user's hands
                putDownWaitTimeoutEndTime = CACurrentMediaTime() +
                kPutDownTimeoutLength/10.;
                
                // reset
                putDownStableEndTime = -1;
            }
            else
            {
                // no motion, robot may be on the ground
                if(putDownWaitTimeoutEndTime < 0)
                {
                    // set
                    putDownWaitTimeoutEndTime = CACurrentMediaTime() +
                    kPutDownTimeoutLength;
                }
                // too much time without motion; start looking for put-down
                else if(CACurrentMediaTime() > putDownWaitTimeoutEndTime)
                {
                    // reset
                    putDownWaitTimeoutEndTime = CACurrentMediaTime() +
                    kPutDownTimeoutLength;
                    
                    state = WAIT_FOR_PUT_DOWN;
                }
                
                // reset
                putDownStableEndTime = -1;
            }
            
            break;
        }
            
        case WAIT_FOR_PUT_DOWN:
        {
            // if the current iDevice orientation is the same as the
            // target reference orientation then the robot was put down!
            if([self
                isGravityVector:_gravityVectorBuffer[GRAVITY_CURRENT_IDX]
                equalToVector:referenceGravityVector ] )
            {
                // found the reference vector; the robot has been put down
                self.elevationState = RMRobotElevationStatePutDown;
                
                // set the time after which it's okay to test if the robot
                // has been picked up again (this prevents false event
                // detections if the user shakes the robot up and down)
                pickUpLockOutEndTime = CACurrentMediaTime() +
                kPickUpLockOutEndLength;
                
                state = WAIT_FOR_PICK_UP_LOCK_OUT_END;
            }
            
            // if the orientation of the iDevice has become very stable but
            // is not the same as the target orienation then assume that the
            // robot has been down in a new orientation
            else if(!self.isMoving && [self isGravityVectorStable])
            {
                // robot's orientation is stable; the robot has been put down
                self.elevationState = RMRobotElevationStatePutDown;
                
                pickUpLockOutEndTime = CACurrentMediaTime() +
                kPickUpLockOutEndLength;
                
                state = WAIT_FOR_PICK_UP_LOCK_OUT_END;
            }
            
            // if it's been a long time and a put-down hasn't been detected,
            // assume there's been an error and restart the state machine
            else if(CACurrentMediaTime() > putDownWaitTimeoutEndTime)
            {
                // Put-Down detection timed out
                
                // the robot's up/down state is unknown but it's safest to
                // assume that it's been put down, otherwise you can get
                // stuck in a weird situation when the robot has been put
                // down but is behaving like it is lifted up, which is
                // a hard state to recover from
                self.elevationState = RMRobotElevationStatePutDown;
                
                pickUpLockOutEndTime = CACurrentMediaTime() +
                kPickUpLockOutEndLength;
                
                state = WAIT_FOR_PICK_UP_LOCK_OUT_END;
            }
            
            // if there's motion detected then we probably got here falsely
            // and should go back to looking for the down motion trigger
            else if(self.isMoving)
            {
                // reset timers
                putDownWaitTimeoutEndTime = -1;
                putDownStableEndTime = -1;
                
                state = WAIT_FOR_VERT_MOTION_TRIGGER_DOWN;
            }
            
            break;
        }
        case WAIT_FOR_PICK_UP_LOCK_OUT_END:
        {
            // Pick-Up detection locked out
            
            // after this time it's okay to look for the robot to be picked
            // up again
            if(CACurrentMediaTime() > pickUpLockOutEndTime)
            {
                state = WAIT_FOR_VERT_MOTION_TRIGGER_UP;
            }
            
            break;
        }
    }

    [self sendUpDownStateNotification];
}

// low-pass filter used to take noise out of final acceleration measurement
- (double)accelLowPassFilterWithInput:(double)newData resetFilter:(BOOL)reset
{
    const float kAlpha = .3;
    static double prevVal = INFINITY;
    
    if(prevVal == INFINITY)
    {
        prevVal = newData;
    }
    else if(reset)
    {
        // this is a hacky way to let the outside world reset this filter
        prevVal = 0;
    }
    else
    {
        prevVal = prevVal + kAlpha * (newData - prevVal);
    }
    
    return prevVal;
}

- (RMDispatchTimer *)sensingTimer
{
    if (!_sensingTimer) {
        __weak RMEquilibrioception *weakSelf = self;
        _sensingTimer = [[RMDispatchTimer alloc] initWithName:@"com.Romotive.Equilibrioception"
                                                    frequency:self.updateFrequency];
        _sensingTimer.eventHandler = ^{
            [weakSelf sense];
        };
    }
    return _sensingTimer;
}

@end
