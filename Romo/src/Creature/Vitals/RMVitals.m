//
//  RMVitals.m
//  Romo
//

#import "RMVitals.h"
#import <Romo/RMCore.h>
#import <Romo/RMShared.h>

// In 1 second @ (1.0,1.0), how many meters does Romo drive
#define metersPerSecond 0.75

// Any values lower than this don't propel Romo
#define minSpeedCutoff 0.275

// Duration of time until Romo becomes sleepy
#define sleepyDelay (180.0 + (float)(arc4random() % 80))

// Duration of time until Romo falls asleep
#define asleepDelay (30.0 + (float)(arc4random() % 30))

@interface RMVitals ()

@property (nonatomic, strong) NSTimer *wakefulnessTimer;

@property (nonatomic, readwrite) RMVitalsWakefulness wakefulness;
@property (nonatomic, readwrite) float odometer; // Distance in mm
@property (nonatomic) float robotSpeed;
@property (nonatomic) float previousSpeedUpdateTime;

- (void)applicationDidEnterBackground:(NSNotification *)notification;
- (void)becomeSleepy;
- (void)goToSleep;

@end

@implementation RMVitals

- (id)init
{
    self = [super init];
    if (self) {
        _wakefulnessEnabled = YES;
        _odometer = [[NSUserDefaults standardUserDefaults] floatForKey:@"romo-3 odometer reading"];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleRobotDidConnectNotification:)
                                                     name:RMCoreRobotDidConnectNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleRobotDidDisconnectNotification:)
                                                     name:RMCoreRobotDidDisconnectNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillEnterForeground:)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidEnterBackground:)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleRobotSpeedDidChangeNotification:)
                                                     name:RMCoreRobotDriveSpeedDidChangeNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleRobotTiltSpeedDidChangeNotification:)
                                                     name:RMCoreRobotHeadTiltSpeedDidChangeNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_wakefulnessTimer invalidate];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    [self wakeUp];
}

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
    [[NSUserDefaults standardUserDefaults] setFloat:_odometer forKey:@"romo-3 odometer reading"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self wakeUp];
}

#pragma mark - Private Properties

- (void)setWakefulness:(RMVitalsWakefulness)wakefulness
{
    if (_wakefulness != wakefulness) {
        _wakefulness = wakefulness;
        if ([self.delegate respondsToSelector:@selector(robotDidChangeWakefulness:)]) {
            [self.delegate robotDidChangeWakefulness:wakefulness];
        }
    }
}

- (void)setWakefulnessEnabled:(BOOL)wakefulnessEnabled
{
    if (_wakefulnessEnabled != wakefulnessEnabled) {
        _wakefulnessEnabled = wakefulnessEnabled;
        if (wakefulnessEnabled) {
            [self wakeUp];
        } else {
            [self.wakefulnessTimer invalidate];
        }
    }
}

#pragma mark - Updating

- (void)setRobotSpeed:(float)robotSpeed
{
    double currentTime = CACurrentMediaTime();
    double deltaTime = currentTime - self.previousSpeedUpdateTime;
    [self incrementOdometerForSpeed:_robotSpeed duration:deltaTime];

    _robotSpeed = robotSpeed;
    self.previousSpeedUpdateTime = currentTime;
}

- (void)handleRobotDidConnectNotification:(NSNotification *)notification
{
    self.robotSpeed = 0;
    [self wakeUp];
}

- (void)handleRobotDidDisconnectNotification:(NSNotification *)notification
{
    self.robotSpeed = 0;
    [self wakeUp];
}

- (void)handleRobotSpeedDidChangeNotification:(NSNotification *)notification
{
    RMCoreRobot<DriveProtocol> *robot = ((RMCoreRobot<DriveProtocol> *)notification.object);
    float robotSpeed = robot.speed;

    if (robotSpeed == RM_DRIVE_SPEED_UNKNOWN && [robot conformsToProtocol:@protocol(DifferentialDriveProtocol)]) {
        robotSpeed = (ABS(((RMCoreRobot<DifferentialDriveProtocol> *)robot).leftDriveMotor.powerLevel) +
                      ABS(((RMCoreRobot<DifferentialDriveProtocol> *)robot).rightDriveMotor.powerLevel))/2;
    }

    if (robotSpeed != 0) {
        [self wakeUp];
    }

    self.robotSpeed = robotSpeed;
}

- (void)handleRobotTiltSpeedDidChangeNotification:(NSNotification *)notification
{
    RMCoreRobot<DriveProtocol> *robot = ((RMCoreRobot<DriveProtocol> *)notification.object);
    float tiltSpeed = robot.speed;

    if (tiltSpeed != 0) {
        [self wakeUp];
    }
}

#pragma mark - Wakefulness --

- (void)wakeUp
{
    if (!self.wakefulnessEnabled) {
        return;
    }
    [self.wakefulnessTimer invalidate];
    self.wakefulnessTimer = [NSTimer scheduledTimerWithTimeInterval:sleepyDelay
                                                             target:self
                                                           selector:@selector(becomeSleepy)
                                                           userInfo:nil
                                                            repeats:NO];
    self.wakefulness = RMVitalsWakefulnessAwake;
}

- (void)becomeSleepy
{
    if (self.robotSpeed == 0) {
        self.wakefulness = RMVitalsWakefulnessSleepy;
        self.wakefulnessTimer = [NSTimer scheduledTimerWithTimeInterval:asleepDelay
                                                             target:self
                                                           selector:@selector(goToSleep)
                                                           userInfo:nil
                                                            repeats:NO];
    }
}

- (void)goToSleep
{
    self.wakefulness = RMVitalsWakefulnessAsleep;
}

#pragma mark - Odometry --

- (void)incrementOdometerForSpeed:(float)speed duration:(CFAbsoluteTime)durationInSeconds
{
    if (speed > minSpeedCutoff) {
        float currentMetersPerSecond = (speed - minSpeedCutoff)/(1.0 - minSpeedCutoff) * metersPerSecond;
        float currentMeters = currentMetersPerSecond * durationInSeconds;
        _odometer += currentMeters;
    }
}

@end
