//
//  RMFirmwareUpdateVC.m
//  Romo
//

#import "RMFirmwareUpdatingRobotController.h"
#import <QuartzCore/QuartzCore.h>
#import <Romo/RMProgrammingProtocol.h>
#import <Romo/RMCore.h>
#import <Romo/RMCoreRobot_Internal.h>
#import "RMAppDelegate.h"
#import "RMRomo.h"
#import "UIView+Additions.h"
#import "UIFont+RMFont.h"
#import "UIColor+RMColor.h"
#import "AFNetworking.h"
#import <Romo/UIDevice+Romo.h>

#ifdef DEBUG
#define RM_FIRMWARE_URL @"tbd"
#else
#define RM_FIRMWARE_URL @"tbd"
#endif //DEBUG

#ifdef DEBUG_FIRMWARE_UPDATING
#define LOG(...) DDLogWarn(__VA_ARGS__)
#else
#define LOG(...)
#endif //DEBUG_FIRMWARE_UPDATING

#define RM_SUCCESS_PREFIX @"http"

static const int maximumNumberOfFailedStarts = 4;
static const float kFirmwareUpdateVerificationTimeout = 5.0;
static const float kRobotResetVerificationTimeout = 5.0;

typedef enum {
    RMFirmwareUpdatingStateInit                   = 0,
    RMFirmwareUpdatingStateAsk                    = 1,
    RMFirmwareUpdatingStateUndock                 = 2,
    RMFirmwareUpdatingStateRedock                 = 3,
    RMFirmwareUpdatingStateWaitingForReset        = 4,
    RMFirmwareUpdatingStateWaitingForProgress     = 5,
    RMFirmwareUpdatingStateProgress               = 6,
    RMFirmwareUpdatingStateFinalUndock            = 7,
    RMFirmwareUpdatingStateFinalRedock            = 8,
    RMFirmwareUpdatingStateWaitingForVerification = 9,
    RMFirmwareUpdatingStateSuccess                = 10,
    RMFirmwareUpdatingStateFailure                = 11,
    RMFirmwareUpdatingStateNotNow                 = 12,
    RMFirmwareUpdatingStateBroken                 = 13,
    RMFirmwareUpdatingStatePrematureRemoval       = 14,
} RMFirmwareUpdatingState;

@interface RMFirmwareUpdatingRobotController () <RMVoiceDelegate>

@property (nonatomic, weak) RMCoreRobot *robot;
@property (nonatomic) RMFirmwareUpdatingState state;
@property (nonatomic) RMProgrammerState programmerState;

@property (nonatomic, strong) RMCoreRobotDataTransport *robotTransport;
@property (nonatomic, readwrite) BOOL hasUpdate;
@property (nonatomic) BOOL hasBrokenFirmware;
@property (nonatomic) int failedToStartCount;

@property (nonatomic, strong) NSString *deviceName;
@property (nonatomic, copy) NSString *updateURL;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) UILabel *progressLabel;
@property (nonatomic, strong) NSString *bootloaderVersion;
@property (nonatomic, strong) NSString *firmwareUpdateVersion;


@property (nonatomic, strong) NSTimer *updateVerificationTimer;
@property (nonatomic, copy) void (^updateSuccessVerificationCompletion)(BOOL verified);
@property (nonatomic, copy) void (^updateStartVerificationCompletion)(BOOL verified);
@property (nonatomic, copy) void (^robotResetCompletion)(BOOL reset);
@property (nonatomic) BOOL updateStarted;
@property (nonatomic) BOOL updateVerified;
@property (nonatomic) BOOL robotDidReset;
@property (nonatomic, getter=isWaitingForInterrupt) BOOL waitingToInterrupt;

#ifdef DEBUG_FIRMWARE_UPDATING
@property (nonatomic, strong) NSArray *states;
#endif

@end

@implementation RMFirmwareUpdatingRobotController

#pragma GCC diagnostic ignored "-Wundeclared-selector"
#pragma GCC diagnostic push

- (id)init
{
    self = [super init];
    if (self) {
        LOG(@"self: %@", self);
        
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleBadFirmwareNotification:)
                                                     name:RMCoreRobotDidConnectBrokenFirmwareNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleRobotDidDisconnectNotification:)
                                                     name:RMCoreRobotDidDisconnectBrokenFirmwareNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleUpdatingRobotDidConnectNotification:)
                                                     name:RMCoreRobotDidConnectFirmwareUpdatingNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleUpdatingRobotDidDisconnectNotification:)
                                                     name:RMCoreRobotDidDisconnectFirmwareUpdatingNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleRobotDidFailToStartProgrammingNotification:)
                                                     name:RMCoreRobotDidFailToStartProgrammingNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleProgrammerNotification:)
                                                     name:RMCoreRobotProgrammerNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleRobotControllerDidChangeNotification:)
                                                     name:RMRobotControllerDidBecomeActiveNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleRobotDidConnectNotification:)
                                                     name:RMCoreRobotDidConnectNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleRobotDidDisconnectNotification:)
                                                     name:RMCoreRobotDidDisconnectNotification
                                                   object:nil];
        
        
#ifdef DEBUG_FIRMWARE_UPDATING
        _states = [NSArray arrayWithObjects:@"Init",
                   @"Ask",
                   @"Undock",
                   @"Redock",
                   @"Waiting for Reset",
                   @"WaitingForProgress",
                   @"Progress",
                   @"FinalUndock",
                   @"FinalRedock",
                   @"WaitingForVerification",
                   @"Success",
                   @"Failure",
                   @"NotNow",
                   @"Broken",
                   @"PrematureRemoval",
                   nil];
#endif //DEBUG_FIRMWARE_UPDATING
    }
    return self;
}

- (void)controllerDidBecomeActive
{

}

- (void)controllerDidResignActive
{

}

- (void)dealloc
{
    LOG(@"self: %@", self);
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (RMRomoFunctionalities)initiallyActiveFunctionalities
{
    // only allow the character
    return RMRomoFunctionalityCharacter;
}

- (RMRomoInterruptions)initiallyAllowedInterruptions
{
    // never get interrupted
    return RMRomoInterruptionNone;
}

#pragma mark - Public Properties

- (void)checkForUpdates
{

}

- (void)ignoreUpdates
{
    _state = RMFirmwareUpdatingStateInit;
    self.hasUpdate = NO;
    self.hasBrokenFirmware = NO;
    self.failedToStartCount = 0;
}

#pragma mark - RMVoiceDelegate

- (void)userDidSelectOptionAtIndex:(int)optionIndex forVoice:(RMVoice *)voice
{
    [voice dismiss];
    
    if (self.state == RMFirmwareUpdatingStateAsk) {
        // "Install Now"
        if (optionIndex == 1) {
            // If the robot isn't softResettable, ask the user to undock
            if (!self.Romo.robot.supportsReset) {
                self.state = RMFirmwareUpdatingStateUndock;
            } else {
                self.state = RMFirmwareUpdatingStateWaitingForReset;
            }
            [self.Romo.robot updateFirmware:self.updateURL];
        } else {
            self.state = RMFirmwareUpdatingStateNotNow;
        }
    }
}

#pragma mark - Private Properties & Methods

- (void)setState:(RMFirmwareUpdatingState)state
{

}

- (void)setHasUpdate:(BOOL)hasUpdate
{

}

#pragma mark - Verifications

- (void)verifySuccesfulUpdateWithCompletion:(void (^)(BOOL verified))completion
{
    LOG(@"self: %@", self);
    self.updateVerified = NO;
    self.updateSuccessVerificationCompletion = completion;
    self.updateVerificationTimer = [NSTimer scheduledTimerWithTimeInterval:kFirmwareUpdateVerificationTimeout
                                                                    target:self
                                                                  selector:@selector(updateSuccessVerifyTimeout)
                                                                  userInfo:nil
                                                                   repeats:NO];
}

- (void)updateSuccessVerifyTimeout
{
    LOG(@"self: %@ verified? %d", self, self.updateVerified);
    if(self.updateSuccessVerificationCompletion) {
        self.updateSuccessVerificationCompletion(self.updateVerified);
        self.updateSuccessVerificationCompletion = nil;
    }
    [self.updateVerificationTimer invalidate];
    self.updateVerificationTimer = nil;
}

- (void)verifyProgrammerStartWithCompletion:(void (^)(BOOL verified))completion
{
    LOG(@"self: %@", self);
    self.updateStarted = NO;
    self.updateStartVerificationCompletion = completion;
    self.updateVerificationTimer = [NSTimer scheduledTimerWithTimeInterval:kFirmwareUpdateVerificationTimeout
                                                                    target:self
                                                                  selector:@selector(updateStartVerifyTimeout)
                                                                  userInfo:nil
                                                                   repeats:NO];
}

- (void)updateStartVerifyTimeout
{
    LOG(@"self: %@ verified? %d", self, self.updateStarted);
    if(self.updateStartVerificationCompletion) {
        self.updateStartVerificationCompletion(self.updateStarted);
        self.updateStartVerificationCompletion = nil;
    }
    
    [self.updateVerificationTimer invalidate];
    self.updateVerificationTimer = nil;
}

- (void)verifyResetWithCompletion:(void (^)(BOOL reset))completion
{
    LOG(@"self: %@", self);
    self.robotDidReset = NO;
    self.robotResetCompletion = completion;
    self.updateVerificationTimer = [NSTimer scheduledTimerWithTimeInterval:kRobotResetVerificationTimeout
                                                                    target:self
                                                                  selector:@selector(robotResetVerifyTimeout)
                                                                  userInfo:Nil
                                                                   repeats:NO];
}

- (void)robotResetVerifyTimeout
{
    LOG(@"self: %@", self);
    self.robotTransport.softResetting = NO;
    if(self.robotResetCompletion) {
        self.robotResetCompletion(self.robotDidReset);
        self.robotResetCompletion = nil;
    }
    
    [self.updateVerificationTimer invalidate];
    self.updateVerificationTimer = nil;
}


#pragma mark - Notifications

- (void)handleRobotDidConnectNotification:(NSNotification *)notification
{
    LOG(@"self: %@ robot: %@", self, notification.object);
    switch(self.state) {
        case RMFirmwareUpdatingStateInit:
            self.robot = notification.object;
            self.hasBrokenFirmware = NO;
            [self checkForUpdates];
            break;
            
        case RMFirmwareUpdatingStateWaitingForVerification:
            if([self.robotTransport.firmwareVersion isEqualToString:self.firmwareUpdateVersion]) {
                self.updateVerified = YES;
                if(self.updateVerificationTimer) {
                    [self.updateVerificationTimer fire];
                }
            }
            break;
            
        case RMFirmwareUpdatingStateRedock:
            self.state = RMFirmwareUpdatingStateWaitingForProgress;
            break;
            
        case RMFirmwareUpdatingStateFinalRedock:
            self.state = RMFirmwareUpdatingStateWaitingForVerification;
            break;
        
        case RMFirmwareUpdatingStatePrematureRemoval:
            self.state = RMFirmwareUpdatingStateWaitingForProgress;
            break;
            
        default: break;
    }
}

- (void)handleRobotDidDisconnectNotification:(NSNotification *)notification
{
    LOG(@"self: %@ robot: %@", self, notification.object);
    self.robot = nil;
    
    switch(self.state) {
        case RMFirmwareUpdatingStateAsk:
            self.hasBrokenFirmware = NO;
            self.failedToStartCount = 0;
            self.state = RMFirmwareUpdatingStateNotNow;
            break;
            
        case RMFirmwareUpdatingStateFinalUndock:
            self.state = RMFirmwareUpdatingStateFinalRedock;
            break;
            
        case RMFirmwareUpdatingStateBroken:
        case RMFirmwareUpdatingStateUndock:
            self.state = RMFirmwareUpdatingStateRedock;
            break;
            
        default:
            break;
    }
}

- (void)handleUpdatingRobotDidConnectNotification:(NSNotification *)notification
{
    LOG(@"self: %@ robot: %@", self, notification.object);
    self.robotDidReset = YES;
    if(self.updateVerificationTimer) {
        [self.updateVerificationTimer fire];
    }
    self.state = RMFirmwareUpdatingStateWaitingForProgress;
}

- (void)handleUpdatingRobotDidDisconnectNotification:(NSNotification *)notification
{
    LOG(@"self: %@ robot: %@", self, notification.object);
    self.robot = nil;
    self.programmerState = RMProgrammerStateError;
    
    switch(self.state) {
        case RMFirmwareUpdatingStateUndock:
            self.state = RMFirmwareUpdatingStateRedock;
            break;
            
        case RMFirmwareUpdatingStateProgress:
            [self.robotTransport stopUpdatingFirmware];
            self.state = RMFirmwareUpdatingStatePrematureRemoval;
            break;
            
        case RMFirmwareUpdatingStateBroken:
            self.state = RMFirmwareUpdatingStateRedock;
            break;
            
        case RMFirmwareUpdatingStateFinalUndock:
            self.state = RMFirmwareUpdatingStateFinalRedock;
            break;
            
        case RMFirmwareUpdatingStateWaitingForProgress:
            self.state = RMFirmwareUpdatingStatePrematureRemoval;
        default:
            break;
    }
}

- (void)handleRobotDidFailToStartProgrammingNotification:(NSNotification *)notification
{
    LOG(@"self: %@", self);
    self.failedToStartCount++;
    
    if(self.failedToStartCount <= maximumNumberOfFailedStarts) {
        self.state = RMFirmwareUpdatingStateUndock;
    } else {
        self.state = RMFirmwareUpdatingStateNotNow;
    }
}

- (void)handleBadFirmwareNotification:(NSNotification *)notification
{
    LOG(@"self: %@", self);
    self.robotTransport = notification.object;
    self.hasBrokenFirmware = YES;
 
    if(self.firmwareUpdateVersion) {
        self.state = RMFirmwareUpdatingStateBroken;
    } else {
        [self checkForUpdates];
    }
}
    
- (void)handleProgrammerNotification:(NSNotification *)notification
{
    RMProgrammerState state = ((NSNumber *)notification.userInfo[@"state"]).intValue;
    NSNumber *progress = notification.userInfo[@"progress"];
    self.progressView.progress = progress.floatValue;
    
    if(state != self.programmerState) {
        self.programmerState = state;
        switch(state) {
            case RMProgrammerStateInit:
            case RMProgrammerStateSentStart:
                LOG(@"programmer init");
                self.state = RMFirmwareUpdatingStateWaitingForProgress;
                break;
                
            case RMProgrammerStateProgramming:
                if(!self.updateStarted) {
                    LOG(@"programming");
                    self.updateStarted = YES;
                    if(self.updateVerificationTimer) {
                        [self.updateVerificationTimer fire];
                    }
                }
                self.state = RMFirmwareUpdatingStateProgress;
                break;
                
            case RMProgrammerStatePaused:
                break;
                
            case RMProgrammerStateVerifying:
                self.state = RMFirmwareUpdatingStateProgress;
                self.Romo.character.emotion = RMCharacterEmotionSleeping;
                self.progressLabel.text = NSLocalizedString(@"FirmwareUpdate-Verifying-Prompt", @"Verifying...");
                break;
                
            case RMProgrammerStateDone:
                [self.robotTransport stopUpdatingFirmware];
                LOG(@"programming finished. Bootloader %@", self.bootloaderVersion);
                self.state = RMFirmwareUpdatingStateWaitingForVerification;
                break;
                
            case RMProgrammerStateError:
                LOG(@"programmer error!");
            case RMProgrammerStateAbort:
                LOG(@"programmer aborting...");
                [self.robotTransport stopUpdatingFirmware];
                self.state = RMFirmwareUpdatingStateFailure;
                break;
        }
    }
}

- (void)handleRobotControllerDidChangeNotification:(NSNotification *)notification
{
    LOG(@"self: %@", self);
    RMRobotController *activeRobotController = notification.object;
    if (activeRobotController != self) {
        [self interruptRobotController];
    }
}

- (void)interruptRobotController
{
    RMAppDelegate *appDelegate = (RMAppDelegate *)[UIApplication sharedApplication].delegate;
    BOOL allowsFirmwareUpdatingInterruption = allowsRomoInterruption(RMRomoInterruptionFirmwareUpdating, appDelegate.robotController.Romo.allowedInterruptions);
    if (allowsFirmwareUpdatingInterruption && self.isWaitingForInterrupt) {
        self.waitingToInterrupt = NO;
        appDelegate.robotController = self;
    }
}

- (UIProgressView *)progressView
{
    if (!_progressView) {
        _progressView = [[UIProgressView alloc] initWithFrame:CGRectMake(20, self.view.height - 64, self.view.width - 40, 30)];
        _progressView.progressTintColor = [UIColor colorWithHue:0.90 saturation:0.98 brightness:0.91 alpha:1.0];
    }
    return _progressView;
}

- (UILabel *)progressLabel
{
    if (!_progressLabel) {
        _progressLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, self.view.height - 50, self.view.width - 40, 36)];
        _progressLabel.backgroundColor = [UIColor clearColor];
        _progressLabel.font = [UIFont voiceForRomoWithSize:24];
        _progressLabel.textAlignment = NSTextAlignmentCenter;
        _progressLabel.textColor = [UIColor whiteColor];
        _progressLabel.layer.shadowColor = [UIColor romoBlack].CGColor;
        _progressLabel.layer.shadowOffset = CGSizeMake(0, 2.5);
        _progressLabel.layer.shadowOpacity = 0.4;
        _progressLabel.layer.shadowRadius = 2.5;
        _progressLabel.layer.shouldRasterize = YES;
        _progressLabel.layer.rasterizationScale = 2.0;
    }
    return _progressLabel;
}

- (NSString *)deviceName
{
    if (!_deviceName) {
        UIDeviceFamily family = [UIDevice currentDevice].deviceFamily;
        switch (family) {
            case UIDeviceFamilyiPhone: _deviceName = @"iPhone"; break;
            case UIDeviceFamilyiPod: _deviceName = @"iPod"; break;
            case UIDeviceFamilyiPad: _deviceName = @"iPad"; break;
            default: break;
        }
    }
    return _deviceName;
}

#pragma GCC diagnostic pop

@end
