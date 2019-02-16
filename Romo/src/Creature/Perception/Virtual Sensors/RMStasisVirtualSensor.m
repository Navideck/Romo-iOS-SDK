//
//  RMStasisVirtualSensor.m
//  Romo
//

#import "RMStasisVirtualSensor.h"
#import <Romo/RMVisualStasisDetectionModule.h>
#import <Romo/RMMath.h>
#import "RMRomo.h"

/** When the robot is driving at speeds lower than this, we ignore stasis events */
static const float minimumDriveSpeedToTriggerStasis = 0.55;

static const float stasisConfirmationDuration = 0.5;

@interface RMStasisVirtualSensor ()

@property (nonatomic, readwrite, getter=isInStasis) BOOL inStasis;

@property (nonatomic, strong) RMVisualStasisDetectionModule *stasisModule;

@property (nonatomic, strong) NSTimer *stasisConfirmationTimer;

@property (nonatomic, getter=isDriving) BOOL driving;

@end

@implementation RMStasisVirtualSensor

#pragma mark - Public Methods

- (void)beginGeneratingStasisNotifications
{
    self.inStasis = NO;
    [self setupNotificationSubscriptions];
    
    self.Romo.activeFunctionalities = enableFunctionality(RMRomoFunctionalityEquilibrioception, self.Romo.activeFunctionalities);
    [self.Romo.vision activateModule:self.stasisModule];
}

- (void)finishGeneratingStasisNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [self.stasisConfirmationTimer invalidate];
    self.stasisConfirmationTimer = nil;
    
    [self.Romo.vision deactivateModule:self.stasisModule];
    self.stasisModule = nil;
}

- (BOOL)isInStasis
{
    return _inStasis;
}

- (void)dealloc
{
    [self finishGeneratingStasisNotifications];
}

#pragma mark - Private Properties

- (RMVisualStasisDetectionModule *)stasisModule
{
    if (!_stasisModule) {
        _stasisModule = [[RMVisualStasisDetectionModule alloc] initWithVision:self.Romo.vision];
    }
    return _stasisModule;
}

#pragma mark - Private Methods

- (void)setupNotificationSubscriptions
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(stasisDetected)
                                                 name:@"RMStasisDetected"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(stasisDetected)
                                                 name:@"RMVisualStasisDetected"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(stasisCleared)
                                                 name:@"RMStasisCleared"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(stasisCleared)
                                                 name:@"RMVisualStasisCleared"
                                               object:nil];
}

- (void)stasisDetected
{
    if (!self.stasisConfirmationTimer.isValid) {
        float left = self.Romo.robot.leftDriveMotor.powerLevel;
        float right = self.Romo.robot.rightDriveMotor.powerLevel;
        float averagePowerLevel = (ABS(left) + ABS(right)) / 2.0;
        BOOL drivingFowardOrBackward = SIGN(left) == SIGN(right);
        BOOL robotIsTryingToDrive = self.Romo.robot.isDriving && (averagePowerLevel > minimumDriveSpeedToTriggerStasis);
        
        if (robotIsTryingToDrive && drivingFowardOrBackward) {
            self.stasisConfirmationTimer = [NSTimer timerWithTimeInterval:stasisConfirmationDuration
                                                                            target:self
                                                                          selector:@selector(stasisConfirmed)
                                                                          userInfo:nil
                                                                           repeats:NO];
            [[NSRunLoop mainRunLoop] addTimer:self.stasisConfirmationTimer forMode:NSRunLoopCommonModes];
        }
    }
}

- (void)stasisConfirmed
{
    self.inStasis = YES;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate virtualSensorDidDetectStasis:self];
    });
}

- (void)stasisCleared
{
    [self.stasisConfirmationTimer invalidate];
    self.inStasis = NO;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate virtualSensorDidLoseStasis:self];
    });
}

@end
