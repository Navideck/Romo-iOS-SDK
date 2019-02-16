//
//  RMActivityAction.m
//  Romo
//

#import "RMBehaviorArbiter.h"
#import <Romo/RMCore.h>
#import <Romo/RMBrightnessMeteringModule.h>
#import <Romo/RMMath.h>
#import <Romo/RMDispatchTimer.h>
#import <Romo/UIDevice+Romo.h>
#import "UIColor+RMColor.h"
#import "UIView+Additions.h"
#import "RMRomo.h"
#import "RMDockingRequiredVC.h"
#import "RMSoundEffect.h"
#import "RMAudioUtils.h"

static const float searchLookDownAngle = 90.0;
static const float searchLookUpAngle = 120.0;
static const float kLineLeakMax = 5.0;

@interface RMBehaviorArbiter () <RMObjectTrackingVirtualSensorDelegate, RMStasisVirtualSensorDelegate, RMBrightnessMeteringModuleDelegate>

/** Behavior Arbitration */
@property (nonatomic, strong) NSMutableDictionary *behaviorStates;
@property (nonatomic, readonly) RMActivityBehavior highestPriorityBehavior;
@property (nonatomic, strong) NSMutableDictionary *behaviorTimes;
@property (nonatomic) int behaviorStep;

/** Virtual Sensors */
@property (nonatomic, readwrite, strong) RMObjectTrackingVirtualSensor *objectTracker;
@property (nonatomic, readwrite, strong) RMStasisVirtualSensor *stasisVirtualSensor;
@property (nonatomic, strong) RMBrightnessMeteringModule *brightnessMeteringModule;

/** Chase Controller */
@property (nonatomic) RMCoreControllerPID *chaseController;
@property (nonatomic) float Kp;
@property (nonatomic) float Ki;
@property (nonatomic) float Kd;
@property (nonatomic) float setPoint;
@property (nonatomic) float objectHorizontalError;
@property (nonatomic) float trackPointX;
@property (nonatomic) float trackPointY;

@property (nonatomic, strong) NSMutableSet *tooDarkPrompts;
@property (nonatomic, strong) NSMutableSet *tooBrightPrompts;
@property (nonatomic, strong) NSMutableSet *idealBrightnessPrompts;

@property (nonatomic, strong) RMDispatchTimer *colorFillAnimationTimer;

@property (nonatomic, strong) RMDockingRequiredVC *dockingRequiredVC;

/** Line Follow */
@property (nonatomic) double lineLeakyIntegrator;
@property (nonatomic) double lastLineTime;

/** State */
@property (nonatomic, strong) void (^negativeDataCompletion)(BOOL);
@property (nonatomic, strong) void (^motionTriggeredColorTrainingCompletion)(BOOL);
@property (nonatomic, strong) void (^lineDetectionCompletion)(BOOL);
@property (nonatomic, readwrite, getter=isObjectTracking) BOOL objectTracking;
@property (nonatomic) BOOL cancellingObjectTracking;

#ifdef VISION_DEBUG
@property (nonatomic, strong) UIImageView *debugView;
#endif

@end

@implementation RMBehaviorArbiter

- (id)init
{
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleRobotDidConnectNotification:)
                                                     name:RMCoreRobotDidConnectNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleRobotDidDisconnectNotification:)
                                                     name:RMCoreRobotDidDisconnectNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleRobotDidFlipToOrientationNotification:)
                                                     name:RMRobotDidFlipToOrientationNotification
                                                   object:nil];
        _wavePrompt = NSLocalizedString(@"Chase-Wave-Prompt", @"Wave a color\nfor me to chase!");
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    self.negativeDataCompletion = nil;
    self.motionTriggeredColorTrainingCompletion = nil;
    
    if (_objectTracker) {
        [self.objectTracker stopMotionTriggeredColorTraining];
    }
    
    if (_stasisVirtualSensor) {
        [self.stasisVirtualSensor finishGeneratingStasisNotifications];
    }
    
    if (_objectTracker) {
        [self.objectTracker stopTracking];
        self.objectTracker = nil;
    }
    
    if (_brightnessMeteringModule) {
        [self.Romo.vision deactivateModule:self.brightnessMeteringModule];
        self.brightnessMeteringModule = nil;
    }
    
    [self.Romo.character setFillColor:nil percentage:0.0];
}

#pragma mark - Public Properties

- (void)setPrioritizedBehaviors:(NSArray *)prioritizedBehaviors
{
    _prioritizedBehaviors = prioritizedBehaviors;
    
    // Mark all behaviors as inactive with the last runtime reset
    _behaviorStates = [NSMutableDictionary dictionaryWithCapacity:prioritizedBehaviors.count];
    _behaviorTimes = [NSMutableDictionary dictionaryWithCapacity:prioritizedBehaviors.count];
    for (NSNumber *behaviorValue in prioritizedBehaviors) {
        _behaviorStates[behaviorValue] = @NO;
        _behaviorTimes[behaviorValue] = @(0);
    }
    
    if (self.Romo && !self.Romo.robot) {
        [self behavior:RMActivityBehaviorRequireDocking wantsToRun:YES];
    } else {
        [self behavior:RMActivityBehaviorRequireDocking wantsToRun:NO];
    }
}

- (void)setRomo:(RMRomo *)Romo
{
    _Romo = Romo;
    
    if (![self.behaviorStates[@(RMActivityBehaviorRequireDocking)] boolValue]) {
        if (self.prioritizedBehaviors.count && Romo && !Romo.robot) {
            [self behavior:RMActivityBehaviorRequireDocking wantsToRun:YES];
        } else {
            [self behavior:RMActivityBehaviorRequireDocking wantsToRun:NO];
        }
    }
    
    if (self.isLineFollowing) {
        self.lineLeakyIntegrator = kLineLeakMax;
        self.lastLineTime = currentTime();
    }
    
    _objectTracker.Romo = Romo;
    _stasisVirtualSensor.Romo = Romo;
}

#pragma mark - Public Methods

- (void)startLookingForNegativeDataWithCompletion:(void (^)(BOOL))completion
{
    self.Romo.activeFunctionalities = enableFunctionality(RMRomoFunctionalityVision, self.Romo.activeFunctionalities);
    self.negativeDataCompletion = completion;
    [self behavior:RMActivityBehaviorMotionTriggeredColorTrainingLookForNegativeData wantsToRun:YES];
}

- (void)startMotionTriggeredColorTrainingWithCompletion:(void (^)(BOOL))completion
{
    self.Romo.activeFunctionalities = enableFunctionality(RMRomoFunctionalityVision, self.Romo.activeFunctionalities);
    [self.Romo.character setFillColor:nil percentage:0.0];
    self.motionTriggeredColorTrainingCompletion = completion;
    [self.Romo.voice say:self.wavePrompt withStyle:RMVoiceStyleLLS autoDismiss:NO];
    
    self.lineFollowing = NO;
    
    int step = self.behaviorStep;
    
    double delayInSeconds = 0.75;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        if (step == self.behaviorStep) {
            [self.objectTracker startMotionTriggeredColorTraining];
        }
    });
}

- (void)stopMotionTriggeredColorTraining
{
    self.behaviorStep++;
    
    self.motionTriggeredColorTrainingCompletion = nil;
    [self behavior:RMActivityBehaviorMotionTriggeredColorTrainingFinished wantsToRun:NO];
    [self behavior:RMActivityBehaviorMotionTriggeredColorTrainingUpdated wantsToRun:NO];
    [self behavior:RMActivityBehaviorMotionTriggeredColorTrainingLookForNegativeData wantsToRun:NO];
    
    if (_objectTracker) {
        [self.objectTracker stopMotionTriggeredColorTraining];
    }
}

- (void)startTrackingObject
{
    [self startTrackingObjectWithTrainingData:self.objectTracker.trainingData];
}

- (void)startTrackingObjectWithTrainingData:(RMVisionTrainingData *)trainingData
{
    self.objectTracking = NO;
    self.cancellingObjectTracking = NO;
    
    // For Line Follow, only track the bottom third of the frame
    // For Chase, track the whole frame
    CGRect regionOfInterest = self.isLineFollowing ? CGRectMake(-1.0, 0.1, 2.0, 0.9) : CGRectMake(-1.0, -1.0, 2.0, 2.0);
    if (self.isLineFollowing) {
        self.lineLeakyIntegrator = kLineLeakMax;
        self.lastLineTime = currentTime();
    }
    
    self.objectTracker.allowAdaptiveBackgroundUpdates = self.isLineFollowing ? NO : YES;
    self.objectTracker.allowAdaptiveForegroundUpdates = self.isLineFollowing ? YES : NO;
    
    // Don't enable foreground updates on slow devices
    if (self.Romo.vision.isSlow) {
        self.objectTracker.allowAdaptiveForegroundUpdates = NO;
    }

    self.Romo.activeFunctionalities = enableFunctionality(RMRomoFunctionalityVision, self.Romo.activeFunctionalities);
    [self.objectTracker startTrackingObjectWithTrainingData:trainingData regionOfInterest:regionOfInterest];
    
    [RMSoundEffect playForegroundEffectWithName:threeTwoOneCountdownSound repeats:NO gain:1.0];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void){
        if (!self.cancellingObjectTracking) {
            self.objectTracking = YES;
        }
        self.cancellingObjectTracking = NO;
    });
}

- (void)stopTrackingObject
{
    self.objectTracking = NO;
    self.cancellingObjectTracking = YES;
    
    [self behavior:RMActivityBehaviorObjectFollow wantsToRun:NO];
    [self behavior:RMActivityBehaviorObjectCheckBehind wantsToRun:NO];
    [self behavior:RMActivityBehaviorObjectHeldOverHead wantsToRun:NO];
    [self behavior:RMActivityBehaviorObjectPossession wantsToRun:NO];
    [self behavior:RMActivityBehaviorObjectQuicklyFind wantsToRun:NO];
    [self behavior:RMActivityBehaviorObjectSearch wantsToRun:NO];
    [self behavior:RMActivityBehaviorLineSearch wantsToRun:NO];
    
#ifdef VISION_DEBUG
    [self.debugView removeFromSuperview];
    self.debugView = nil;
#endif
    
    [self.Romo.character setFillColor:nil percentage:0.0];
    
    if (_objectTracker) {
        [self.objectTracker stopTracking];
        [self.objectTracker stopMotionTriggeredColorTraining];
        self.objectTracker = nil;
    }
}

- (void)startDetectingStasis
{
    self.Romo.activeFunctionalities = enableFunctionality(RMRomoFunctionalityVision, self.Romo.activeFunctionalities);
    [self.stasisVirtualSensor beginGeneratingStasisNotifications];
}

- (void)stopDetectingStasis
{
    [self behavior:RMActivityBehaviorStasisRandomBounce wantsToRun:NO];
    
    if (_stasisVirtualSensor) {
        [self.stasisVirtualSensor finishGeneratingStasisNotifications];
    }
}

- (void)startBrightnessMetering
{
    self.Romo.activeFunctionalities = enableFunctionality(RMRomoFunctionalityVision, self.Romo.activeFunctionalities);
    [self.Romo.vision activateModule:self.brightnessMeteringModule];
}

- (void)stopBrightnessMetering
{
    [self behavior:RMActivityBehaviorTooBright wantsToRun:NO];
    [self behavior:RMActivityBehaviorTooDark wantsToRun:NO];
    
    if (_brightnessMeteringModule) {
        [self.Romo.vision deactivateModule:self.brightnessMeteringModule];
        self.brightnessMeteringModule = nil;
    }
}

#pragma mark - Private Methods

- (void)behavior:(RMActivityBehavior)behavior wantsToRun:(BOOL)wantsToRun
{
    if (![self.prioritizedBehaviors containsObject:@(behavior)]) {
        // Ignore behaviors without priorities
        return;
    }
    
    // Only do work if we're actually flipping the state
    BOOL changingStateOfBehavior = [self.behaviorStates[@(behavior)] boolValue] != wantsToRun;
    if (changingStateOfBehavior) {
        self.behaviorStates[@(behavior)] = @(wantsToRun);
        
        RMActivityBehavior previousBehavior = RMActivityBehaviorNone;
        __block RMActivityBehavior newBehavior = RMActivityBehaviorNone;
        BOOL shouldSwitch = NO;
        if (!wantsToRun && behavior == self.highestPriorityBehavior) {
            // If we're turning off our highest priority behavior, find the new highest priority behavior
            previousBehavior = self.highestPriorityBehavior;
            shouldSwitch = YES;
            [self.prioritizedBehaviors enumerateObjectsUsingBlock:^(NSNumber *behaviorValue, NSUInteger index, BOOL *stop) {
                if ([self.behaviorStates[behaviorValue] boolValue] == YES) {
                    newBehavior = [behaviorValue intValue];
                    *stop = YES;
                }
            }];
        } else if (wantsToRun) {
            // Check to see if we're faster than the rate-limit
            NSNumber *rateLimit = nil;
            if ((rateLimit = self.behaviorRateLimits[@(behavior)])) {
                double executionTime = currentTime();
                double lastExecutionTime = executionTime - [self.behaviorTimes[@(behavior)] doubleValue];
                if (lastExecutionTime < rateLimit.doubleValue) {
                    // If so, don't execute the new behavior
                    return;
                }
            }
            
            if (self.highestPriorityBehavior != RMActivityBehaviorNone) {
                // Check to see if the new behavior is higher priority than our current
                NSInteger priorityOfCurrentBehavior = self.prioritizedBehaviors.count - [self.prioritizedBehaviors indexOfObject:@(self.highestPriorityBehavior)];
                NSInteger priorityOfNewBehavior = self.prioritizedBehaviors.count - [self.prioritizedBehaviors indexOfObject:@(behavior)];
                
                if (priorityOfNewBehavior > priorityOfCurrentBehavior) {
                    previousBehavior = self.highestPriorityBehavior;
                    newBehavior = behavior;
                    shouldSwitch = YES;
                }
            } else {
                newBehavior = behavior;
                shouldSwitch = YES;
            }
        }
        
        if (shouldSwitch) {
            // Change behavior & let our delegate know
            _highestPriorityBehavior = newBehavior;
            [self stopExecutingBehavior:previousBehavior];
            [self executeBehavior:newBehavior];
            if (previousBehavior != RMActivityBehaviorNone) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate behaviorArbiter:self didFinishExecutingBehavior:previousBehavior];
                });
            }
        }
    } else if (behavior == self.highestPriorityBehavior && wantsToRun) {
        // If this is already the highest priority behavior, execute it again
        [self executeBehavior:behavior];
    }
}

- (void)executeBehavior:(RMActivityBehavior)behavior
{
    // Mark the execution time of this behavior
    self.behaviorTimes[@(behavior)] = @(currentTime());
    
    switch (behavior) {
        case RMActivityBehaviorMotionTriggeredColorTrainingLookForNegativeData: {
            [self lookForNegativeData];
            break;
        }
            
        case RMActivityBehaviorMotionTriggeredColorTrainingUpdated: {
            [self updateMotionTriggeredColorTrainingWithColor:self.objectTracker.trainingColor progress:self.objectTracker.trainingProgress];
            break;
        }
            
        case RMActivityBehaviorMotionTriggeredColorTrainingFinished: {
            [self finishMotionTriggeredColorTrainingWithColor:self.objectTracker.trainedColor data:self.objectTracker.trainingData];
            break;
        }
            
        case RMActivityBehaviorObjectFollow: {
            [self chaseObject:self.objectTracker.object];
            break;
        }
            
        case RMActivityBehaviorObjectQuicklyFind:
            [self quicklyFindObject:self.objectTracker.lastSeenObject];
            break;
            
        case RMActivityBehaviorObjectSearch:
            [self startSearchingForObject];
            break;
            
        case RMActivityBehaviorLineSearch:
            [self startSearchingForLine];
            break;
            
        case RMActivityBehaviorObjectCheckBehind:
            [self startCheckingBehind];
            break;
            
        case RMActivityBehaviorObjectHeldOverHead:
            [self reactToObjectHeldOverHead:self.objectTracker.object];
            break;
            
        case RMActivityBehaviorObjectPossession:
            [self reactToPossessionOfObject:self.objectTracker.object];
            break;
            
        case RMActivityBehaviorStasisRandomBounce:
            [self startRandomBounce];
            break;
            
        case RMActivityBehaviorRequireDocking:
            if (!_dockingRequiredVC) {
                if (self.dockingRequiredVC.isBeingDismissed) {
                    double delayInSeconds = 0.25;
                    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                        [self executeBehavior:behavior];
                    });
                } else if (!self.dockingRequiredVC.parentViewController) {
                    // Disable all behaviors when undocked
                    [self.behaviorStates removeAllObjects];
                    for (NSNumber *behaviorValue in self.prioritizedBehaviors) {
                        if (behaviorValue.intValue == behavior) {
                            self.behaviorStates[behaviorValue] = @YES;
                        } else {
                            self.behaviorStates[behaviorValue] = @NO;
                        }
                    }
                    
                    [self.delegate.viewController presentViewController:self.dockingRequiredVC animated:YES completion:nil];
                }
            }
            break;
            
        case RMActivityBehaviorSelfRighting: {
            [self selfRight];
            break;
        }
            
        case RMActivityBehaviorTooBright: {
            [self reactToTooBright];
            break;
        }
            
        case RMActivityBehaviorTooDark: {
            [self reactToTooDark];
            break;
        }
            
        case RMActivityBehaviorNone:
            break;
    }
}

- (void)stopExecutingBehavior:(RMActivityBehavior)behavior
{
    self.behaviorStep++;
    
    switch (behavior) {
        case RMActivityBehaviorMotionTriggeredColorTrainingLookForNegativeData: {
            if (self.negativeDataCompletion) {
                void (^completion)(BOOL) = self.negativeDataCompletion;
                self.negativeDataCompletion = nil;
                completion(NO);
            }
            break;
        }
            
        case RMActivityBehaviorMotionTriggeredColorTrainingFinished:
        case RMActivityBehaviorMotionTriggeredColorTrainingUpdated: {
            // If we're ending motion-triggered training, execute the completion and say it didn't finish
            if (self.motionTriggeredColorTrainingCompletion && self.highestPriorityBehavior != RMActivityBehaviorMotionTriggeredColorTrainingUpdated && self.highestPriorityBehavior != RMActivityBehaviorMotionTriggeredColorTrainingFinished) {
                void (^completion)(BOOL) = self.motionTriggeredColorTrainingCompletion;
                self.motionTriggeredColorTrainingCompletion = nil;
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO);
                });
            }
            
            [self.colorFillAnimationTimer stopRunning];
            self.colorFillAnimationTimer = nil;
            
            break;
        }
            
        case RMActivityBehaviorObjectSearch:
            [self stopSearchingForObject];
            break;
            
        case RMActivityBehaviorObjectFollow:
            [self stopChasing];
            break;
            
        case RMActivityBehaviorObjectQuicklyFind:
            [self stopChasing];
            break;
            
        case RMActivityBehaviorObjectCheckBehind:
            [self stopCheckingBehind];
            break;
            
        case RMActivityBehaviorStasisRandomBounce:
            [self stopRandomBounce];
            break;
            
        case RMActivityBehaviorRequireDocking: {
            if (self.dockingRequiredVC.isBeingPresented) {
                double delayInSeconds = 0.25;
                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                    [self stopExecutingBehavior:behavior];
                });
            } else {
                [self.delegate.viewController dismissViewControllerAnimated:YES completion:^{
                    self.dockingRequiredVC = nil;
                }];
            }
            break;
        }
            
        case RMActivityBehaviorSelfRighting:
            [self stopSelfRighting];
            break;
            
        case RMActivityBehaviorTooBright:
        case RMActivityBehaviorTooDark:
            [self stopReactingToBadBrightness];
            break;
            
        default: break;
    }
}

- (NSString *)nameForBehavior:(RMActivityBehavior)behavior
{
    switch (behavior) {
        case RMActivityBehaviorNone: return @"None";
        case RMActivityBehaviorMotionTriggeredColorTrainingLookForNegativeData: return @"NegativeData-MotionTriggeredTraining";
        case RMActivityBehaviorMotionTriggeredColorTrainingFinished: return @"Finish-MotionTriggeredTraining";
        case RMActivityBehaviorMotionTriggeredColorTrainingUpdated: return @"Update-MotionTriggeredTraining";
        case RMActivityBehaviorObjectCheckBehind: return @"CheckBehind";
        case RMActivityBehaviorObjectFollow: return @"ObjectFollow";
        case RMActivityBehaviorObjectHeldOverHead: return @"HeldOverHead";
        case RMActivityBehaviorObjectQuicklyFind: return @"QuicklyFind";
        case RMActivityBehaviorObjectSearch: return @"Search";
        case RMActivityBehaviorObjectPossession: return @"Possession";
        case RMActivityBehaviorStasisRandomBounce: return @"Free-RandomBounce";
        case RMActivityBehaviorRequireDocking: return @"RequireDocking";
        case RMActivityBehaviorTooBright: return @"TooBright";
        case RMActivityBehaviorTooDark: return @"TooDark";
        case RMActivityBehaviorSelfRighting: return @"SelfRighting";
        case RMActivityBehaviorLineSearch: return @"LineSearch";
    }
}

#pragma mark - Actions

- (void)lookForNegativeData
{
    int step = self.behaviorStep;
    
    void (^finishLookingForNegativeData)(void) = ^{
        if (self.negativeDataCompletion) {
            void (^completion)(BOOL) = self.negativeDataCompletion;
            self.negativeDataCompletion = nil;
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(YES);
            });
        }
        
        [self behavior:RMActivityBehaviorMotionTriggeredColorTrainingLookForNegativeData wantsToRun:NO];
    };
    
    [self.Romo.voice say:@"Hmm..." withStyle:RMVoiceStyleLLS autoDismiss:YES];
    
    if (self.Romo.robot) {
        enableRomotions(NO, self.Romo);
        [self.Romo.character setExpression:RMCharacterExpressionLookingAround withEmotion:RMCharacterEmotionCurious];
        
        if ([UIDevice currentDevice].isFastDevice) {
            // For fast devices, capture more negative training data
            [self.objectTracker captureNegativeTrainingDataWithCompletion:^{
                BOOL lookDownFirst = ABS(searchLookDownAngle - self.Romo.robot.headAngle) < ABS(searchLookUpAngle - self.Romo.robot.headAngle);
                [self.Romo.robot tiltToAngle:lookDownFirst ? self.Romo.robot.minimumHeadTiltAngle : self.Romo.robot.maximumHeadTiltAngle completion:^(BOOL success) {
                    if (self.behaviorStep == step) {
                        [self.objectTracker captureNegativeTrainingDataWithCompletion:^{
                            [self.Romo.robot tiltToAngle:lookDownFirst ? self.Romo.robot.maximumHeadTiltAngle : self.Romo.robot.minimumHeadTiltAngle completion:^(BOOL success) {
                                if (self.behaviorStep == step) {
                                    [self.objectTracker captureNegativeTrainingDataWithCompletion:^{
                                        [self.Romo.robot tiltToAngle:120.0 completion:^(BOOL success) {
                                            if (self.behaviorStep == step) {
                                                finishLookingForNegativeData();
                                            }
                                        }];
                                    }];
                                }
                            }];
                        }];
                    }
                }];
            }];
        } else {
            // For fast devices, capture more negative training data
            [self.Romo.robot tiltToAngle:self.Romo.robot.minimumHeadTiltAngle completion:^(BOOL success) {
                if (self.behaviorStep == step) {
                    [self.objectTracker captureNegativeTrainingDataWithCompletion:^{
                        [self.Romo.robot tiltToAngle:self.Romo.robot.maximumHeadTiltAngle completion:^(BOOL success) {
                            [self.objectTracker captureNegativeTrainingDataWithCompletion:^{
                                [self.Romo.robot tiltToAngle:120.0 completion:^(BOOL success) {
                                    if (self.behaviorStep == step) {
                                        finishLookingForNegativeData();
                                    }
                                }];
                            }];
                        }];
                    }];
                }
            }];
        }
        
    } else {
        [self.objectTracker captureNegativeTrainingDataWithCompletion:finishLookingForNegativeData];
    }
}

- (void)updateMotionTriggeredColorTrainingWithColor:(UIColor *)color progress:(float)progress
{
    self.Romo.character.emotion = RMCharacterEmotionCurious;
    
    static UIColor *goodColor = nil;
    static float lastProgress = 0.0;
    static float thisProgress = 0.0;
    static double lastTime = 0.0;
    
    if (![color isEqual:[UIColor clearColor]]) {
        goodColor = [color colorWithSaturation:1.0 brightness:1.0];
    }
    lastProgress = thisProgress;
    thisProgress = progress;
    lastTime = currentTime();
    [RMAudioUtils updateTrainingSoundAtProgress:thisProgress
                               withLastProgress:lastProgress];
    
    if (!_colorFillAnimationTimer) {
        goodColor = nil;
        lastProgress = 0.0;
        thisProgress = 0.0;
        lastTime = 0.0;
        
        __weak RMBehaviorArbiter *weakSelf = self;
        self.colorFillAnimationTimer.eventHandler = ^{
            static float lastPercentage = 0.0;
            float scale = [UIDevice currentDevice].isFastDevice ? 1.0 : 0.8;
            double dt = currentTime() - lastTime;
            float percentage = (thisProgress + scale * weakSelf.Romo.vision.targetFrameRate * dt * (thisProgress - lastProgress)) * 100.0;
            
            if (ABS(percentage - lastPercentage) > 2.0) {
                // Smooth out rough changes so we always animate smoothly
                percentage = (percentage + lastPercentage) / 2.0;
            }
            
            [weakSelf.Romo.character setFillColor:goodColor percentage:percentage];
            lastPercentage = percentage;
        };
        [self.colorFillAnimationTimer startRunning];
    }
}

- (RMDispatchTimer *)colorFillAnimationTimer
{
    if (!_colorFillAnimationTimer) {
        _colorFillAnimationTimer = [[RMDispatchTimer alloc] initWithQueue:dispatch_get_main_queue() frequency:30.0];
    }
    return _colorFillAnimationTimer;
}

- (void)finishMotionTriggeredColorTrainingWithColor:(UIColor *)color data:(RMVisionTrainingData *)trainingData
{
    [self.Romo.character setFillColor:[color colorWithSaturation:1.0 brightness:1.0] percentage:100.0];
    [self.Romo.voice dismiss];
    
    if (self.motionTriggeredColorTrainingCompletion) {
        void (^completion)(BOOL) = self.motionTriggeredColorTrainingCompletion;
        self.motionTriggeredColorTrainingCompletion = nil;
        completion(YES);
    }
    
    [self behavior:RMActivityBehaviorMotionTriggeredColorTrainingUpdated wantsToRun:NO];
    [self behavior:RMActivityBehaviorMotionTriggeredColorTrainingFinished wantsToRun:NO];
}

- (void)detectedLineWithColor:(UIColor *)lineColor
{
    [self.Romo.character setFillColor:lineColor percentage:100.0];
}

- (void)chaseObject:(RMBlob *)object
{
    if (!self.chaseController.isEnabled) {
        self.chaseController.enabled = YES;
        self.Romo.character.emotion = RMCharacterEmotionHappy;
    }
    
    self.trackPointX = object.centroid.x;
    self.trackPointY = object.centroid.y;
    self.objectHorizontalError = object.centroid.x;
    [self.chaseController triggerController];
    
    [self lookAtObject:object];
}

- (void)stopChasing
{
    self.chaseController.enabled = NO;
    [self.Romo.robot stopAllMotion];
    [self.Romo.character lookAtDefault];
}

- (void)quicklyFindObject:(RMBlob *)lostObject
{
    if (self.isLineFollowing) {
        // For line follow, assume the object didn't move as far
        lostObject.centroid = CGPointMake(lostObject.centroid.x * 0.5, lostObject.centroid.y);
    }
    [self chaseObject:lostObject];
}

- (void)startSearchingForObject
{
    int step = self.behaviorStep;
    
    [self.Romo.romotions stopRomoting];
    self.Romo.character.emotion = RMCharacterEmotionCurious;
    
    BOOL lookDownFirst = ABS(searchLookDownAngle - self.Romo.robot.headAngle) < ABS(searchLookUpAngle - self.Romo.robot.headAngle);
    
    [self.Romo.character lookAtPoint:RMPoint3DMake(0.0, lookDownFirst ? 1.0 : -1.0, 0.25) animated:YES];
    [self.Romo.robot tiltToAngle:lookDownFirst ? self.Romo.robot.minimumHeadTiltAngle : self.Romo.robot.maximumHeadTiltAngle
                      completion:^(BOOL success) {
                          if (self.behaviorStep == step && self.Romo.RomoCanDrive) {
                              [self.Romo.character lookAtPoint:RMPoint3DMake(0.0, lookDownFirst ? 0.2 : -0.4, 0.25) animated:YES];
                              [self.Romo.robot tiltToAngle:lookDownFirst ? searchLookDownAngle : searchLookUpAngle
                                                completion:^(BOOL success) {
                                                    if (self.behaviorStep == step && self.Romo.RomoCanDrive) {
                                                        float direction = arc4random_uniform(2) ? -1.0 : 1.0;
                                                        [self.Romo.character lookAtPoint:RMPoint3DMake(0.75 * direction, 0.0, 0.25) animated:YES];
                                                        [self.Romo.robot turnByAngle:360.0 * direction withRadius:0.0 speed:0.22 finishingAction:RMCoreTurnFinishingActionStopDriving
                                                                          completion:^(BOOL success, float heading) {
                                                                              if (self.behaviorStep == step && self.Romo.RomoCanDrive) {
                                                                                  [self.Romo.character lookAtPoint:RMPoint3DMake(0.0, lookDownFirst ? -0.4 : 0.2, 0.25) animated:YES];
                                                                                  [self.Romo.robot tiltToAngle:lookDownFirst ? searchLookUpAngle : searchLookDownAngle
                                                                                                    completion:^(BOOL success) {
                                                                                                        if (self.behaviorStep == step && self.Romo.RomoCanDrive) {
                                                                                                            [self.Romo.character lookAtPoint:RMPoint3DMake(-0.75 * direction, 0.0, 0.25) animated:YES];
                                                                                                            [self.Romo.robot turnByAngle:-360.0 * direction withRadius:0.0 speed:0.22
                                                                                                                         finishingAction:RMCoreTurnFinishingActionStopDriving
                                                                                                                              completion:^(BOOL success, float heading) {
                                                                                                                                  if (self.behaviorStep == step) {
                                                                                                                                      [self startSearchingForObject];
                                                                                                                                  }
                                                                                                                              }];
                                                                                                        }
                                                                                                    }];
                                                                              }
                                                                          }];
                                                    }
                                                }];
                          }
                      }];
}

- (void)startSearchingForLine
{
    int step = self.behaviorStep;
    
    [self.Romo.robot tiltToAngle:self.Romo.robot.minimumHeadTiltAngle completion:nil];
    
    // Turn around in a random fashion to help avoid repetitive loops from occuring
    float angle = 180.0 * (arc4random() % 2 ? -1 : 1);
    float radius = 0.12 * randFloat();
    float speed = 0.10 + 0.08 * randFloat();
    
    [self.Romo.robot turnByAngle:angle
                      withRadius:radius
                           speed:speed
                 finishingAction:RMCoreTurnFinishingActionStopDriving
                      completion:^(BOOL success, float heading) {
                          if (self.behaviorStep == step) {
                              [self startSearchingForLine];
                          }
                      }];
}

- (void)stopSearchingForObject
{
    [self.Romo.robot stopAllMotion];
    [self.Romo.character lookAtPoint:RMPoint3DMake(0.0, -0.1, 0.35) animated:YES];
    [self behavior:RMActivityBehaviorObjectSearch wantsToRun:NO];
    [self behavior:RMActivityBehaviorLineSearch wantsToRun:NO];
}

- (void)startCheckingBehind
{
    int step = self.behaviorStep;
    
    enableRomotions(NO, self.Romo);
    self.Romo.character.expression = RMCharacterExpressionWee;
    
    [self.Romo.character lookAtPoint:RMPoint3DMake(0.0, -1.0, 0.65) animated:YES];
    [self.Romo.robot tiltByAngle:self.Romo.robot.maximumHeadTiltAngle completion:^(BOOL success) {
        if (self.behaviorStep == step && self.Romo.RomoCanDrive) {
            [self.Romo.character lookAtPoint:RMPoint3DMake(1.0, -0.25, 0.45) animated:YES];
            [self.Romo.robot tiltToAngle:85.0 completion:nil];
            [self.Romo.robot turnByAngle:180.0 withRadius:0.0 speed:1.0 finishingAction:RMCoreTurnFinishingActionStopDriving
                              completion:^(BOOL success, float heading) {
                                  if (self.behaviorStep == step) {
                                      [self stopCheckingBehind];
                                  }
                              }];
        }
    }];
}

- (void)stopCheckingBehind
{
    [self.Romo.robot stopAllMotion];
    [self.Romo.character lookAtPoint:RMPoint3DMake(0.0, -0.1, 0.35) animated:YES];
    [self behavior:RMActivityBehaviorObjectCheckBehind wantsToRun:NO];
}

- (void)reactToObjectHeldOverHead:(RMBlob *)object
{
    NSArray *reactionExpressions = @[
                                     @(RMCharacterExpressionWant),
                                     @(RMCharacterExpressionWant),
                                     @(RMCharacterExpressionWant),
                                     @(RMCharacterExpressionWant),
                                     @(RMCharacterExpressionWant),
                                     @(RMCharacterExpressionWant),
                                     @(RMCharacterExpressionWant),
                                     @(RMCharacterExpressionYippee),
                                     @(RMCharacterExpressionYippee),
                                     @(RMCharacterExpressionYippee),
                                     @(RMCharacterExpressionExcited),
                                     @(RMCharacterExpressionBewildered),
                                     ];
    int seed = arc4random() % reactionExpressions.count;
    
    enableRomotions(YES, self.Romo);
    [self.Romo.character setExpression:[reactionExpressions[seed] intValue] withEmotion:RMCharacterEmotionExcited];
    [self behavior:RMActivityBehaviorObjectHeldOverHead wantsToRun:NO];
}

- (void)reactToPossessionOfObject:(RMBlob *)object;
{
    int seed = arc4random() % 4;
    
    [self.Romo.character lookAtPoint:RMPoint3DMake(0.0, 0.65, 0.0) animated:YES];
    
    if (seed == 0) {
        // Get a good sniff
        self.Romo.character.expression = RMCharacterExpressionSniff;
    } else if (seed == 1) {
        // Turn and fart on it
        float direction = arc4random() % 2 ? -1.0 : 1.0;
        [self.Romo.robot turnByAngle:direction * 75.0 withRadius:0.0 completion:^(BOOL success, float heading) {
            self.Romo.character.expression = RMCharacterExpressionFart;
        }];
    } else if (seed == 2) {
        // Some of the time, ignore possession
        [self behavior:RMActivityBehaviorObjectPossession wantsToRun:NO];
    } else if (seed == 3) {
        // Back up and kick it
        [self.Romo.robot driveBackwardWithSpeed:0.85];
        double delayInSeconds = 0.15;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self.Romo.robot driveForwardWithSpeed:1.0];
            double delayInSeconds = 0.65;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                [self.Romo.robot stopDriving];
            });
        });
    }
}

- (void)startRandomBounce
{
    int step = self.behaviorStep;
    
    self.Romo.character.emotion = RMCharacterEmotionIndifferent;
    
    if (self.Romo.RomoCanDrive) {
        BOOL left = arc4random() % 2;
        [self.Romo.robot driveWithLeftMotorPower:left ? -0.8 : -1.0 rightMotorPower:left ? -1.0 : -0.8];
        
        double delayInSeconds = 0.5;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            if (self.behaviorStep == step) {
                int seed = arc4random() % 100;
                if (seed < 8) {
                    // On rare occassions, smack into the screen
                    self.Romo.character.expression = RMCharacterExpressionSmack;
                } else if (seed < 12) {
                    self.Romo.character.expression = RMCharacterExpressionAngry;
                } else if (seed < 14) {
                    self.Romo.character.expression = RMCharacterExpressionHiccup;
                } else if (seed < 16) {
                    self.Romo.character.expression = RMCharacterExpressionYawn;
                }
                
                const float kBaseTurnAngle = 100.0; // degrees;
                const float kTurnAngleAdder = 260.0; // degrees;
                float turnDirection = arc4random() % 2 ? -1.0 : 1.0;
                
                [self.Romo.robot turnByAngle:turnDirection * (kBaseTurnAngle + (kTurnAngleAdder * randFloat()))
                                  withRadius:RM_DRIVE_RADIUS_TURN_IN_PLACE
                             finishingAction:RMCoreTurnFinishingActionStopDriving
                                  completion:^(BOOL success, float heading) {
                                      if (self.behaviorStep == step) {
                                          [self.Romo.robot driveForwardWithSpeed:1.0];
                                          
                                          double delayInSeconds = 0.5;
                                          dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                                          dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                                              if (self.behaviorStep == step) {
                                                  [self startRandomBounce];
                                              }
                                          });
                                      }
                                  }];
            }
        });
    }
}

- (void)stopRandomBounce
{
    [self.Romo.robot stopAllMotion];
}

- (void)lookAtObject:(RMBlob *)object
{
    if (self.isLineFollowing) {
        // When line following, look down at the line
        [self.Romo.character lookAtPoint:RMPoint3DMake(-0.36 * object.centroid.x, 0.65 + 0.15 * object.centroid.y, 0.42) animated:NO];
    } else {
        // When chasing, look at the object
        [self.Romo.character lookAtPoint:RMPoint3DMake(-0.45 * object.centroid.x, 0.65 * object.centroid.y, 0.30) animated:NO];
    }
}

- (void)selfRight
{
    switch (self.Romo.equilibrioception.orientation) {
        case RMRobotOrientationBackSide:
            [self.Romo.romotions flipFromBackSide];
            if (arc4random() % 2) {
                enableRomotions(NO, self.Romo);
                [self.Romo.character setExpression:RMCharacterExpressionLetDown withEmotion:RMCharacterEmotionSad];
            }
            break;
            
        case RMRobotOrientationFrontSide:
            [self.Romo.romotions flipFromFrontSide];
            if (arc4random() % 2) {
                enableRomotions(NO, self.Romo);
                [self.Romo.character setExpression:RMCharacterExpressionSad withEmotion:RMCharacterEmotionSad];
            }
            break;
            
        case RMRobotOrientationLeftSide:
        case RMRobotOrientationRightSide:
            enableRomotions(NO, self.Romo);
            self.Romo.character.expression = RMCharacterExpressionStartled;
            break;
            
        default:
            [self behavior:RMActivityBehaviorSelfRighting wantsToRun:NO];
            break;
    }
}

- (void)stopSelfRighting
{
    [self.Romo.romotions stopRomoting];
    self.Romo.character.emotion = RMCharacterEmotionHappy;
}

- (void)reactToTooBright
{
    int count = self.behaviorStep;
    
    [self.Romo.voice dismiss];
    RMCharacterExpression randomExpression = (arc4random() % 2) ? RMCharacterExpressionSad : RMCharacterExpressionLetDown;
    [self.Romo.character setExpression:randomExpression withEmotion:RMCharacterEmotionSad];
    
    double delayInSeconds = 1.5;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        if (self.behaviorStep == count) {
            [self sayRandomPromptFromPrompts:self.tooBrightPrompts];
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void){
                if (self.behaviorStep == count) {
                    [self.Romo.voice say:NSLocalizedString(@"Vision-TooBrightStatePrompt", @"Take me\nout of the sun!") withStyle:RMVoiceStyleLLS autoDismiss:NO];
                }
            });
        }
    });
}

- (void)reactToTooDark
{
    int count = self.behaviorStep;
    
    [self.Romo.voice dismiss];
    RMCharacterExpression randomExpression = (arc4random() % 2) ? RMCharacterExpressionScared : RMCharacterExpressionStartled;
    [self.Romo.character setExpression:randomExpression withEmotion:RMCharacterEmotionScared];
    
    double delayInSeconds = 1.5;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        if (self.behaviorStep == count) {
            [self sayRandomPromptFromPrompts:self.tooDarkPrompts];
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void){
                if (self.behaviorStep == count) {
                    [self.Romo.voice say:NSLocalizedString(@"tooDarkStatePrompt", @"Turn some\nlights on!") withStyle:RMVoiceStyleLLS autoDismiss:NO];
                }
            });
        }
    });
}

- (void)sayRandomPromptFromPrompts:(NSMutableSet *)prompts
{
    [self.Romo.voice dismiss];
    
    int seed = arc4random() % prompts.count;
    NSString *prompt = prompts.allObjects[seed];
    [prompts removeObject:prompt];
    [self.Romo.voice say:prompt withStyle:RMVoiceStyleLLS autoDismiss:YES];
}

- (void)stopReactingToBadBrightness
{
    self.Romo.character.emotion = RMCharacterEmotionHappy;
    [self.Romo.voice dismiss];
    [self sayRandomPromptFromPrompts:self.idealBrightnessPrompts];
}

#pragma mark - Private Properties

- (RMCoreControllerPID *)chaseController
{
    @synchronized(self) {
        if (!_chaseController) {
            self.setPoint = 0.0;
            float yBand = 0.0;

            if (self.isLineFollowing) {
                // Line Follow
                if (self.Romo.vision.isSlow) {
                    self.Kp = 0.6;
                    self.Ki = 0.0;
                    self.Kd = 0.01;
                } else {
                    self.Kp = 0.6;
                    self.Ki = 0.0;
                    self.Kd = 0.01;
                }
            } else {
                // Chase
                if (self.Romo.vision.isSlow) {
                    self.Kp = 0.86;
                    self.Ki = 0.0;
                    self.Kd = 0.024;
                    yBand = 0.20;
                } else {
                    self.Kp = 1.18;
                    self.Ki = 0.0;
                    self.Kd = 0.024;
                    yBand = 0.08;
                }
            }

            __weak RMBehaviorArbiter *weakSelf  = self;
            RMControllerPIDInputSourceHandler inputSource = ^float{
                return weakSelf.objectHorizontalError;
            };


            if (!self.isLineFollowing) {
                // Chasing
                RMControllerPIDOutputSinkHandler outputSink = ^(float PIDControllerOutput, RMControllerPIDState *contollerState) {
                    if (weakSelf.Romo.RomoCanDrive) {
                        if ((weakSelf.Romo.robot.headAngle >= weakSelf.Romo.robot.maximumHeadTiltAngle && weakSelf.trackPointY <= 0.0) ||
                            (weakSelf.Romo.robot.headAngle <= weakSelf.Romo.robot.minimumHeadTiltAngle && weakSelf.trackPointY >= 0.0) ||
                            (ABS(weakSelf.trackPointY) <= yBand)) {
                            // Don't try to tilt if we're going past hardware limits or if we're about centered
                            [weakSelf.Romo.robot stopTilting];
                        } else {
                            // Otherwise, tilt full speed in the direction of the object
                            [weakSelf.Romo.robot tiltWithMotorPower:weakSelf.trackPointY < 0 ? -1.0 : 1.0];
                        }

                        float constantPower = 0;
                        if (weakSelf.trackPointY < 0) {
                            // When the ball is over Romo's head, drive backward
                            constantPower = 1.0 - fabs(weakSelf.trackPointY) * 1.9;
                        } else {
                            // When the ball is right in front of Romo, slow down a bit because the ball can move quickest relative to us
                            constantPower = 1.0 - fabs(weakSelf.trackPointY) * 0.5;
                        }

                        float turnPower = PIDControllerOutput;
                        float leftDrivePower = (constantPower + turnPower);
                        float rightDrivePower = (constantPower - turnPower);
                        [weakSelf.Romo.robot driveWithLeftMotorPower:leftDrivePower rightMotorPower:rightDrivePower];
                    }
                };

                _chaseController = [[RMCoreControllerPID alloc] initWithProportional:self.Kp
                                                                            integral:self.Ki
                                                                          derivative:self.Kd
                                                                            setpoint:self.setPoint
                                                                         inputSource:inputSource
                                                                          outputSink:outputSink];
            } else {
                // When line following, don't use tilt and adjust speed based on curvature of the line
                RMControllerPIDOutputSinkHandler outputSink = ^(float PIDControllerOutput, RMControllerPIDState *contollerState) {
                    if (weakSelf.Romo.RomoCanDrive) {
                        static const float maximumHeadAngleDrift = 10.0;
                        if (ABS(weakSelf.Romo.robot.headAngle - self.Romo.robot.minimumHeadTiltAngle) > maximumHeadAngleDrift) {
                            // If Romo's head angle is off by too much, tilt all the way down
                            [weakSelf.Romo.robot tiltToAngle:self.Romo.robot.minimumHeadTiltAngle completion:nil];
                        }

                        // Slow down when the line is curved further
                        const float lineFollowSpeedReduction = 0.7;
                        float constantPower = (1.0 - fabs(weakSelf.trackPointX) * 0.75) * lineFollowSpeedReduction;

                        float turnPower = PIDControllerOutput;
                        float leftDrivePower = (constantPower + turnPower);
                        float rightDrivePower = (constantPower - turnPower);
                        [weakSelf.Romo.robot driveWithLeftMotorPower:leftDrivePower rightMotorPower:rightDrivePower];
                    }
                };

                _chaseController = [[RMCoreControllerPID alloc] initWithProportional:self.Kp
                                                                            integral:self.Ki
                                                                          derivative:self.Kd
                                                                            setpoint:self.setPoint
                                                                         inputSource:inputSource
                                                                          outputSink:outputSink];
            }
        }
    }
    return _chaseController;
}

- (RMObjectTrackingVirtualSensor *)objectTracker
{
    if (!_objectTracker) {
        _objectTracker = [[RMObjectTrackingVirtualSensor alloc] init];
        _objectTracker.delegate = self;
        _objectTracker.Romo = self.Romo;
    }
    return _objectTracker;
}

- (RMStasisVirtualSensor *)stasisVirtualSensor
{
    if (!_stasisVirtualSensor) {
        _stasisVirtualSensor = [[RMStasisVirtualSensor alloc] init];
        _stasisVirtualSensor.delegate = self;
        _stasisVirtualSensor.Romo = self.Romo;
    }
    return _stasisVirtualSensor;
}

- (RMBrightnessMeteringModule *)brightnessMeteringModule
{
    if (!_brightnessMeteringModule) {
        _brightnessMeteringModule = [[RMBrightnessMeteringModule alloc] initWithVision:self.Romo.vision];
        _brightnessMeteringModule.delegate = self;
    }
    return _brightnessMeteringModule;
}

- (RMDockingRequiredVC *)dockingRequiredVC
{
    if (!_dockingRequiredVC) {
        _dockingRequiredVC = [[RMDockingRequiredVC alloc] init];
        _dockingRequiredVC.showsDismissButton = NO;
        _dockingRequiredVC.showsPurchaseButton = NO;
    }
    return _dockingRequiredVC;
}

- (NSMutableSet *)tooBrightPrompts
{
    if (!_tooBrightPrompts || _tooBrightPrompts.count == 0) {
        NSArray *tooBrightPrompts = @[
                                      NSLocalizedString(@"Vision-TooBrightPrompt1", @"Whoa! It's\ntoo bright!"),
                                      NSLocalizedString(@"Vision-TooBrightPrompt2", @"I can't see\nin the sun!"),
                                      ];
        _tooBrightPrompts = [NSMutableSet setWithArray:tooBrightPrompts];
    }
    return _tooBrightPrompts;
}

- (NSMutableSet *)tooDarkPrompts
{
    if (!_tooDarkPrompts || _tooDarkPrompts.count == 0) {
        NSArray *tooDarkPrompts = @[
                                    NSLocalizedString(@"Vision-TooDarkPrompt1", @"How am I supposed to\nsee in the dark!"),
                                    NSLocalizedString(@"Vision-TooDarkPrompt2", @"You know I can't\nsee in the dark!"),
                                    NSLocalizedString(@"Vision-TooDarkPrompt3", @"Don't leave me\nin the dark!!!"),
                                    NSLocalizedString(@"Vision-TooDarkPrompt4", @"I don't like\nthe dark!!!"),
                                    ];
        _tooDarkPrompts = [NSMutableSet setWithArray:tooDarkPrompts];
    }
    return _tooDarkPrompts;
}

- (NSMutableSet *)idealBrightnessPrompts
{
    if (!_idealBrightnessPrompts || _idealBrightnessPrompts.count == 0) {
        NSArray *idealBrightnessPrompts = @[
                                            NSLocalizedString(@"Vision-IdealBrightnessPrompt1", @"Much better.\nNow I can see!"),
                                            NSLocalizedString(@"Vision-IdealBrightnessPrompt2", @"Thank you!"),
                                            NSLocalizedString(@"Vision-IdealBrightnessPrompt3", @"There we go!"),
                                            NSLocalizedString(@"Vision-IdealBrightnessPrompt4", @"Now I can see\nsome colors!")
                                            ];
        _idealBrightnessPrompts = [NSMutableSet setWithArray:idealBrightnessPrompts];
    }
    return _idealBrightnessPrompts;
}

#pragma mark - RMObjectTrackingVirtualSensorDelegate

- (void)virtualSensor:(RMObjectTrackingVirtualSensor *)virtualSensor didUpdateMotionTriggeredColorTrainingWithColor:(UIColor *)color progress:(float)progress
{
    [self behavior:RMActivityBehaviorMotionTriggeredColorTrainingUpdated wantsToRun:YES];
}

- (void)virtualSensor:(RMObjectTrackingVirtualSensor *)virtualSensor didFinishMotionTriggeredColorTraining:(RMVisionTrainingData *)trainingData
{
    [self behavior:RMActivityBehaviorMotionTriggeredColorTrainingFinished wantsToRun:YES];
}

- (void)virtualSensor:(RMObjectTrackingVirtualSensor *)virtualSensor didDetectObject:(RMBlob *)object
{
    if (self.isObjectTracking) {
        [self updateLeakyIntegratorWithLine:YES];
        [self behavior:RMActivityBehaviorObjectFollow wantsToRun:YES];
        [self behavior:RMActivityBehaviorObjectCheckBehind wantsToRun:NO];
        [self behavior:RMActivityBehaviorObjectQuicklyFind wantsToRun:NO];
        [self behavior:RMActivityBehaviorObjectSearch wantsToRun:NO];
        [self behavior:RMActivityBehaviorLineSearch wantsToRun:NO];
    }
}

- (void)virtualSensorFailedToDetectObject:(RMObjectTrackingVirtualSensor *)virtualSensor
{
    if (self.isObjectTracking) {
        [self updateLeakyIntegratorWithLine:NO];
    }
}

- (void)virtualSensorJustLostObject:(RMObjectTrackingVirtualSensor *)virtualSensor
{
    if (self.isObjectTracking) {
        [self behavior:RMActivityBehaviorObjectQuicklyFind wantsToRun:YES];
        [self behavior:RMActivityBehaviorObjectFollow wantsToRun:NO];
   
        [self updateLeakyIntegratorWithLine:NO];
    }
}

- (void)virtualSensorDidLoseObject:(RMObjectTrackingVirtualSensor *)virtualSensor
{
    if (self.isObjectTracking) {
        [self behavior:RMActivityBehaviorObjectSearch wantsToRun:YES];
        [self behavior:RMActivityBehaviorLineSearch wantsToRun:YES];
        [self behavior:RMActivityBehaviorObjectQuicklyFind wantsToRun:NO];
        [self behavior:RMActivityBehaviorObjectFollow wantsToRun:NO];
        
        [self updateLeakyIntegratorWithLine:NO];
    }
}

- (void)virtualSensor:(RMObjectTrackingVirtualSensor *)virtualSensor didStartPossessingObject:(RMBlob *)object
{
    [self behavior:RMActivityBehaviorObjectPossession wantsToRun:YES];
}

- (void)virtualSensor:(RMObjectTrackingVirtualSensor *)virtualSensor didStopPossessingObject:(RMBlob *)object
{
    [self behavior:RMActivityBehaviorObjectPossession wantsToRun:NO];
}

- (void)virtualSensorDidDetectObjectHeldOverHead:(RMObjectTrackingVirtualSensor *)virtualSensor
{
    [self behavior:RMActivityBehaviorObjectHeldOverHead wantsToRun:YES];
}

- (void)virtualSensorDidDetectObjectFlyOverHead:(RMObjectTrackingVirtualSensor *)virtualSensor
{
    [self behavior:RMActivityBehaviorObjectCheckBehind wantsToRun:YES];
}

- (void)virtualSensor:(RMObjectTrackingVirtualSensor *)virtualSensor didDetectLineWithColor:(UIColor *)lineColor
{
    [self detectedLineWithColor:self.objectTracker.trainedColor];
}

#pragma mark - RMStasisVirtualSensor

- (void)virtualSensorDidDetectStasis:(RMStasisVirtualSensor *)stasisVirtualSensor
{
    [self behavior:RMActivityBehaviorStasisRandomBounce wantsToRun:YES];
}

- (void)virtualSensorDidLoseStasis:(RMStasisVirtualSensor *)stasisVirtualSensor
{
    [self behavior:RMActivityBehaviorStasisRandomBounce wantsToRun:NO];
}

#pragma mark - RMBrightnessMeteringModuleDelegate

- (void)brightnessMeteringModule:(RMBrightnessMeteringModule *)module didDetectBrightnessChangeFromState:(RMVisionBrightnessState)previousState toState:(RMVisionBrightnessState)brightnessState
{
    [self behavior:RMActivityBehaviorTooBright wantsToRun:(brightnessState == RMVisionBrightnessStateTooBright)];
    [self behavior:RMActivityBehaviorTooDark wantsToRun:(brightnessState == RMVisionBrightnessStateTooDark)];
}

#pragma mark - Line Follow Helpers
- (void)updateLeakyIntegratorWithLine:(BOOL)sawLineThisFrame
{
    double now = currentTime();
    double timeDiff = now - self.lastLineTime;
    
    // update leaky integrator
    if (sawLineThisFrame) {
        self.lineLeakyIntegrator += (0.5 * timeDiff);
    } else {
        self.lineLeakyIntegrator -= timeDiff;
    }

    self.lastLineTime = now;
    
    // enforce range limits
    self.lineLeakyIntegrator = CLAMP(0.0, _lineLeakyIntegrator, kLineLeakMax);
    if (self.lineLeakyIntegrator == 0.0) {
        if ([self.delegate respondsToSelector:@selector(lineFollowIsFuckingUp)]) {
            [self.delegate lineFollowIsFuckingUp];
        }
    }
}

#pragma mark - Notifications

- (void)handleRobotDidConnectNotification:(NSNotification *)notification
{
    [self behavior:RMActivityBehaviorRequireDocking wantsToRun:NO];
}

- (void)handleRobotDidDisconnectNotification:(NSNotification *)notification
{
    [self behavior:RMActivityBehaviorRequireDocking wantsToRun:YES];
}

- (void)handleRobotDidFlipToOrientationNotification:(NSNotification *)notifcation
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self behavior:RMActivityBehaviorSelfRighting wantsToRun:YES];
    });
}

#pragma mark - Debug

#ifdef VISION_DEBUG
- (void)showDebugImage:(UIImage *)debugImage
{
    if (!_debugView) {
        _debugView = [[UIImageView alloc] initWithFrame:self.delegate.view.bounds];
        [self.delegate.view addSubview:_debugView];
    }
    self.debugView.image = debugImage;
    self.debugView.alpha = 0.2;
}
#endif

@end
