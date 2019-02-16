//
//  RMWiFiDriveManager.m
//  Romo
//

#import "RMWiFiDriveRobotController.h"
#import <Romo/RMMath.h>
#import "RMAppDelegate.h"
#import "RMSessionManager.h"
#import "RMRemoteControlSubscriber.h"
#import "RAVSubscriber.h"
#import "RMSessionManager.h"
#import "RMSession.h"
#import "RMCommandService.h"
#import "RMRomo.h"
#import "RMProgressManager.h"

/** Joystick: Only send new drive command if the joystick moved further than these distances */
#define MIN_ANGLE_CHANGE 3.5
#define MIN_DISTANCE_CHANGE 0.1

// must continually receive motor command via wi-fi remote controller within
// this time window in order to avoid timing out
#define REMOTE_CONTROL_CONNECTION_TIMEOUT_TIME  0.55  // seconds

/** After this many failed watchdog checks, the session is ended */
static const int watchdogFailureCount = 6;

NSString *const RMWiFiDriveRobotControllerSessionDidStart = @"RMWiFiDriveRobotControllerSessionDidStart";
NSString *const RMWiFiDriveRobotControllerSessionDidEnd = @"RMWiFiDriveRobotControllerSessionDidEnd";


@interface RMWiFiDriveRobotController () <RMSessionManagerDelegate, RMVideoImageCapturingDelegate, RMSessionDelegate, RMCommandDelegate>

@property (nonatomic, strong) RMSession *session;
@property (nonatomic, strong) RMRemoteControlSubscriber *remoteControlSubscriber;
@property (nonatomic, strong) RAVSubscriber *avSubscriber;
@property (nonatomic, strong) RMCommandService *commandService;
@property (nonatomic) BOOL didSendStartExpression;

/** Watchdog */
@property (nonatomic, strong) NSTimer *remoteControlWatchdog;
@property (nonatomic) BOOL remoteControlAlive;
@property (nonatomic) int timeoutCount;

/** Runs once this robot controller becomes active */
@property (nonatomic, copy) void (^activeCompletion)(void);

- (void)processSlidersLeft:(float)left right:(float)right;
- (void)processDPadSector:(RMDpadSector)sector;
- (void)processJoystickDistance:(float)distance angle:(float)angle;

/** If shit's gone down, let's abort and cleanup as best we can */
- (void)shutdownEverything;

@end

@implementation RMWiFiDriveRobotController

- (id)init
{
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleRomoDidChangeNameNotification:)
                                                     name:RMRomoDidChangeNameNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.remoteControlWatchdog invalidate];
}

- (void)controllerWillBecomeActive
{
    [super controllerWillBecomeActive];

    self.Romo.character.emotion = RMCharacterEmotionHappy;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(shutdownEverything)
                                                 name:UIApplicationDidEnterBackgroundNotification object:nil];
}

- (void)controllerDidBecomeActive
{
    [super controllerDidBecomeActive];
    
    self.Romo.character.emotion = RMCharacterEmotionHappy;
    
    if (self.activeCompletion) {
        self.activeCompletion();
        self.activeCompletion = nil;
    }

    [RMProgressManager sharedInstance].currentChapter = RMChapterRomoControl;
}

- (void)controllerDidResignActive
{
    [super controllerDidResignActive];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self shutdownEverything];
    [RMProgressManager sharedInstance].currentChapter = [RMProgressManager sharedInstance].newestChapter;
}

- (RMRomoFunctionalities)initiallyActiveFunctionalities
{
    return RMRomoFunctionalityEquilibrioception | RMRomoFunctionalityCharacter;
}

- (RMRomoInterruptions)initiallyAllowedInterruptions
{
    return RMRomoInterruptionDizzy | RMRomoInterruptionRomotion | RMRomoInterruptionSelfRighting | RMRomoInterruptionWakefulness;
}

- (void)setBroadcasting:(BOOL)broadcasting
{
    if (broadcasting != _broadcasting) {
        _broadcasting = broadcasting;
        
        if (broadcasting) {
            [self shutdownEverything];
            
            NSString *name = self.Romo ? self.Romo.name : [[NSUserDefaults standardUserDefaults] objectForKey:@"romo-3 romo name"];
            RMPeer *localIdentity = [[RMPeer alloc] initWithName:name];
            localIdentity.appVersion = RMRomoWiFiDriveVersion;
            
            [RMSessionManager shared].managerDelegate = self;
            [[RMSessionManager shared] startBroadcastWithIdentity:localIdentity];
            
        } else {
            [self.session stop];
            self.session = nil;
            [[RMSessionManager shared] stopBroadcasting];
        }
    }
}

- (void)shutdownEverything
{
    [self.session stopService:self.commandService];
    [self.commandService stop];
    
    [self.avSubscriber stop];
    self.avSubscriber = nil;
    
    [self.remoteControlSubscriber stop];
    self.remoteControlSubscriber = nil;
    
    self.session.delegate = nil;
    [self.session stop];
    self.session = nil;
    
    [self.remoteControlWatchdog invalidate];
}

#pragma mark - Notifications

- (void)handleRomoDidChangeNameNotification:(NSNotification *)notification
{
    if (self.isBroadcasting) {
        NSString *name = self.Romo ? self.Romo.name : [[NSUserDefaults standardUserDefaults] objectForKey:@"romo-3 romo name"];
        RMPeer *localIdentity = [[RMPeer alloc] initWithName:name];
        localIdentity.appVersion = RMRomoWiFiDriveVersion;
        
        [[RMSessionManager shared] updateIdentity:localIdentity];
    }
}

#pragma mark - SessionManager Delegates --

- (void)peerListUpdated:(NSArray *)peerList
{
}

- (void)sessionInitiated:(RMSession *)session
{
    if (!self.session) {
        self.session = session;
        self.session.delegate = self;
        [self.session start];
    }
}

#pragma mark - Session Delegates --

- (void)sessionBegan:(RMSession *)session
{
    [[RMSessionManager shared] stopBroadcasting];
    _broadcasting = NO;

    ((RMAppDelegate *)[UIApplication sharedApplication].delegate).robotController = self;

    self.commandService = [RMCommandService service];
    self.commandService.delegate = self;
    [self.session startService:self.commandService];


    [self.remoteControlWatchdog invalidate];
    self.remoteControlWatchdog = [NSTimer scheduledTimerWithTimeInterval:REMOTE_CONTROL_CONNECTION_TIMEOUT_TIME
                                                                  target:self
                                                                selector:@selector(checkRemoteControlWatchdog:)
                                                                userInfo:nil
                                                                 repeats:YES];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:RMWiFiDriveRobotControllerSessionDidStart object:self];
}

- (void)session:(RMSession *)session receivedService:(RMService *)service
{
    if ([service isKindOfClass:[RAVService class]]) {
        void (^activeCompletion)(void) = ^{
            self.avSubscriber = (RAVSubscriber *)[service subscribe];
            [self.avSubscriber start];
            self.avSubscriber.videoInput.imageCapturingDelegate = self;
        };
        if (self.isActive) {
            activeCompletion();
        } else {
            self.activeCompletion = activeCompletion;
        }
    } else if ([service isKindOfClass:[RMRemoteControlService class]]) {
        self.remoteControlSubscriber = (RMRemoteControlSubscriber *)[service subscribe];
        [self.remoteControlSubscriber start];
    }
}

- (void)session:(RMSession *)session finishedService:(RMService *)service
{
    if ([service isKindOfClass:[RAVService class]]) {
        [self.avSubscriber stop];
    } else if ([service isKindOfClass:[RMRemoteControlService class]]) {
        [self.remoteControlSubscriber stop];
    }
}

- (void)sessionEnded:(RMSession *)session
{
    [self shutdownEverything];
    self.broadcasting = YES;

    ((RMAppDelegate *)[UIApplication sharedApplication].delegate).robotController = ((RMAppDelegate *)[UIApplication sharedApplication].delegate).defaultController;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:RMWiFiDriveRobotControllerSessionDidEnd object:self];
}

#pragma mark - Video Input Delegate --

- (void)didFinishCapturingStillImage:(UIImage *)image
{
    [self.remoteControlSubscriber sendPicture:image];
}

#pragma mark - RMRomoDelegate

- (void)characterDidBeginExpressing:(RMCharacter *)character
{
    if (character.expression != RMCharacterExpressionNone) {
        [self.remoteControlSubscriber sendExpressionDidStart];
        self.didSendStartExpression = YES;
    }
}

- (void)characterDidFinishExpressing:(RMCharacter *)character
{
    if (self.didSendStartExpression) {
        [self.remoteControlSubscriber sendExpressionDidFinish];
        self.didSendStartExpression = NO;
    }
}

- (void)robotDidFlipToOrientation:(RMRobotOrientation)orientation
{
    if (orientation != RMRobotOrientationUpright) {
        [self.remoteControlSubscriber sendRobotDidFlipOver];
    }
}

#pragma mark - Command Service --

- (void)commandReceivedWithTiltMotorPower:(float)tiltMotorPower
{
    // got data from remote control source: set flag
    self.remoteControlAlive = YES;

    if (self.Romo.RomoCanDrive) {
        [self.Romo.robot tiltWithMotorPower:tiltMotorPower];
    }
}

- (void)commandReceivedWithDriveParameters:(DriveControlParameters)parameters
{
    static DriveControlParameters prevDriveParameters;

    BOOL newCommand = NO;

    self.remoteControlAlive = YES;

    // test if any of the command parameters changed
    if ((parameters.controlType != prevDriveParameters.controlType) ||
        (parameters.leftSlider != prevDriveParameters.leftSlider) ||
        (parameters.rightSlider != prevDriveParameters.rightSlider) ||
        (parameters.distance != prevDriveParameters.distance) ||
        (parameters.angle != prevDriveParameters.angle) ||
        (parameters.sector != prevDriveParameters.sector)) {
        newCommand = YES;
    }

    // issue drive if the command
    if (self.Romo.RomoCanDrive && newCommand) {
        switch(parameters.controlType) {
            case DRIVE_CONTROL_DPAD:
                [self processDPadSector:parameters.sector];
                break;

            case DRIVE_CONTROL_JOY:
                [self processJoystickDistance:parameters.distance angle:parameters.angle];
                break;

            case DRIVE_CONTROL_TANK:
                [self processSlidersLeft:parameters.leftSlider right:parameters.rightSlider];
                break;

            case DRIVE_CONTROL_NONE:
                break;

        }

        prevDriveParameters = parameters;
    }
}

- (void)commandReceivedWithExpression:(RMCharacterExpression)expression
{
    self.Romo.character.expression = expression;
}

- (void)commandReceivedToTakePicture
{
    [self.avSubscriber.videoInput captureStillImage];
}

- (void)checkRemoteControlWatchdog:(NSTimer *)timer
{
    if (self.remoteControlAlive) {
        self.remoteControlAlive = NO;
        self.timeoutCount = 1;
    } else if (self.timeoutCount < watchdogFailureCount) {
        // stop robot (because we haven't received a command from the remote
        // device in some time (commands should stream continually))
        [(RMCoreRobot <DriveProtocol> *)self.Romo.robot stopAllMotion];
        self.timeoutCount++;
    } else {
        [self sessionEnded:self.session];
    }
}

#pragma mark - Control Processing methods --

- (void)processSlidersLeft:(float)left right:(float)right
{
    const float kCloseCommandMargin = .05;  // percent off by which left/right
    const float kRadiusMultiplier = 1.0;
    float speed = (left + right)/2;

    if ([self.Romo.robot conformsToProtocol:@protocol(DifferentialDriveProtocol)]) {
        if ((left <= ((1. + kCloseCommandMargin) * right)) &&
            (left >= ((1. - kCloseCommandMargin) * right)) ) {
            [(RMCoreRobot<DriveProtocol> *)self.Romo.robot driveWithRadius:RM_DRIVE_RADIUS_STRAIGHT
                                                                     speed:speed];
        } else {
            [(RMCoreRobot<DifferentialDriveProtocol> *)self.Romo.robot driveWithLeftMotorPower:left
                                                                               rightMotorPower:right];
        }
    } else { // not a diff drive robot

        // TODO: Test and fix the following code.  It does not matter for Romo, but will matter
        // for non diff-drive robots
        int direction = (right >= left) ? 1 : -1;
        speed = (fabsf(left) + fabsf(right))/2 * direction;
        float radius = 0;

        if ((left <= ((1. + kCloseCommandMargin) * right)) &&
            (left >= ((1. - kCloseCommandMargin) * right)) ) {
            [(RMCoreRobot<DriveProtocol> *)self.Romo.robot driveWithRadius:RM_DRIVE_RADIUS_STRAIGHT
                                                                     speed:speed];
        } else {
            if (direction > 0) {
                radius = (1/(right - left)-.5) * kRadiusMultiplier;
            } else {
                radius = (1/(left - right)-.5) * kRadiusMultiplier;
            }
            [(RMCoreRobot<DriveProtocol> *)self.Romo.robot driveWithRadius:radius
                                                                     speed:speed];
        }
    }
}

- (void)processDPadSector:(RMDpadSector)sector
{
    const float kTurnInPlaceSpeed = 0.3;

    switch (sector) {
        case RMDpadSectorUp:
            [(RMCoreRobot<DriveProtocol> *)self.Romo.robot driveWithRadius:RM_DRIVE_RADIUS_STRAIGHT
                                                                     speed:RM_MAX_DRIVE_SPEED];
            break;

        case RMDpadSectorLeft:
            [(RMCoreRobot<DriveProtocol> *)self.Romo.robot driveWithRadius:RM_DRIVE_RADIUS_TURN_IN_PLACE
                                                                     speed:kTurnInPlaceSpeed];
            break;

        case RMDpadSectorRight:
            [(RMCoreRobot<DriveProtocol> *)self.Romo.robot driveWithRadius:RM_DRIVE_RADIUS_TURN_IN_PLACE
                                                                     speed:-kTurnInPlaceSpeed];
            break;

        case RMDpadSectorDown:
            [(RMCoreRobot<DriveProtocol> *)self.Romo.robot driveWithRadius:RM_DRIVE_RADIUS_STRAIGHT
                                                                     speed:-RM_MAX_DRIVE_SPEED];
            break;

        default:
            [(RMCoreRobot<DriveProtocol> *)self.Romo.robot stopDriving];
            break;
    }
}

- (void)processJoystickDistance:(float)distance angle:(float)angle
{
    static float previousAngle = -1;
    static float previousDistance = -1;

    // only update the drive command if they've changed their position enough since we last commanded
    if (previousAngle == -1 || previousDistance == -1 ||
        ABS(angle - previousAngle) > MIN_ANGLE_CHANGE || ABS(distance - previousDistance) > MIN_DISTANCE_CHANGE) {
        float direction = (angle >= 180) || (angle < 0) ? -1 : 1;
        float driveSpeed = powf(distance, 2) * direction;
        float driveRadius = tanf(DEG2RAD(-angle));

        [(RMCoreRobot<DriveProtocol> *)self.Romo.robot driveWithRadius:driveRadius
                                                                 speed:driveSpeed];
        previousAngle = angle;
        previousDistance = distance;
    }
}

@end
