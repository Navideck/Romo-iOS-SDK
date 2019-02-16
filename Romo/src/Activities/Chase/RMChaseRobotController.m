//
//  RMChaseRobotController.m
//  Romo
//

#import "RMChaseRobotController.h"
#import <Romo/RMMath.h>
#import "RMBehaviorArbiter.h"
#import "RMAppDelegate.h"
#import "RMColorTrainingHelpRobotController.h"
#import "RMProgressManager.h"
#import "RMUnlockable.h"
#import "RMInteractionScriptRuntime.h"
#import <Romo/RMVisionObjectTrackingModule.h>
#import <Romo/RMVisionObjectTrackingModuleDebug.h>
#import "RMSoundEffect.h"
#import "RMChaseFillTrainingRobotController.h"
#import <Romo/UIDevice+Romo.h>

/** Amount of time between reacting to things being held over your head */
//static const float minimumHeldOverHeadReactionDelay = 12.0; // sec

/** Shows an extended intro the first time Chase is played */
static NSString *hasSeenChaseExtendedIntroKey = @"seenChaseIntro";

/** Amount of time Romo must chase before the comet is beaten */
static const float minimumAccumulatedChasePlayTime = 700.0; // sec

/** The total playtime for Chase, stored between sessions */
static NSString *const chaseAccumulatedPlaytimeKey = @"chaseAccumulatedPlaytime";

/** If we've played for at least the minimum playtime, this flag is marked to say we've unlocked the next content */
static NSString *const chaseHasAccumulatedEnoughPlaytimeKey = @"chaseHasAccumulatedEnoughPlaytime";

static NSString *introductionFirstTimeFileName = @"Chase-Introduction-First-Run";
static NSString *introductionFileName = @"Chase-Introduction";

@interface RMChaseRobotController () <RMBehaviorArbiterDelegate, RMVoiceDelegate, UIAlertViewDelegate>

/** Behavior & Action */
@property (nonatomic, strong) RMBehaviorArbiter *behaviorArbiter;

/** State */
@property (nonatomic) BOOL shouldShowIntroduction;
@property (nonatomic) double chasingStartTime;
@property (nonatomic) BOOL shouldTrain;

#ifdef CAPTURE_DEBUG_DATA_BUTTON
@property (nonatomic, strong) UIButton *captureButton;
@property (nonatomic, getter=isCapturing) BOOL capturing;
@property (nonatomic, strong) NSTimer *capturingTimer;
#endif

@end

@implementation RMChaseRobotController

+ (double)activityProgress
{
    double playtime = [[NSUserDefaults standardUserDefaults] doubleForKey:chaseAccumulatedPlaytimeKey];
    return CLAMP(0.0, playtime / minimumAccumulatedChasePlayTime, 1.0);
}

- (id)init
{
    self = [super init];
    if (self) {
        self.shouldShowIntroduction = YES;
        self.shouldTrain = YES;
    }
    return self;
}

- (void)controllerDidBecomeActive
{
    [super controllerDidBecomeActive];
    
    self.Romo.voice.delegate = self;
    
    BOOL shouldShowFirstRunIntroduction = ![[NSUserDefaults standardUserDefaults] boolForKey:hasSeenChaseExtendedIntroKey];
    
    if (shouldShowFirstRunIntroduction) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:hasSeenChaseExtendedIntroKey];
        [self startExtendedIntroduction];
    } else if (self.shouldShowIntroduction) {
        self.shouldShowIntroduction = NO;
        [self startIntroduction];
    } else {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(updateAccumulatedPlaytime)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
#ifdef DEBUG
        UITapGestureRecognizer *threeFingerTripleTap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                               action:@selector(handleMinimumPlayTimeReached)];
        threeFingerTripleTap.numberOfTouchesRequired = 3;
        threeFingerTripleTap.numberOfTapsRequired = 3;
        [self.view addGestureRecognizer:threeFingerTripleTap];
#endif

        [self triggerVoicePrompts];

        
        self.behaviorArbiter.Romo = self.Romo;
    }
    
#ifdef CAPTURE_DEBUG_DATA_BUTTON
    self.captureButton.center = CGPointMake(self.view.frame.size.width / 2.0, self.view.frame.size.height - 70);
    [self.view addSubview:self.captureButton];
#endif
}

- (void)controllerWillResignActive
{
    [super controllerWillResignActive];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self updateAccumulatedPlaytime];
    
    if (_behaviorArbiter) {
        self.behaviorArbiter.Romo = nil;
        self.behaviorArbiter = nil;
    }
    [self.Romo.character setFillColor:nil percentage:0.0];
}

#pragma mark - RMActivityRobotController overrides

- (RMRomoFunctionalities)initiallyActiveFunctionalities
{
    BOOL isFastEnoughForEquilibrioception = [UIDevice currentDevice].isFastDevice;
    return RMRomoFunctionalityCharacter | RMRomoFunctionalityVision | (isFastEnoughForEquilibrioception ? RMRomoFunctionalityEquilibrioception : 0);
}

- (RMRomoInterruptions)initiallyAllowedInterruptions
{
    return RMRomoInterruptionRomotion | RMRomoInterruptionDizzy;
}

- (NSSet *)initiallyActiveVisionModules
{
    return nil;
}

- (NSString *)title
{
    return NSLocalizedString(@"Chase-Title", @"Chase");
}

- (RMChapter)chapter
{
    return RMCometChase;
}

- (void)setAttentive:(BOOL)attentive
{
    if (attentive != super.attentive) {
        super.attentive = attentive;
        if (_behaviorArbiter) {
            if (attentive) {
                [self triggerVoicePrompts];
            } else {
                self.behaviorArbiter.Romo = self.Romo;
                
                if (self.behaviorArbiter.isObjectTracking) {
                    [self.Romo.voice dismiss];
                }
            }
        }
    }
}

- (void)triggerVoicePrompts
{
    if (self.behaviorArbiter.isObjectTracking) {
        self.behaviorArbiter.Romo = nil;
        [self.Romo.romotions stopRomoting];
        [self.Romo.robot stopAllMotion];
        [self.Romo.character lookAtPoint:RMPoint3DMake(0, 0, 0.45) animated:YES];
        [self.Romo.character mumble];
        
        [self.Romo.voice dismissImmediately];
        [self.Romo.voice ask:NSLocalizedString(@"Chase-Different-Color-Prompt", @"Chase a\ndifferent color?")
                 withAnswers:@[NSLocalizedString(@"Generic-Prompt-No", @"No"), NSLocalizedString(@"Chase-Different-Color-Yes", @"New Color")]];
    } else if (self.shouldTrain) {
        [self.Romo.character mumble];
        
        [self.Romo.voice dismissImmediately];
        [self.Romo.voice ask:NSLocalizedString(@"Chase-Object-Ready-Prompt", @"Do you have the\ncolorful object ready?")
                 withAnswers:@[NSLocalizedString(@"Generic-Prompt-No", @"No"), NSLocalizedString(@"Generic-Prompt-Yes", @"Yes")]];
    }
}

- (void)userDidSelectOptionAtIndex:(int)optionIndex forVoice:(RMVoice *)voice
{
    self.attentive = NO;
    [self.Romo.voice dismiss];
    
    // User selects Chase a New Color
    if (optionIndex == 1) {
        if (self.Romo.robot && (self.shouldTrain || self.behaviorArbiter.isObjectTracking)) {
            [self stopChasing];
            [self startTraining];
        }
    } else {
        if (self.Romo.robot && self.shouldTrain) {
            [self.Romo.voice say:NSLocalizedString(@"Chase-Grab-Ball-Prompt", @"Go grab a colorful ball\nfor me to chase!") withStyle:RMVoiceStyleLLS autoDismiss:NO];
            double delayInSeconds = 3.0;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                self.attentive = YES;
            });
        }
    }
}

- (BOOL)showsHelpButton
{
    return NO;
}


#pragma mark - RMBehaviorArbiterDelegate

- (void)behaviorArbiter:(RMBehaviorArbiter *)behaviorArbiter didFinishExecutingBehavior:(RMActivityBehavior)behavior
{
    switch (behavior) {
        case RMActivityBehaviorRequireDocking: {
            [self controllerDidBecomeActive];
            break;
        }
            
        default:
            break;
    }
}

- (UIViewController *)viewController
{
    return self;
}

#pragma mark - Private Methods

- (void)startTraining
{
    [self stopChasing];
    
    if (self.isActive) {
        __weak RMChaseRobotController *weakSelf = self;
        [self.behaviorArbiter startBrightnessMetering];
        
        [weakSelf.Romo.vision deactivateModuleWithName:RMVisionModule_FaceDetection];
        
        NSMutableArray *prioritizedBehaviorsCopy = [self.behaviorArbiter.prioritizedBehaviors mutableCopy];
        [prioritizedBehaviorsCopy removeObject:@(RMActivityBehaviorRequireDocking)];
        self.behaviorArbiter.prioritizedBehaviors = prioritizedBehaviorsCopy;
        
        RMAppDelegate *appDelegate = (RMAppDelegate*)[UIApplication sharedApplication].delegate;
        RMChaseFillTrainingRobotController *chaseTrainerRC = [[RMChaseFillTrainingRobotController alloc] initWithCovarianceScaling:1.0 completion:^(RMVisionTrainingData *trainingData) {
           
            if (trainingData) {
                weakSelf.shouldTrain = NO;
            }
            
            // We've finished training. Pop off the training robot controller
            [appDelegate popRobotController];

            if (trainingData) {
                weakSelf.behaviorArbiter.Romo = weakSelf.Romo;
                [weakSelf.behaviorArbiter startTrackingObjectWithTrainingData:trainingData];
                
                weakSelf.behaviorArbiter.prioritizedBehaviors = [weakSelf.behaviorArbiter.prioritizedBehaviors arrayByAddingObject:@(RMActivityBehaviorRequireDocking)];
                
                if ([UIDevice currentDevice].isFastDevice) {
                    [weakSelf.behaviorArbiter startDetectingStasis];
                }
                
                if (!weakSelf.chasingStartTime) {
                    // Log the start of the chase as the first time we're trained
                    weakSelf.chasingStartTime = currentTime();
                }
                
            } else {
                [self.delegate activityDidFinish:self];
            }
        }];
        
        [appDelegate pushRobotController:chaseTrainerRC];
    }
}

- (void)stopChasing
{
    [self.behaviorArbiter stopTrackingObject];
    [self.behaviorArbiter stopDetectingStasis];
    [self.behaviorArbiter stopBrightnessMetering];
}

- (void)startExtendedIntroduction
{
    // Show an extended backstory then help if this is the first time
    NSString *firstTimeIntroductionPath = [[NSBundle mainBundle] pathForResource:introductionFirstTimeFileName ofType:@"json"];
    RMInteractionScriptRuntime *runtime = [[RMInteractionScriptRuntime alloc] initWithJSONPath:firstTimeIntroductionPath];
    runtime.completion = ^(BOOL finished){
        [(RMAppDelegate *)[UIApplication sharedApplication].delegate popRobotController];
    };
    [(RMAppDelegate *)[UIApplication sharedApplication].delegate pushRobotController:runtime];
}

- (void)startIntroduction
{
    self.shouldShowIntroduction = NO;
    self.Romo.character.emotion = RMCharacterEmotionHappy;
    
    // Every time, we show an introduction for how to show Romo colors
    NSString *introductionPath = [[NSBundle mainBundle] pathForResource:introductionFileName ofType:@"json"];
    RMInteractionScriptRuntime *runtime = [[RMInteractionScriptRuntime alloc] initWithJSONPath:introductionPath];
    runtime.completion = ^(BOOL finished){
        [(RMAppDelegate *)[UIApplication sharedApplication].delegate popRobotController];
    };
    [(RMAppDelegate *)[UIApplication sharedApplication].delegate pushRobotController:runtime];
}

- (void)updateAccumulatedPlaytime
{
    if (self.chasingStartTime) {
        // Compute how long we chased and add that to the lifetime total
        double chasingPlaytime = currentTime() - self.chasingStartTime;
        double accumulatedPlaytime = chasingPlaytime + [[NSUserDefaults standardUserDefaults] doubleForKey:chaseAccumulatedPlaytimeKey];
        [[NSUserDefaults standardUserDefaults] setDouble:accumulatedPlaytime forKey:chaseAccumulatedPlaytimeKey];
        self.chasingStartTime = 0.0;
        
        if (accumulatedPlaytime >= minimumAccumulatedChasePlayTime) {
            BOOL hasBeatenChase = [[NSUserDefaults standardUserDefaults] boolForKey:chaseHasAccumulatedEnoughPlaytimeKey];
            if (!hasBeatenChase) {
                [[NSUserDefaults standardUserDefaults] setBool:YES forKey:chaseHasAccumulatedEnoughPlaytimeKey];
                [self handleMinimumPlayTimeReached];
            }
        }
    }
}

- (void)handleMinimumPlayTimeReached
{
    // Unlock Chapter 3 if not already done
    RMUnlockable *chapterThreeUnlockable = [[RMUnlockable alloc] initWithType:RMUnlockableChapter value:@(RMChapterThree)];
    [[RMProgressManager sharedInstance] achieveUnlockable:chapterThreeUnlockable];
    
    // And Mission 3-1
    RMUnlockable *missionOneUnlockable = [[RMUnlockable alloc] initWithType:RMUnlockableMission value:@"3-1"];
    [[RMProgressManager sharedInstance] achieveUnlockable:missionOneUnlockable];
}

- (void)handleSpaceButtonTouch:(id)sender
{
    [self.delegate activityDidFinish:self];
}

#pragma mark - Private Properties

- (RMBehaviorArbiter *)behaviorArbiter
{
    if (!_behaviorArbiter) {
        _behaviorArbiter = [[RMBehaviorArbiter alloc] init];
        _behaviorArbiter.delegate = self;
        if ([UIDevice currentDevice].isFastDevice) {
            // On fast devices, enable fancier features like stasis, self-righting, etc.
            _behaviorArbiter.prioritizedBehaviors = @[
                                                      @(RMActivityBehaviorRequireDocking),
                                                      @(RMActivityBehaviorSelfRighting),
                                                      @(RMActivityBehaviorTooDark),
                                                      @(RMActivityBehaviorTooBright),
                                                      @(RMActivityBehaviorMotionTriggeredColorTrainingLookForNegativeData),
                                                      @(RMActivityBehaviorMotionTriggeredColorTrainingFinished),
                                                      @(RMActivityBehaviorMotionTriggeredColorTrainingUpdated),
                                                      @(RMActivityBehaviorStasisRandomBounce),
                                                      @(RMActivityBehaviorObjectPossession),
                                                      @(RMActivityBehaviorObjectHeldOverHead),
                                                      @(RMActivityBehaviorObjectFollow),
                                                      @(RMActivityBehaviorObjectCheckBehind),
                                                      @(RMActivityBehaviorObjectSearch),
                                                      @(RMActivityBehaviorObjectQuicklyFind),
                                                      ];
        } else {
            _behaviorArbiter.prioritizedBehaviors = @[
                                                      @(RMActivityBehaviorRequireDocking),
                                                      @(RMActivityBehaviorTooDark),
                                                      @(RMActivityBehaviorTooBright),
                                                      @(RMActivityBehaviorMotionTriggeredColorTrainingLookForNegativeData),
                                                      @(RMActivityBehaviorMotionTriggeredColorTrainingFinished),
                                                      @(RMActivityBehaviorMotionTriggeredColorTrainingUpdated),
                                                      @(RMActivityBehaviorObjectFollow),
                                                      @(RMActivityBehaviorObjectSearch),
                                                      @(RMActivityBehaviorObjectQuicklyFind),
                                                      ];
        }
        _behaviorArbiter.behaviorRateLimits = @{
                                                @(RMActivityBehaviorObjectHeldOverHead) : @18.0,
                                                @(RMActivityBehaviorObjectPossession) : @14.0
                                                };
        
    }
    return _behaviorArbiter;
}

// This is for play-testing sessions, enabling us to record
#ifdef CAPTURE_DEBUG_DATA_BUTTON
- (UIButton *)captureButton
{
    if (!_captureButton) {
        _captureButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 80, 80)];
        [_captureButton setImage:[UIImage imageNamed:@"debugRecordButton.png"] forState:UIControlStateNormal];
        _captureButton.imageView.contentMode = UIViewContentModeCenter;
        [_captureButton addTarget:self action:@selector(handleCaptureButtonTouch:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _captureButton;
}

- (void)handleCaptureButtonTouch:(id)sender
{
    static RMVisionObjectTrackingModuleDebug *moduleDebug;
    
    if (!self.isCapturing) {
        // Start capture
        self.capturing = YES;
        
        NSSet *activeModules = [self.Romo.vision activeModules];
        for (id<RMVisionModuleProtocol> module in activeModules) {
            if ([module isKindOfClass:[RMVisionObjectTrackingModule class]]) {
                
                moduleDebug = [[RMVisionObjectTrackingModuleDebug alloc] initWithModule:(RMVisionObjectTrackingModule *)module];
                
                if (![moduleDebug startDebugCapture]) {
                    NSLog(@"Error capturing debug data!");
                }
                break;
            }
        }
        
        self.capturingTimer = [NSTimer scheduledTimerWithTimeInterval:0.35 target:self selector:@selector(blink) userInfo:nil repeats:YES];
        
    } else {
        self.capturing = NO;
        
        [self.capturingTimer invalidate];
        if (self.captureButton.tag == 1) {
            [_captureButton setImage:[UIImage imageNamed:@"debugRecordButton.png"] forState:UIControlStateNormal];
            self.captureButton.tag = 0;
        }
        
        [moduleDebug stopDebugCaptureWithCompletion:^(NSData *compressedData) {
            
            //TODO Send compressedData to the cloud!
            // Wrap up and ship to the cloud
            UIAlertView *addTitleAlert = [[UIAlertView alloc] initWithTitle:@"Add a title"
                                                                    message:nil delegate:self cancelButtonTitle:nil otherButtonTitles:@"Save", nil];
            addTitleAlert.alertViewStyle = UIAlertViewStylePlainTextInput;
            [addTitleAlert show];
            
        }];
        
    }
}

- (void)blink
{
    if (self.captureButton.tag == 1) {
        [_captureButton setImage:[UIImage imageNamed:@"debugRecordButton.png"] forState:UIControlStateNormal];
        self.captureButton.tag = 0;
    } else {
        [_captureButton setImage:[UIImage imageNamed:@"debugRecordButtonOn.png"] forState:UIControlStateNormal];
        self.captureButton.tag = 1;
    }
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    UITextField *titleField = [alertView textFieldAtIndex:0];
    [self.Romo.voice dismissImmediately];
    [self.Romo.voice say:titleField.text withStyle:RMVoiceStyleLLS autoDismiss:NO];
    
    self.captureButton.hidden = YES;
    
    double delayInSeconds = 0.5;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        UIGraphicsBeginImageContextWithOptions(self.view.bounds.size, NO, [UIScreen mainScreen].scale);
        [self.view.layer renderInContext:UIGraphicsGetCurrentContext()];
        UIImage *screenshot = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        UIImageWriteToSavedPhotosAlbum(screenshot, nil, nil, nil);
        
        double delayInSeconds = 0.25;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self.Romo.voice dismiss];
            
            double delayInSeconds = 5.0;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                self.capturing = NO;
                self.captureButton.hidden = NO;
            });
        });
    });
}
#endif

@end
