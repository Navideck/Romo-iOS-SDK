//
//  RMCoreDifferentialDrive.m
//  Romo3
//

#import "RMCoreDifferentialDrive.h"
#import "RMCoreDriveController.h"
#import "RMCoreMovingAverage.h"
#import "RMCoreControllerPID.h"
#import <RMShared/RMMath.h>
#import <RMShared/RMCircleMath.h>
#import "RMCoreMotor_Internal.h"

@interface RMCoreDifferentialDrive ()

@property (nonatomic, strong) RMCoreDriveController *headingController;
@property (nonatomic, strong) RMCoreDriveController *radiusController;

@property (nonatomic, strong) RMCoreMotor *leftDriveMotor;
@property (nonatomic, strong) RMCoreMotor *rightDriveMotor;


@property (nonatomic, readwrite, getter=isDriving) BOOL driving;

// these properties are used by the the controller (non-PID controller) that
// is used for all turn-to/turn-by drive commands
// Note: There's probably a good way to do this such that all these global
//       parameters don't need to be... global (but I don't want to sink the
//       time into working that out right now) -mss.
@property (nonatomic) dispatch_queue_t turnToControlLoopQueue;
@property (nonatomic) dispatch_source_t turnToControlLoopTimer;
@property (nonatomic) BOOL turnToControllerEnabled;
@property (nonatomic) BOOL turnToControllerReachedGoal;
@property (nonatomic, copy) RMCoreTurncompletion turnCompletion;
@property (nonatomic) float turnToTargetHeading;
@property (nonatomic) float turnToTargetSpeed;
@property (nonatomic) float turnSweepAngle;
@property (nonatomic) float turnSweptAngle;
@property (nonatomic) float turnPrevHeading;
@property (nonatomic) BOOL turnToSlowDownStarted;
@property (nonatomic) float turnToElapsedStallTime;
@property (nonatomic) RMCoreTurnFinishingAction turnFinishingAction;

@end

@implementation RMCoreDifferentialDrive

- (id)init
{
    self = [super init];
    if (self)
    {
        // setup controllers for heading- and radius-based drive control
        [self setupHeadingController];
        [self setupRadiusController];
        [self setupTurnToController];

        // initialize turnTo/By controller state
        self.turnToControllerEnabled = NO;
        _turnCompletion = nil;
        _turnToSlowDownStarted = NO;
        _turnToElapsedStallTime = 0;
    }
    return self;
}

- (void)dealloc
{
    if (!self.turnToControllerEnabled) {
        dispatch_resume(self.turnToControlLoopTimer);
    }
    
    if (self.turnToControlLoopTimer) {
        dispatch_source_cancel(self.turnToControlLoopTimer);
    }
}

- (void)setRobot:(RMCoreRobot<DifferentialDriveProtocol,
                  RobotMotionProtocol> *)robot
{
    _robot = robot;
    _leftDriveMotor = robot.leftDriveMotor;
    _rightDriveMotor = robot.rightDriveMotor;
}

#pragma mark - drive commands

- (void)driveWithLeftMotorPower:(float)leftMotorPower
                rightMotorPower:(float)rightMotorPower
{
    // make sure closed-loop controllers stop trying to control motors
    [self disableClosedLoopControllers];

    // issue motor command
    _leftDriveMotor.powerLevel = leftMotorPower;
    _rightDriveMotor.powerLevel = rightMotorPower;

    if (leftMotorPower || rightMotorPower) {
        self.driving = YES;
    } else {
        self.driving = NO;
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:RMCoreRobotDriveSpeedDidChangeNotification
                                                        object:self.robot
                                                      userInfo:nil];
}

// drive on given heading at input power
- (void) driveWithHeading:(float)heading power:(float)power
{
    const float kLatencyFudgeFactor = 2.5;
    
    // make sure nothing else tries to control motors
    [self disableClosedLoopControllers];

    // issue motor command immediately
    _leftDriveMotor.powerLevel = power;
    _rightDriveMotor.powerLevel = power;

    // setup for closed-loop control
    if (power != 0)
    {
        self.driving = YES;

        // set the desired target driving speed in PWM "units"
        _headingController.targetLeftWheelVal = (power * _leftDriveMotor.pwmScalar);
        _headingController.targetRightWheelVal = _headingController.targetLeftWheelVal;

        // set current driving speed to match
        _headingController.leftWheelVal = _headingController.targetLeftWheelVal;
        _headingController.rightWheelVal=_headingController.targetRightWheelVal;

        // estimate where robot will be pointed when the setpoint is taken (this
        // is necessary because the IMU's sampling rate is far too slow when
        // compared to Romo's turn-rate capability)
        heading += (_robot.platformYawRate * (1/20.) * kLatencyFudgeFactor);
        // 20 Hz is the assumed update rate of the sensors.  I am leaving this
        // hard-coded as a reminder that it needs to be changed once the IMU
        // system is moved to a free-running format with a known frequency

        // keep results on [-180, 180] range (need to put this in
        // RMCoreCircleMath.h)
        if (heading > 180) {heading -= 360;}
        else if (heading < -180) {heading += 360;}

        // set heading & enable controller
        [_headingController setSetpoint:heading];
        _headingController.enabled = YES;
    }
    else
    {
        self.driving = NO;
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:RMCoreRobotDriveSpeedDidChangeNotification
                                                        object:self.robot
                                                      userInfo:nil];

    // alert user if command issued without IMU being active
    if (!self.robot.isRobotMotionEnabled && power != 0)
    {
        NSString *warningString = @"WARNING: 'Drive With Heading' command "
        "called with RobotMotion disabled; drive output is unpredictable";
        
        NSLog(@"%@", warningString);
    }
}

// drive on given heading at input speed
- (void)driveWithHeading:(float)heading speed:(float)speed
{
    // power as PWM value
    float power = [self calcPwmFromMetersPerSecond:speed];

    // power as [-1.,1.] value (using left motor is arbitrary; assumption is
    // that both left and right motors as the same)
    power /= _leftDriveMotor.pwmScalar;

    [self driveWithHeading:heading power:power];
}

// drive on current heading at input speed
- (void)driveWithPower:(float)power
{
    [self driveWithHeading:[self currentHeading] power:power];
}

// drive along arc with given radius (m) at  given speed (m)
- (void)driveWithRadius:(float)radius speed:(float)speed
{
    // calculate wheel speeds (in PWM values) and yaw rate (deg/s)
    [self setupRadiusDriveWithRadius:radius speed:speed];

    // make sure nothing else tries to control motors
    [self disableClosedLoopControllers];

    // issue motor commands
    _leftDriveMotor.powerLevel = (float)_radiusController.leftWheelVal / _leftDriveMotor.pwmScalar;
    _rightDriveMotor.powerLevel = (float)_radiusController.rightWheelVal / _rightDriveMotor.pwmScalar;

    // start controller
    if (speed != 0)
    {
        self.driving = YES;

        // test for special case:
        if (radius == RM_DRIVE_RADIUS_STRAIGHT)
        {   // use heading controller
            [self driveWithHeading:[self currentHeading] speed:speed ];
        }
        else
        {   // use radius controller
            _radiusController.enabled = YES;
        }
    }
    else
    {
        self.driving = NO;
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:RMCoreRobotDriveSpeedDidChangeNotification
                                                        object:self.robot
                                                      userInfo:nil];
    
    // alert user if command issued without IMU being active
    if (!self.robot.isRobotMotionEnabled && speed != 0)
    {
        NSString *warningString = @"WARNING: 'Drive With Radius' command "
         "called with RobotMotion disabled; drive output is unpredictable";
        
        NSLog(@"%@", warningString);
    }
}

// turn to the specified heading by driving along the specified arc at the
// specified speed and ensure that robot rotates though (roughly) sweepAngle
// (required to support arbitrarily large turns)
- (void)turnToHeading:(float)targetHeading
           withRadius:(float)radius
                speed:(float)speed
    forceShortestTurn:(BOOL)forceShortestTurn
           sweepAngle:(float)sweepAngle
      finishingAction:(RMCoreTurnFinishingAction)finishingAction
           completion:(RMCoreTurncompletion)completion
{
    // set completion callback (if provided)
    if (completion)
    {
        self.turnCompletion = completion;
    }

    // store target speed for later use by turn-to control heading
    self.turnToTargetSpeed = speed;

    if (forceShortestTurn)
    {
        // force radius to direction that will achieve goal with minimal turning
        float turnAngle = circleSubtract(targetHeading,
                                                    [self currentHeading] );
        radius = SIGN(turnAngle) * fabsf(radius);

        // for turn-in-place sign of speed dictates turn direction
        if (radius == RM_DRIVE_RADIUS_TURN_IN_PLACE)
        {
            if (SIGN(turnAngle) == CW)
            {
                speed = fabsf(speed);
            }
            else
            {
                speed = -fabsf(speed);
            }
        }
    }

    // if dirving backwards the radius direction must be reversed
    if (speed < 0)
    {
        radius = -radius;
    }

    // store sweet angle (which is used to ensure that when making large turns
    // the turn completes the proper number of cycles (e.g. a 720 degree turn
    // needs to turn one full circle _before_ it starts looking to stop at the
    // final heading (which is at 0 degrees)
    self.turnSweepAngle = sweepAngle;
    
    // start radius controller
    [self driveWithRadius:radius speed:speed];

    // setup and start turn-to controller
    self.turnToTargetHeading = targetHeading;
    self.turnFinishingAction = finishingAction;

    if(self.turnToControllerEnabled == NO)
    {
        self.turnToControllerEnabled = YES;
        self.turnToControllerReachedGoal = NO;
        dispatch_resume(self.turnToControlLoopTimer);
    }
    
    // alert user if command issued without IMU being active
    if (!self.robot.isRobotMotionEnabled && speed != 0)
    {
        NSString *warningString = @"WARNING: 'Turn To/By Drive' command "
        "called with RobotMotion disabled; drive output is unpredictable";
        
        NSLog(@"%@", warningString);
    }
}

// turn to the specified heading by driving along the specified arc at the
// specified speed
- (void)turnToHeading:(float)targetHeading
           withRadius:(float)radius
                speed:(float)speed
    forceShortestTurn:(BOOL)forceShortestTurn
      finishingAction:(RMCoreTurnFinishingAction)finishingAction
           completion:(RMCoreTurncompletion)completion
{
    // include sweep angle of zero since turnToHeading doesn't use this param
    [self turnToHeading:targetHeading
             withRadius:radius
                  speed:speed
      forceShortestTurn:forceShortestTurn
             sweepAngle:0
        finishingAction:finishingAction
             completion:completion ];
}

// turn to the specified heading by driving along the specified arc.  An optimal
// drive speed is determined automatically
- (void)turnToHeading:(float)targetHeading
           withRadius:(float)radius
      finishingAction:(RMCoreTurnFinishingAction)finishingAction
           completion:(RMCoreTurncompletion)completion
{
    // the angle through which the robot needs to turn
    float angle = circleSubtract(targetHeading, [self currentHeading]);

    // the optimal drive speed for the given rotation angle and drive radius
    // (e.g. if driving with a large radius the robot can drive with a higher
    // speed without risk of overshooting the target heading)
    float speed = [self calcDriveSpeedForTurnRadius:radius turnAngle:angle];

    // issue drive command
    [self turnToHeading:targetHeading
             withRadius:radius
                  speed:speed
      forceShortestTurn:YES
        finishingAction:finishingAction
             completion:completion ];
}

// turn by the specified angle by driving along the specified arc at the
// specified speed
- (void)turnByAngle:(float)angle
         withRadius:(float)radius
              speed:(float)speed
    finishingAction:(RMCoreTurnFinishingAction)finishingAction
         completion:(RMCoreTurncompletion)completion
{
    // calculate target heading
    float targetHeading = circleAdd([self currentHeading], angle);
    
    // force drive direction to obey the sign of the angle (where positive
    // angles cause counter-clockwise drive paths)
    if (SIGN(angle) > 0)
    {
        if (radius == RM_DRIVE_RADIUS_TURN_IN_PLACE)
        {
            // if turning in place direction is dictated by speed's sign
            speed = fabsf(speed);
        }
        else
        {
            // otherwise radius' sign controls direction
            radius = fabsf(radius);
        }
    }
    else
    {
        if (radius == RM_DRIVE_RADIUS_TURN_IN_PLACE)
        {
            // if turning in place direction is dictated by speed's sign
            speed = -fabsf(speed);
        }
        else
        {
            // otherwise radius' sign controls direction
            radius = -fabsf(radius);
        }
    }

    // issue drive command
    [self turnToHeading:targetHeading
             withRadius:radius
                  speed:speed
      forceShortestTurn:NO
             sweepAngle:fabsf(angle)
        finishingAction:finishingAction
             completion:completion ];
}

// turn by the specified angle by driving along the specified arc.  An optimal
// drive speed is determined automatically
- (void)turnByAngle:(float)angle
         withRadius:(float)radius
    finishingAction:(RMCoreTurnFinishingAction)finishingAction
         completion:(RMCoreTurncompletion)completion
{
    [self turnByAngle:angle
           withRadius:radius
                speed:[self calcDriveSpeedForTurnRadius:radius turnAngle:angle]
      finishingAction:finishingAction
           completion:completion ];
}

#pragma mark - drive command helpers

- (void)disableClosedLoopControllers
{
    // turn off closed-loop controllers
    _headingController.enabled = NO;
    [_headingController resetController];   // clear internal data

    _radiusController.enabled = NO;
    [_radiusController resetController];    // clear internal data

    if (self.turnToControllerEnabled == YES)
    {
        dispatch_suspend(self.turnToControlLoopTimer);
        self.turnToControllerEnabled = NO;

        if(self.turnToControllerReachedGoal == NO)
        {
            [self notifyCallerOfTurnToCancellation];
        }
    }
    
    // clear state
    self.turnToSlowDownStarted = NO;
    self.turnToElapsedStallTime = 0;
    self.turnSweptAngle = 0;
    self.turnPrevHeading = RM_MAX_HEADING + 1; // indicates initialization
                                               // required
    
    self.driving = NO;
}

- (void)notifyCallerOfTurnToCancellation
{
    if(self.turnCompletion)
    {
        // call external completion block to notify the "user" that the
        // mission has failed
        dispatch_async(dispatch_get_main_queue(), ^{
            self.turnCompletion(NO, self.currentHeading);
        });
    }
}

// figure out and set controller parameters base on command input pair
// (speed = m/s, radius = m)
- (void)setupRadiusDriveWithRadius:(float)radius speed:(float)speed
{
    float yawRate;      // yaw rate required of robot (rad/s)
    float leftSpeed;    // wheel speeds required (m/s)
    float rightSpeed;   //
    int leftPWM;        // associated commands (pwm values)
    int rightPWM;       //
    float R;            // radius to robot's outer wheel
    float r;            // radius to robot's inner wheel
    float radiiRatio;   // ratios of R to r

    // set target yaw rate
    if (radius == RM_DRIVE_RADIUS_TURN_IN_PLACE)
    {
        // using the wheel spacing is an arbitrary selection for radius (used
        // to avoid targeting an infinit yaw rate)
        yawRate = RAD2DEG(speed/(self.wheelSpacing/1.));
    }
    else
    {
        // typical usage
        yawRate = RAD2DEG(speed/radius);
    }

    // calculate the turn radius to the robot's inner and outer wheels
    r = radius - self.wheelSpacing/2.;
    R = radius + self.wheelSpacing/2.;

    // set target left and right wheel speeds
    if (radius == RM_DRIVE_RADIUS_TURN_IN_PLACE && speed != 0)
    {
        // set directly for special turn-in-place command
        leftSpeed = -speed;
        rightSpeed = speed;
    }
    else if (fabsf(radius) <= self.wheelSpacing/2. && speed != 0)
    {
        // set directly for special case where the given radius is smaller than
        // the distance between the wheels and the "center" of the robot
        if (speed >= 0)
        {
            // turning counter clockwise
            leftSpeed = 0;
            rightSpeed = speed;
        }
        else
        {
            // turning counter-clockwise
            leftSpeed = speed;
            rightSpeed = 0;
        }
    }
    else
    {
        // calculate wheel speeds needed to satify inputs
        radiiRatio = R/r;

        leftSpeed = (2. * speed)/(1. + radiiRatio);
        rightSpeed = leftSpeed * radiiRatio;
    }

    // set best-guess of PWM values needed to achieve target wheel speeds
    leftPWM = [self calcPwmFromMetersPerSecond:leftSpeed];
    rightPWM = [self calcPwmFromMetersPerSecond:rightSpeed];

    // adjust PWM value(s) were clamped (otherwise drive radius will be wrong)

    // adjustment timeout
    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
    CFAbsoluteTime kTimeout = .050;  // ms

    // variables needed for adjustment process
    float speedReducer = 0.;

    // keep adjust PWM until clipping is averted or timeout kicks in
    while(((abs(leftPWM) >= _leftDriveMotor.pwmScalar) ||
           (abs(rightPWM) >= _rightDriveMotor.pwmScalar) ) &&
           ((CFAbsoluteTimeGetCurrent() - startTime) < kTimeout) )
    {
        // adjust amount by which to reduce speed
        speedReducer += .1;  // m/s

        // make sure speed is adjust towards zero
        int leftDirectionScalar = 1;
        int rightDirectionScalar = 1;

        if (leftPWM >= 0)
        {
            leftDirectionScalar = -1;
        }
        if (rightPWM >= 0)
        {
            rightDirectionScalar = -1;
        }

        leftPWM = [self calcPwmFromMetersPerSecond:leftSpeed + (speedReducer * leftDirectionScalar)];
        rightPWM = [self calcPwmFromMetersPerSecond:rightSpeed + (speedReducer * rightDirectionScalar)];
    }

    // set controller parameters

    // set starting value of wheel motors
    _radiusController.leftWheelVal = leftPWM;
    _radiusController.rightWheelVal = rightPWM;

    // store target wheel speeds for future reference
    _radiusController.targetLeftWheelVal = leftPWM;
    _radiusController.targetRightWheelVal = rightPWM;

    // set the target yaw rate
    [_radiusController setSetpoint:yawRate];
}

// convert speed into PWM value using emperical calibration code
// (speed = m/s)
- (int) calcPwmFromMetersPerSecond:(float)speed
{
    // make sure 0 speed returns 0 pwm
    if (speed == 0.)
    {
        return 0;
    }

    // setup to return pwm with correct direction
    int signScalar = 1;
    if (speed < 0)
    {
        signScalar = -1;
    }

    // calibration equation
    int pwm = (int)(277.3 * fabsf(speed) + 51.7) * signScalar;

    // clamp pwm value
    int maxPWMVal = _leftDriveMotor.pwmScalar;

    if (pwm < -maxPWMVal)
    {
        pwm = -maxPWMVal;
    }
    if (pwm > maxPWMVal)
    {
        pwm = maxPWMVal;
    }

    return pwm;
}

// determine the fastest speed that won't cause position overshoot during for
// a turning drive with the given radius and angle parameter values
- (float)calcDriveSpeedForTurnRadius:(float)radius turnAngle:(float)angle
{
    const float kMinSpeed = .1;                 // minimum useful drive speed
    const float kMaxSpeed = .45;                // maximum useful drive speed
    const float kMaxSpeedProportionality = .1;  // empirically determined
    const float kMaxSpeedOffset = .2;           // empirically determined
    
    // limit the maximum speed proportionally based on the arc radius
    float maxSpeed = fabsf(radius) * kMaxSpeedProportionality + kMaxSpeedOffset;

    // limit the drive speed proportionally based on the distance the robot
    // needs to turn through
    float speed = (fabsf(angle) * ((maxSpeed - kMinSpeed)/360.)) + kMinSpeed;

    speed = MIN(speed, kMaxSpeed);
    
    return speed;
}

// provide current heading
- (float)currentHeading
{
    return self.robot.platformAttitude.yaw;
}

#pragma mark - Drive Controllers

// this controller attempts to maintain a target heading at a target drive-speed
- (void)setupHeadingController
{
    __weak RMCoreDifferentialDrive *weakSelf = self;
    
    // create the controller instance
    _headingController = [[RMCoreDriveController alloc]
                          initWithFrequency:HEADING_CONTROLLER_FREQUENCY
                          proportional:HEADING_CONTROLLER_P
                          integral:HEADING_CONTROLLER_I
                          derivative:HEADING_CONTROLLER_D

          // callback controller uses to get input for the controller
          inputSource:^float(void)
          {
              // get the current phone attitude in quaternion form
              return weakSelf.robot.platformAttitude.yaw;
          }

          // callback the controller uses to apply the control results
          outputSink:^(float controllerOutput,
                       RMControllerPIDState *pControllerState )
          {
              // convenience variables
              int lVal = weakSelf.headingController.leftWheelVal;
              int rVal = weakSelf.headingController.rightWheelVal;
              int targetVal = weakSelf.headingController.targetLeftWheelVal;
              // Note: use of left wheel value is arbitrary, want both sides to
              //       be the same

              // setup motor speed limits based on the target speed and a low-
              // end value that won't let the robot drive so much slowly than
              // commanded
              int maxVal = targetVal;
              int minVal = (int)(maxVal * .75);

              int directionScalar = 1;   // robot's direction (1 = forwards,
                                         //                    -1 = backwards)

              // apply controller output
              lVal += (int)controllerOutput;
              rVal -= (int)controllerOutput;

              // assure values remain without bounds
              // !!! REPLACE WITH CLAMP MACRO !!!
              if (abs(lVal) > abs(maxVal)) {lVal = maxVal;}
              if (abs(lVal) < abs(minVal)) {lVal = minVal;}
              if (abs(rVal) > abs(maxVal)) {rVal = maxVal;}
              if (abs(rVal) < abs(minVal)) {rVal = minVal;}

              // if the robot is driving straight (within 1 degree) then make
              // symmetric increase to wheel motor values
              if (fabsf(pControllerState->error) < STRAIGHT_DRIVE_TOLERANCE &&
                                                  (abs(lVal) < abs(maxVal) &&
                                                   abs(rVal) < abs(maxVal) ) )
              {
                  // make sure values are "increased" in the direction the
                  // robot is driving
                  if (targetVal < 0)
                  {
                      directionScalar = -1;
                  }

                  lVal += (1 * directionScalar);
                  rVal += (1 * directionScalar);
              }

              // check that controller wasn't disabled on another thread before
              // applying results
              if (weakSelf.headingController.enabled)
              {
                  // store for the future
                  weakSelf.headingController.leftWheelVal = lVal;
                  weakSelf.headingController.rightWheelVal = rVal;

                  // send off motor commands (as [-1.,1] power value)
                  weakSelf.leftDriveMotor.powerLevel = lVal / (float)weakSelf.leftDriveMotor.pwmScalar;
                  weakSelf.rightDriveMotor.powerLevel = rVal / (float)weakSelf.rightDriveMotor.pwmScalar;
              }
          }

          subtractionHandler:^float(float a, float b)
          {
              return circleSubtract(a, b);
          } ];
}

// this controller attempts to hit a target drive-arc and drive-speed
- (void)setupRadiusController
{
    __weak RMCoreDifferentialDrive *weakSelf = self;

    // create the controller instance
    _radiusController = [[RMCoreDriveController alloc]
                         initWithFrequency: RADIUS_CONTROLLER_FREQUENCY
                         proportional: RADIUS_CONTROLLER_P
                         integral: RADIUS_CONTROLLER_I
                         derivative: RADIUS_CONTROLLER_D

         inputSource:^float
         {
             return weakSelf.robot.platformYawRate;
         }

         outputSink:^(float controllerOutput,
                      RMControllerPIDState *pControllerState )
             {
             int lVal = weakSelf.radiusController.leftWheelVal;      // left wheel PWM
             int rVal = weakSelf.radiusController.rightWheelVal;     // right wheel PWM

             // apply controller output
             lVal += (int)controllerOutput;
             rVal -= (int)controllerOutput;

             // set scalars for wheel rotation directions
             int lDirection = 1;
             if (lVal < 0) {lDirection = -1;}

             int rDirection = 1;
             if (rVal < 0) {rDirection = -1;}

             // if the robot near the target yaw rate then make symmetric
             // change to wheel motors to move towards target speed

             if (fabsf(pControllerState->error) < 1 &&  // degrees/sec
                                 lVal != weakSelf.radiusController.targetLeftWheelVal )
             {
                 // make sure values are "increased" in the direction the robot
                 // is driving
                 int directionScalar = 1;
                 if (lVal > weakSelf.radiusController.targetLeftWheelVal)
                 {
                     directionScalar = -1;
                 }

                 lVal += (1 * directionScalar);
                 rVal -= (1 * directionScalar);
             }

             // make sure we don't roll over (seems highly unlikley to happen,
             // but capping it will result in less weird results than letting
             // it roll
             int internalPWMLimit = (int)(.8 * INT_MAX);

             // !!! REPLACE WITH CLAMP MACRO !!!
             if (lVal > internalPWMLimit)
             {
                 lVal = internalPWMLimit;
             }
             if (rVal > internalPWMLimit)
             {
                 rVal = internalPWMLimit;
             }
             // !!! REPLACE WITH CLAMP MACRO !!!

             // Note: Letting lVal & rVal go above the motor's max PWM limit
             //       makes it easier to drive towards the target wheel speeds
             //       because lVal & rVal can be adjusted in a symmetric way

             // check that controller wasn't diabled on another thread before
             // applying results
             if (weakSelf.radiusController.enabled)
             {
                 // store for the future
                 weakSelf.radiusController.leftWheelVal = lVal;
                 weakSelf.radiusController.rightWheelVal = rVal;

                 int maxPWMVal = weakSelf.leftDriveMotor.pwmScalar;
                 // Note: Using left motor is arbitrary; assuming both motors
                 //       are the same.

                 // assure values remain within bounds
                 // !!! REPLACE WITH CLAMP MACRO !!!
                 if (abs(lVal) > maxPWMVal)
                 {
                     lVal = maxPWMVal * lDirection;
                 }
                 if (abs(lVal) < 0)
                 {
                     lVal = 0 * lDirection;
                 }
                 if (abs(rVal) > maxPWMVal)
                 {
                     rVal = maxPWMVal * rDirection;
                 }
                 if (abs(rVal) < 0)
                 {
                     rVal = 0 * rDirection;
                 }
                 // !!! REPLACE WITH CLAMP MACRO !!!

                 // send off motor commands
                 weakSelf.leftDriveMotor.powerLevel = lVal / (float)weakSelf.leftDriveMotor.pwmScalar;
                 weakSelf.rightDriveMotor.powerLevel = rVal / (float)weakSelf.rightDriveMotor.pwmScalar;
             }
         }

         subtractionHandler:nil ];
}

// setup the queue & timer for the "turn-to" controller
- (void)setupTurnToController
{
    // percent off that the PID Controller frequency can be (assuming GCD holds to
    // this request...)
    const float kLeewayPercentage = 0.05;
    
    self.turnToControlLoopQueue = dispatch_queue_create("com.romotive.TurnToControllerQueue", DISPATCH_QUEUE_SERIAL);
    self.turnToControlLoopTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.turnToControlLoopQueue);
    
    double timerIntervalInNanoseconds = 1.0E9/TURN_TO_CONTROLLER_FREQUENCY;
    
    dispatch_source_set_timer(self.turnToControlLoopTimer,
                              dispatch_time(DISPATCH_TIME_NOW, 0),
                              timerIntervalInNanoseconds,
                              (kLeewayPercentage * timerIntervalInNanoseconds));
    
    __weak RMCoreDifferentialDrive *weakSelf = self;
    dispatch_source_set_event_handler(self.turnToControlLoopTimer, ^{
        [weakSelf controlTurningToHeading];
    } );
}

// this controller is used to adjust the yaw parameters of the radius controller
// in and effort to slow the robot down (while driving at a given radius) so
// that the target heading canbe reliably detected
- (void)controlTurningToHeading
{
    // all times are in seconds, angles in degrees, and yaw rates in deg/sec
    
    const float kLatencyFudgeFactor = .250; // this accounts for latency that
                                            // can become significant when
                                            // making estimates based on yaw
                                            // rate
    const float kSlowDownStartTime = 0.5;   // we should begin to reduce the
                                            // robot's yaw rate when we're this
                                            // close to reaching the target
    const float kSlowDownYawRate = 75.0;    // yaw rate to target when trying to
                                            // hone in on final heading
    const int kHeadingTolerance = 5;        // when heading is +/- this value
                                            // the target angle is considered
                                            // to be achieved
    const float kStallTimeThreshold = .75;  // if we haven't been turning (fast
                                            // enough) for this long, consider
                                            // the robot stuck
    const float kSweptAngleTolerance = 180; // Must be within this many degrees
                                            // in order to have the possibility
                                            // of being done (needed to allow
                                            // arbitrarily large turn commands)
    
    static float maxYawRate = 0;            // yaw rate that radius controller
                                            // was set at before this controller
                                            // started modifying it
    
    float heading;                          //
    float headingError;                     // degrees to go before reaching
                                            // target
    float yawRate;                          // new radius controller setpoint
    float remainingTime;                    // estimated time to complete turn
    float currentYawRate;                   // measured yaw rate right now
    BOOL sweepComplete = YES;               // indicates if an appropriate
                                            // amount of turning has happened
                                            // such that it's possible that the
                                            // final heading can be checked
    
    // find difference between current heading and target heading
    heading = [self currentHeading];
    headingError = circleSubtract(self.turnToTargetHeading, heading);
    
    // update angular progress
    if(self.turnPrevHeading <= RM_MAX_HEADING)
    {
        self.turnSweptAngle += fabsf(circleSubtract(heading,
                                                    self.turnPrevHeading));
    }
    self.turnPrevHeading = heading;
    
    // check if we've covered anywhere near as much of a turn as we should (this
    // if necessary for large turn angles) Note: 0 turnSweepAngle indicates that
    // there is no angle sweep requirement.
    if((self.turnSweepAngle - self.turnSweptAngle) > kSweptAngleTolerance)
    {
        sweepComplete = NO;
    }
    
    // find robot's current yaw rate
    currentYawRate = _robot.platformYawRate;

    
    if(sweepComplete)
    {
        // if error is +/- goal
        if (fabsf(headingError) < kHeadingTolerance)
        {
            // set flag showing we're succeeded
            self.turnToControllerReachedGoal = YES;
            
            // these finishing actions must be done here because the robot may
            // be rotating quickly to the point where handfuls of ms make a
            // difference.
            switch (self.turnFinishingAction)
            {
                case RMCoreTurnFinishingActionStopDriving:
                    [self driveWithPower:0];
                    break;
                case RMCoreTurnFinishingActionDriveForward:
                    [self driveWithHeading:self.turnToTargetHeading
                                     speed:fabsf(self.turnToTargetSpeed) ];
                    break;
                case RMCoreTurnFinishingActionDriveBackward:
                    [self driveWithHeading:self.turnToTargetHeading
                                     speed:-fabsf(self.turnToTargetSpeed) ];
                    break;
            }
        
            // indicate that a yaw rate slow down (as we approach the target
            // heading) is not in process
            self.turnToSlowDownStarted = NO;
            self.turnToElapsedStallTime = 0;
        
            if (self.turnCompletion)
            {
                // call external completion block to notify the "user" that the
                // mission has been accomplished
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.turnCompletion(YES, self.currentHeading);
                });
            }
        }
        else
        {
            // estimate how long it will take to reach the target heading given
            // the current yaw rate
            remainingTime = fabsf(headingError)/fabsf(currentYawRate);
            remainingTime -= kLatencyFudgeFactor;
            
            // if the target heading is within range...
            if (remainingTime < kSlowDownStartTime || self.turnToSlowDownStarted)
            {
                // "initialize"
                if (self.turnToSlowDownStarted == NO)
                {
                    // shouldn't turn any faster that the current yaw rate
                    maxYawRate = currentYawRate;
                    self.turnToSlowDownStarted = YES;
                }
                else
                {
                    // turn slowly while trying to hone in on final heading
                    yawRate = kSlowDownYawRate * SIGN(headingError);
                    
                    // update the radius controller and clear it's error data
                    _radiusController.setpoint = yawRate;
                    [_radiusController resetController];
                }
            }
        }
    }
    
    // test if robot isn't really turning right now
    if (fabsf(currentYawRate) < fabsf(_radiusController.setpoint)/2.)
    {
        self.turnToElapsedStallTime += 1./TURN_TO_CONTROLLER_FREQUENCY;
    }
    else
    {
        self.turnToElapsedStallTime = 0;
    }

    // if the robot hasn't been turning for a while, give up
    if (self.turnToElapsedStallTime > kStallTimeThreshold)
    {
        // stop robot (this will disable this controller)
        [self driveWithPower:0];
    }
}

@end
