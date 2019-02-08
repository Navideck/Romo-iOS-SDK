//
//  RMCoreRobotRomo3.m
//  RMCore
//

#import "RMCoreRobotRomo3.h"
#import "RMCoreRobot_Internal.h"
#import "RMCoreRobotIdentification_Internal.h"
#import "RMCoreRobotVitals_Internal.h"
#import "RMCoreDifferentialDrive.h"
#import "RMCoreHeadTilt.h"
#import "RMCoreBumpDetector.h"
#import "RMCoreStasisDetector.h"
#import "RMCoreRobotMotion.h"
#import "RMCoreMotor.h"
#import "RMCoreMotor_Internal.h"
#import "RobotCommunicationProtocol.h"
#import "RMCoreRobotCommunication.h"
#import "RMCoreRobotCommunicationOld.h"
#import "RMCoreLEDs_Internal.h"
#import "Romo3Defs.h"

@interface RMCoreRobotRomo3 ()

@property (nonatomic, strong) RMCoreDifferentialDrive *drive;
@property (nonatomic, strong) RMCoreHeadTilt *tilt;
@property (nonatomic, strong) RMCoreBumpDetector *bumpDetector;
@property (nonatomic, strong) RMCoreStasisDetector *stasisDetector;
@property (nonatomic, strong, readwrite) RMCoreLEDs *LEDs;
@property (nonatomic, strong, readwrite) RMCoreRobotVitals *vitals;
@property (nonatomic, strong) RMCoreRobotMotion *robotMotion;

@end

@implementation RMCoreRobotRomo3

@synthesize leftDriveMotor = _leftDriveMotor;
@synthesize rightDriveMotor = _rightDriveMotor;
@synthesize tiltMotor = _tiltMotor;
@synthesize LEDs = _LEDs;
@synthesize communication = _communication;
@synthesize vitals = _vitals;
@synthesize driving = _driving;
@synthesize tilting = _tilting;
@synthesize speed = _speed;
@synthesize driveCommand = _driveCommand;
@synthesize robotMotionEnabled = _robotMotionEnabled;
@synthesize robotMotionDataUpdateRate = _robotMotionDataUpdateRate;
@synthesize deviceAccelerometer = _deviceAccelerometer;
@synthesize deviceGyroscope = _deviceGyroscope;
@synthesize deviceAcceleration = _deviceAcceleration;
@synthesize deviceGravity = _deviceGravity;
@synthesize deviceRotationRate = _deviceRotationRate;
@synthesize deviceAttitude = _deviceAttitude;
@synthesize platformAttitude = _platformAttitude;
@synthesize platformAcceleration = _platformAcceleration;
@synthesize platformYawRate = _platformYawRate;

- (RMCoreRobotRomo3 *)initWithTransport:(RMCoreRobotDataTransport *)transport
{
    self = [super initWithTransport:transport];
    if (self) {
        _leftDriveMotor = [[RMCoreMotor alloc] initWithAxis:(RMCoreMotorAxis)Romo3MotorAxisLeft
                                                  pwmScalar:255
                                      motorCurrentAvailable:YES
                                                      robot:self];
        
        _rightDriveMotor = [[RMCoreMotor alloc] initWithAxis:(RMCoreMotorAxis)Romo3MotorAxisRight
                                                   pwmScalar:255
                                       motorCurrentAvailable:YES
                                                       robot:self];
        
        _tiltMotor = [[RMCoreMotor alloc] initWithAxis:(RMCoreMotorAxis)Romo3MotorAxisTilt
                                             pwmScalar:255
                                 motorCurrentAvailable:YES
                                                 robot:self];
        
        _LEDs = [[RMCoreLEDs alloc] initWithPwmScalar:255];
        self.LEDs.robot = self;
        
        _robotMotion = [[RMCoreRobotMotion alloc] init];
        self.robotMotionEnabled = YES;
        
        _drive = [[RMCoreDifferentialDrive alloc] init];
        self.drive.robot = self;
        self.drive.wheelSpacing = TRACK_SPACING;
        
        _tilt = [[RMCoreHeadTilt alloc] init];
        self.tilt.robot = self;
        
//        _bumpDetector = [[RMCoreBumpDetector alloc] init];
//        self.bumpDetector.robot = self;
//        
//        _stasisDetector = [[RMCoreStasisDetector alloc] init];
//        self.stasisDetector.robot = self;
        
        if (transport) {
            _communication = [[RMCoreRobotCommunicationOld alloc] initWithTransport:transport];
        }
        
        _vitals = [[RMCoreRobotVitals alloc] initWithRobot:self];
    }
    return self;
}

#pragma mark - DriveProtocol Methods

- (BOOL)isDriving
{
    return self.drive.driving || _speed == RM_DRIVE_SPEED_UNKNOWN;
}

- (float)speed
{
    return _speed;
}

- (RMCoreDriveCommand)driveCommand
{
    return _driveCommand;
}

- (void)driveWithPower:(float)power
{
    if (power) {
        _speed = RM_DRIVE_SPEED_UNKNOWN;
    } else {
        _speed = 0.0;
    }
    
    _driveCommand = RMCoreDriveCommandWithPower;
    
    [self.drive driveWithPower:power];
}

- (void)driveWithHeading:(float)heading power:(float)power
{
    if (power) {
        _speed = RM_DRIVE_SPEED_UNKNOWN;
    } else {
        _speed = 0.0;
    }
    
    _driveCommand = RMCoreDriveCommandWithHeading;
    
    [self.drive driveWithHeading:heading power:power];
}

- (void)driveWithHeading:(float)heading speed:(float)speed
{
    _driveCommand = RMCoreDriveCommandWithHeading;
    _speed = speed;
    
    [self.drive driveWithHeading:heading speed:speed];
}

- (void)driveWithRadius:(float)radius speed:(float)speed
{
    _driveCommand = RMCoreDriveCommandWithRadius;
    _speed = speed;
    
    [self.drive driveWithRadius:radius speed:speed];
}

- (void)turnToHeading:(float)targetHeading
           withRadius:(float)radius
                speed:(float)speed
    forceShortestTurn:(BOOL)forceShortestTurn
      finishingAction:(RMCoreTurnFinishingAction)finishingAction
           completion:(RMCoreTurncompletion)completion
{
    [self.drive turnToHeading:targetHeading
                   withRadius:radius
                        speed:speed
            forceShortestTurn:forceShortestTurn
              finishingAction:finishingAction
                   completion:completion ];
    
    _driveCommand = RMCoreDriveCommandTurn;
}

- (void)turnToHeading:(float)targetHeading
           withRadius:(float)radius
      finishingAction:(RMCoreTurnFinishingAction)finishingAction
           completion:(RMCoreTurncompletion)completion
{
    [self.drive turnToHeading:targetHeading
                   withRadius:radius
              finishingAction:finishingAction
                   completion:completion ];
    
    _driveCommand = RMCoreDriveCommandTurn;
}

- (void)turnByAngle:(float)angle
         withRadius:(float)radius
         completion:(RMCoreTurncompletion)completion
{
    [self turnByAngle:angle
           withRadius:radius
      finishingAction:RMCoreTurnFinishingActionStopDriving
           completion:completion];

    _driveCommand = RMCoreDriveCommandTurn;
}

- (void)turnByAngle:(float)angle
         withRadius:(float)radius
              speed:(float)speed
    finishingAction:(RMCoreTurnFinishingAction)finishingAction
         completion:(RMCoreTurncompletion)completion
{
    [self.drive turnByAngle:angle
                 withRadius:radius
                      speed:speed
            finishingAction:finishingAction
                 completion:completion ];
    
    _driveCommand = RMCoreDriveCommandTurn;
}

- (void)turnByAngle:(float)angle
         withRadius:(float)radius
    finishingAction:(RMCoreTurnFinishingAction)finishingAction
         completion:(RMCoreTurncompletion)completion
{
    [self.drive turnByAngle:angle
                 withRadius:radius
            finishingAction:finishingAction
                 completion:completion ];
    
    _driveCommand = RMCoreDriveCommandTurn;
}

- (void)driveForwardWithSpeed:(float)speed
{
    [self driveWithRadius:RM_DRIVE_RADIUS_STRAIGHT speed:speed];
    
    _driveCommand = RMCoreDriveCommandForward;
}

- (void)driveBackwardWithSpeed:(float)speed
{
    [self driveForwardWithSpeed:-speed];
    
    _driveCommand = RMCoreDriveCommandBackward;
}

- (void)stopDriving
{
    // this sets the motor powers to zero and disables any tracks PID
    // controllers that may be running.
    [self driveWithHeading:0 power:0];
    
    _driveCommand = RMCoreDriveCommandStop;
}

#pragma mark - DifferentialDriveProtocol

- (void)driveWithLeftMotorPower:(float)leftMotorPower rightMotorPower:(float)rightMotorPower
{
    if (leftMotorPower || rightMotorPower) {
        _speed = RM_DRIVE_SPEED_UNKNOWN;
    } else {
        _speed = 0.0;
    }
    [self.drive driveWithLeftMotorPower:leftMotorPower rightMotorPower:rightMotorPower];

    _driveCommand = RMCoreDriveCommandWithPower;
}

#pragma mark - Tilt Commands

- (BOOL)isTilting
{
    return self.tilt.tilting;
}

- (void)tiltWithMotorPower:(float)motorPower
{
    [self.tilt tiltWithMotorPower:motorPower];
}

- (void)tiltByAngle:(float)angle completion:(void (^)(BOOL))completion
{
    [self.tilt tiltByAngle:angle completion:completion];
}

- (void)tiltToAngle:(float)angle completion:(void (^)(BOOL))completion
{
    [self.tilt tiltToAngle:angle completion:completion];
}

- (void)stopTilting
{
    [self.tilt stopTilting];
}

- (double)headAngle
{
    return self.tilt.headAngle;
}

- (double)minimumHeadTiltAngle
{
    return 75.0;
}

- (double)maximumHeadTiltAngle
{
    return 135.0;
}

- (void)stopAllMotion
{
    [self stopDriving];
    [self stopTilting];
}

#pragma mark - robot motion (intertial sensing) commands

- (void)setRobotMotionEnabled:(BOOL)robotMotionEnabled
{
    _robotMotionEnabled = robotMotionEnabled;
    self.robotMotion.enabled = robotMotionEnabled;
}

- (BOOL)isRobotMotionReady
{
    return self.robotMotion.ready;
}

- (void)setRobotMotionDataUpdateRate:(float)robotMotionDataUpdateRate
{
    _robotMotionDataUpdateRate = robotMotionDataUpdateRate;
    self.robotMotion.dataUpdateRate = robotMotionDataUpdateRate;
}

- (float)platformYawRate
{
    return self.robotMotion.platform.yawRate;
}

- (CMAcceleration)platformAcceleration
{
    return self.robotMotion.platform.acceleration;
}

- (RMCoreAttitude)platformAttitude
{
    return self.robotMotion.platform.attitude;
}

- (BOOL)takeDeviceReferenceAttitude
{
    if (self.isRobotMotionReady) {
        [self.robotMotion.platform takeReferenceAttitude];
        return YES;
    } else {
        return NO;
    }
}

- (CMAcceleration)deviceAccelerometer
{
    return self.robotMotion.iDevice.accelerometer;
}

- (CMRotationRate)deviceGyroscope
{
    return self.robotMotion.iDevice.gyroscope;
}

- (CMAcceleration)deviceAcceleration
{
    return self.robotMotion.iDevice.deviceAcceleration;
}

- (CMAcceleration)deviceGravity
{
    return self.robotMotion.iDevice.gravity;
}

- (CMRotationRate)deviceRotationRate
{
    return self.robotMotion.iDevice.rotationRate;
}

- (CMQuaternion)deviceAttitude
{
    return self.robotMotion.iDevice.attitude;
}

@end
