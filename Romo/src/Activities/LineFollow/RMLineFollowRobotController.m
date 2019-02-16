//
//  RMLineFollowRobotController.m
//  Romo
//

#import "RMLineFollowRobotController.h"
#import <Romo/RMMath.h>
#import <Romo/RMVisionNaiveLineTrainingModule.h>
#import <Romo/RMVisionObjectTrackingModule.h>
#import "UIView+Additions.h"
#import "UIColor+RMColor.h"
#import "RMAppDelegate.h"
#import "RMBehaviorArbiter.h"
#import "RMProgressManager.h"
#import "RMUnlockable.h"
#import "RMInteractionScriptRuntime.h"
#import "RMSoundEffect.h"
#import <Romo/RMVisionObjectTrackingModuleDebug.h>
#import <Romo/UIDevice+Romo.h>

/** Shows an extended intro the first time line follow is played */
static NSString *hasSeenLineFollowExtendedIntroKey = @"seenLineFollowIntro";

/** Amount of time Romo must line follow before the comet is beaten */
static const float minimumAccumulatedLineFollowPlayTime = 500.0; // sec

/** The total playtime for line follow, stored between sessions */
static NSString *const lineFollowAccumulatedPlaytimeKey = @"lineFollowAccumulatedPlaytime";

/** If we've played for at least the minimum playtime, this flag is marked to say we've unlocked the next content */
static NSString *const lineFollowHasAccumulatedEnoughPlaytimeKey = @"lineFollowHasAccumulatedEnoughPlaytime";

static NSString *introductionFirstTimeFileName = @"LineFollow-Introduction-First-Run";

static const float voiceHintsTopOffset = 32.0; // pixels
static const float topShadowHeight = 200.0; // pixels

@interface RMLineFollowRobotController () <RMBehaviorArbiterDelegate, RMVoiceDelegate>

/** Behavior & Action */
@property (nonatomic, strong) RMBehaviorArbiter *behaviorArbiter;

/** Measures the playtime */
@property (nonatomic) double lineFollowStartTime;

@property (nonatomic, strong) RMVisionNaiveLineTrainingModule *lineTrainingModule;

@property (nonatomic, getter=isWaitingForEyePoke) BOOL waitingForEyePoke;
@property (nonatomic, getter=isWaitingForInputLocation) BOOL waitingForInputLocation;

/** Shows a still photo of the ground */
@property (nonatomic, strong) UIImageView *groundView;
@property (nonatomic, strong) UIView *backdropView;
@property (nonatomic, strong) UIView *flickeringView;
@property (nonatomic, strong) CAGradientLayer *shadow;

/** The captured photo of the ground */
@property (nonatomic, strong) UIImage *photoOfGround;

/** The user's input of where the line is */
@property (nonatomic) CGPoint inputLineLocation;

@property (nonatomic, strong) UIImage *outputPhoto;
@property (nonatomic, strong) UIColor *outputColor;

@property (nonatomic, strong) RMVoice *voice;

#ifdef CAPTURE_DEBUG_DATA_BUTTON
@property (nonatomic, strong) UIButton *captureButton;
@property (nonatomic, getter=isCapturing) BOOL capturing;
@property (nonatomic, strong) NSTimer *capturingTimer;
#endif

@end

@implementation RMLineFollowRobotController

+ (double)activityProgress
{
    double playtime = [[NSUserDefaults standardUserDefaults] doubleForKey:lineFollowAccumulatedPlaytimeKey];
    return CLAMP(0.0, playtime / minimumAccumulatedLineFollowPlayTime, 1.0);
}

- (void)controllerDidBecomeActive
{
    [super controllerDidBecomeActive];
    
    self.Romo.voice.delegate = self;
    
    BOOL shouldShowFirstRunIntroduction = ![[NSUserDefaults standardUserDefaults] boolForKey:hasSeenLineFollowExtendedIntroKey];
    
    if (shouldShowFirstRunIntroduction) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:hasSeenLineFollowExtendedIntroKey];
        [self startExtendedIntroduction];
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
        
        self.behaviorArbiter.Romo = self.Romo;
        if (self.Romo.robot) {
            [self startLineTraining];
        }
    }
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

- (void)robotDidFlipToOrientation:(RMRobotOrientation)orientation
{
    if (_behaviorArbiter && self.behaviorArbiter.isObjectTracking) {
        // If we're done self-righting, make sure we look at the ground
        [self.Romo.robot tiltToAngle:self.Romo.robot.minimumHeadTiltAngle completion:nil];
    }
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
    return NSLocalizedString(@"Line-Follow-Title", @"Line Follow");
}

- (RMChapter)chapter
{
    return RMCometLineFollow;
}

- (BOOL)showsHelpButton
{
    return NO;
}

- (void)setAttentive:(BOOL)attentive
{
    if (attentive != super.attentive && !self.isWaitingForEyePoke && !self.isWaitingForInputLocation && !self.groundView.superview) {
        super.attentive = attentive;
        if (attentive) {
            if (_behaviorArbiter && self.behaviorArbiter.isObjectTracking) {
                self.behaviorArbiter.Romo = nil;
                [self.Romo.romotions stopRomoting];
                [self.Romo.robot stopAllMotion];
                [self.Romo.character lookAtPoint:RMPoint3DMake(0, 0, 0.45) animated:YES];
                [self.Romo.character mumble];
                
                self.Romo.voice.delegate = self;
                [self.Romo.voice dismissImmediately];
                [self.Romo.voice ask:NSLocalizedString(@"Follow-Different-Line-Prompt", @"Follow a\ndifferent line?") withAnswers:@[NSLocalizedString(@"Follow-Different-Line-No", @"No"), NSLocalizedString(@"Follow-Different-Line-Yes", @"New line")]];
            }
        } else {
            if (_behaviorArbiter) {
                self.behaviorArbiter.Romo = self.Romo;
                
                if (self.behaviorArbiter.isObjectTracking) {
                    [self.Romo.voice dismiss];
                }
            }
        }
    }
}

- (void)userAskedForHelp
{
    // do nothing
}

- (void)robotDidDisconnect:(RMCoreRobot *)robot
{
    self.attentive = NO;
    [self stopLineFollowing];
}

#pragma mark - RMBehaviorArbiterDelegate

- (void)behaviorArbiter:(RMBehaviorArbiter *)behaviorArbiter didFinishExecutingBehavior:(RMActivityBehavior)behavior
{
    switch (behavior) {
        case RMActivityBehaviorRequireDocking: {
            // Whenever they dock, start line follow flow from beginning
            [self startLineTraining];
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

/**
 Starts a guided interaction to capture line training data by capturing a photo of the ground
 then asking the user to input the line location
 */
- (void)startLineTraining
{
    [self stopLineFollowing];
    
    // Exposure point in the bottom middle
    self.Romo.vision.exposurePointOfInterest = CGPointMake(0,0.75);
    
    if (self.isActive) {
        [self.Romo.vision deactivateModuleWithName:RMVisionModule_FaceDetection];
        self.Romo.activeFunctionalities = enableFunctionality(RMRomoFunctionalityVision, self.Romo.activeFunctionalities);
        
        // Explains how the process works, then marks a flag that we're waiting for the user to poke Romo's eye
        [self.Romo.voice say:NSLocalizedString(@"Follow-Line-Put-On-Line", @"Put me on the line\nfor me to race along!") withStyle:RMVoiceStyleLLS autoDismiss:NO];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void){
            [self.Romo.voice say:NSLocalizedString(@"Follow-Line-Poke-Eye-When-Ready", @"Poke my eye\nwhen I'm on the line!") withStyle:RMVoiceStyleLLS autoDismiss:NO];
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void){
                self.waitingForEyePoke = YES;
            });
        });
    }
}

/**
 After the user poke's Romo's eye to let him know he's on the line, Romo will tilt down, snap a picture of the line,
 then ask the user to fill it in
 */
- (void)captureLineTrainingInputImage
{
    [self.Romo.voice dismiss];
    [self.Romo.voice say:NSLocalizedString(@"Follow-Line-Take-Look", @"Let me get a\ngood look...") withStyle:RMVoiceStyleLLS autoDismiss:NO];
    enableRomotions(NO, self.Romo);
    self.Romo.character.expression = RMCharacterExpressionBewildered;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void){
        [self.Romo.robot tiltToAngle:self.Romo.robot.minimumHeadTiltAngle
                          completion:^(BOOL success) {
                              dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void){
                                  // Play the camera shutter sound
                                  static const int numberOfCameraSounds = 5;
                                  [RMSoundEffect playForegroundEffectWithName:[NSString stringWithFormat:@"Camera%d", arc4random() % numberOfCameraSounds] repeats:NO gain:1.0];
                                  
                                  // Capture a photo of the ground and add the photo to the view
                                  self.photoOfGround = self.Romo.vision.currentImage;
                                  self.groundView.image = self.photoOfGround;
                                  [self.view addSubview:self.groundView];
                                  
                                  // Add a simple white flash animation to show we just took a picture
                                  UIView *flashView = [[UIView alloc] initWithFrame:self.view.bounds];
                                  flashView.backgroundColor = [UIColor whiteColor];
                                  [self.view addSubview:flashView];
                                  [UIView animateWithDuration:0.85
                                                   animations:^{
                                                       flashView.alpha = 0.0;
                                                   } completion:^(BOOL finished) {
                                                       [flashView removeFromSuperview];
                                                   }];
                                  
                                  // Turn off the character
                                  self.Romo.activeFunctionalities = disableFunctionality(RMRomoFunctionalityCharacter, self.Romo.activeFunctionalities);
                                  
                                  // Set up the flickering animation by placing two views beneath the photo
                                  // And animate the top view quickly for the flickering effect
                                  self.backdropView.backgroundColor = [UIColor romoBlue];
                                  self.flickeringView.backgroundColor = [UIColor whiteColor];
                                  [self.view insertSubview:self.backdropView belowSubview:self.groundView];
                                  [self.view insertSubview:self.flickeringView belowSubview:self.groundView];
                                  [UIView animateWithDuration:0.185 delay:0.0
                                                      options:UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat | UIViewAnimationOptionAllowUserInteraction
                                                   animations:^{
                                                       self.flickeringView.alpha = 0.0;
                                                   } completion:nil];
                                  
                                  [self.Romo.voice dismiss];
                                  [self.Romo.robot tiltToAngle:self.Romo.robot.maximumHeadTiltAngle
                                                    completion:^(BOOL success) {
                                                        self.waitingForInputLocation = YES;
                                                        
                                                        [self.voice say:NSLocalizedString(@"Follow-Line-Tap-Line-To-Follow", @"Tap the line you\nwant me to follow!") withStyle:RMVoiceStyleLLS autoDismiss:NO];
                                                        self.voice.top = voiceHintsTopOffset;
                                                    }];
                              });
                          }];
    });
}

/**
 Now that we have the photo of the ground and the user's input on where the line is,
 Let's let our training module generate some data for us
 And show the results to the user
 */
- (void)handleNewInputLocation
{
    BOOL isFirstInput = self.outputColor == nil;
    
    self.lineTrainingModule.seedPoint = self.inputLineLocation;
    self.lineTrainingModule.inputImage = self.photoOfGround;
    
    UIColor *outputColor = nil;
    UIImage *outputImage = nil;
    [self.lineTrainingModule getTrainedColor:&outputColor withOutputImage:&outputImage];
    
    if (!outputColor) {
        [self handleBadTrainingInput];
    } else {
        self.outputColor = outputColor;
        self.outputPhoto = outputImage;
        self.groundView.image = self.outputPhoto;
        
        if (isFirstInput) {
            // After the first input location, ask the user if they got the right line
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void){
                if (self.isWaitingForInputLocation) {
                    [self.voice dismissImmediately];
                    [self.voice removeFromSuperview];
                    self.voice = nil;
                    
                    [self.voice ask:NSLocalizedString(@"Follow-Line-Right-Line-Question", @"Is this the right line?")
                        withAnswers:@[NSLocalizedString(@"Follow-Line-Right-Line-No", @"Take new photo"),
                                      NSLocalizedString(@"Follow-Line-Right-Line-Yes", @"Follow this line")]];
                    self.voice.top = voiceHintsTopOffset;
                }
            });
        }
    }
}

/**
 If the training wasn't working, guide the user through taking a new photo
 */
- (void)handleBadTrainingInput
{
    [self tearDownLineTraining];
    
    [self.Romo.voice say:NSLocalizedString(@"Follow-Line-Photo-Trouble", @"Hmm, I'm having\ntrouble with that photo...") withStyle:RMVoiceStyleLLS autoDismiss:NO];
    
    double delayInSeconds = 3.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self.Romo.voice say:NSLocalizedString(@"Follow-Line-Different-Spot", @"Can you show me\na different spot?") withStyle:RMVoiceStyleLLS autoDismiss:NO];
        
        double delayInSeconds = 3.0;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self startLineTraining];
        });
    });
}

/**
 If line following is fucking up, notify the user
 */
- (void)lineFollowIsFuckingUp
{
    self.attentive = YES;
    [self.Romo.robot tiltToAngle:110 completion:nil];
}

/**
 After we've received all necessary training data, we start tracking the line
 */
- (void)startLineFollowing
{
    [self.behaviorArbiter startBrightnessMetering];
    [self.behaviorArbiter startTrackingObjectWithTrainingData:self.lineTrainingModule.trainingData];
    self.lineTrainingModule = nil;
    
    if (!self.lineFollowStartTime) {
        // Log the start of line following as the first time we're trained
        self.lineFollowStartTime = currentTime();
    }
    
    [self.Romo.robot tiltToAngle:self.Romo.robot.minimumHeadTiltAngle completion:nil];
    
    [self tearDownLineTraining];
    
    // make sure super is not attentive because it's easy for it to get in the
    // wrong state (I believe due to screen taps toggeling it inappropriately
    // sometimes)
    super.attentive = NO;
}

- (void)stopLineFollowing
{
    
    // Reset exposure point to the middle
    self.Romo.vision.exposurePointOfInterest = CGPointMake(0,0);
    
    [self.behaviorArbiter stopTrackingObject];
    [self.behaviorArbiter stopBrightnessMetering];
    
    [self updateAccumulatedPlaytime];
}

/**
 Cancels all line training and throws out any collected data
 */
- (void)tearDownLineTraining
{
    self.Romo.activeFunctionalities = enableFunctionality(RMRomoFunctionalityCharacter, self.Romo.activeFunctionalities);
    
    self.waitingForEyePoke = NO;
    self.waitingForInputLocation = NO;
    
    self.outputColor = nil;
    self.outputPhoto = nil;
    self.photoOfGround = nil;
    self.inputLineLocation = CGPointZero;
    
    self.lineTrainingModule = nil;
    
    [self.groundView removeFromSuperview];
    self.groundView = nil;
    
    [self.flickeringView removeFromSuperview];
    self.flickeringView = nil;
    
    [self.backdropView removeFromSuperview];
    self.backdropView = nil;
    
    [self.voice removeFromSuperview];
    self.voice = nil;
}

- (void)updateAccumulatedPlaytime
{
    if (self.lineFollowStartTime) {
        // Compute how long we line followed and add that to the lifetime total
        double lineFollowPlaytime = currentTime() - self.lineFollowStartTime;
        double accumulatedPlaytime = lineFollowPlaytime + [[NSUserDefaults standardUserDefaults] doubleForKey:lineFollowAccumulatedPlaytimeKey];
        [[NSUserDefaults standardUserDefaults] setDouble:accumulatedPlaytime forKey:lineFollowAccumulatedPlaytimeKey];
        self.lineFollowStartTime = 0.0;
        
        if (accumulatedPlaytime >= minimumAccumulatedLineFollowPlayTime) {
            BOOL hasBeatenLineFollow = [[NSUserDefaults standardUserDefaults] boolForKey:lineFollowHasAccumulatedEnoughPlaytimeKey];
            if (!hasBeatenLineFollow) {
                [[NSUserDefaults standardUserDefaults] setBool:YES forKey:lineFollowHasAccumulatedEnoughPlaytimeKey];
                [self handleMinimumPlayTimeReached];
            }
        }
    }
}

- (void)handleMinimumPlayTimeReached
{
    // Unlock the final chapter
    [[RMProgressManager sharedInstance] setStatus:RMChapterStatusNew forChapter:RMChapterTheEnd];
}

- (void)handleSpaceButtonTouch:(id)sender
{
    [self.delegate activityDidFinish:self];
}

- (void)touch:(RMTouch *)touch beganPokingAtLocation:(RMTouchLocation)location
{
    if ((location == RMTouchLocationLeftEye || location == RMTouchLocationRightEye) && self.isWaitingForEyePoke) {
        // If we were waiting for an eye-poke, finish capturing the data
        self.waitingForEyePoke = NO;
        [self captureLineTrainingInputImage];
    }
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (self.isWaitingForInputLocation) {
        [self touchesMoved:touches withEvent:event];
    } else {
        [super touchesBegan:touches withEvent:event];
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (self.isWaitingForInputLocation) {
        CGPoint touchLocation = [[touches anyObject] locationInView:self.view];
        
        // Ignore touches at the top of the screen
        if (touchLocation.y > topShadowHeight) {
            // Scale the input point to a scale of [-1, 1] on (x,y)
            CGFloat scaledX = (touchLocation.x / self.view.width) * 2.0 - 1.0;
            CGFloat scaledY = (touchLocation.y / self.view.height) * 2.0 - 1.0;
            self.inputLineLocation = CGPointMake(scaledX, scaledY);
            
            [self handleNewInputLocation];
        }
    } else {
        [super touchesMoved:touches withEvent:event];
    }
}

#pragma mark - RMVisionObjectTrackingModuleDelegate

#ifdef VISION_DEBUG
-(void)showDebugImage:(UIImage *)debugImage
{
    [self.view addSubview:self.groundView];
    self.groundView.image = debugImage;
}
#endif

#pragma mark - RMVoiceDelegate

- (void)userDidSelectOptionAtIndex:(int)optionIndex forVoice:(RMVoice *)voice
{
    if (voice == self.voice) {
        [voice dismiss];
        // If we're doing the training, either restart the flow or finish the flow
        // based on the user's answer
        if (optionIndex == 0) {
            // "Take new photo"
            [self tearDownLineTraining];
            [self startLineTraining];
        } else {
            [self startLineFollowing];
            
#ifdef CAPTURE_DEBUG_DATA_BUTTON
            self.captureButton.center = CGPointMake(self.view.frame.size.width / 2.0, self.view.frame.size.height - 70);
            [self.view addSubview:self.captureButton];
#endif
        }
        
    } else {
        // Romo asking whether or not we want to follow a new line
        self.attentive = NO;
        [self.Romo.voice dismiss];
        if (optionIndex == 1) {
            // Follow a new line
            [self tearDownLineTraining];
            [self stopLineFollowing];
            [self startLineTraining];
        }
    }
}

#pragma mark - Private Properties

- (RMBehaviorArbiter *)behaviorArbiter
{
    if (!_behaviorArbiter) {
        _behaviorArbiter = [[RMBehaviorArbiter alloc] init];
        _behaviorArbiter.delegate = self;
        _behaviorArbiter.prioritizedBehaviors = @[
                                                  @(RMActivityBehaviorRequireDocking),
                                                  @(RMActivityBehaviorSelfRighting),
                                                  @(RMActivityBehaviorTooDark),
                                                  @(RMActivityBehaviorTooBright),
                                                  @(RMActivityBehaviorObjectFollow),
                                                  @(RMActivityBehaviorLineSearch),
                                                  @(RMActivityBehaviorObjectQuicklyFind),
                                                  ];
        _behaviorArbiter.lineFollowing = YES;
    }
    return _behaviorArbiter;
}

- (RMVisionNaiveLineTrainingModule *)lineTrainingModule
{
    if (!_lineTrainingModule) {
        _lineTrainingModule = [[RMVisionNaiveLineTrainingModule alloc] initWithVision:self.Romo.vision];
    }
    return _lineTrainingModule;
}

- (UIImageView *)groundView
{
    if (!_groundView) {
        _groundView = [[UIImageView alloc] initWithFrame:self.view.bounds];
        _groundView.contentMode = UIViewContentModeScaleToFill;
        _groundView.backgroundColor = [UIColor clearColor];
        [_groundView.layer addSublayer:self.shadow];
    }
    return _groundView;
}

- (UIView *)backdropView
{
    if (!_backdropView) {
        _backdropView = [[UIView alloc] initWithFrame:self.view.bounds];
    }
    return _backdropView;
}

- (UIView *)flickeringView
{
    if (!_flickeringView) {
        _flickeringView = [[UIView alloc] initWithFrame:self.view.bounds];
    }
    return _flickeringView;
}

- (CAGradientLayer *)shadow
{
    if (!_shadow) {
        _shadow = [CAGradientLayer layer];
        _shadow.frame = CGRectMake(0, 0, self.view.width, topShadowHeight * 1.3);
        _shadow.colors = @[(id)[UIColor colorWithWhite:0.0 alpha:0.80].CGColor,
                           (id)[UIColor clearColor].CGColor];
        _shadow.startPoint = CGPointMake(0.0, 0.25);
        _shadow.endPoint = CGPointMake(0.0, 1.0);
    }
    return _shadow;
}

- (RMVoice *)voice
{
    if (!_voice) {
        _voice = [[RMVoice alloc] initWithFrame:self.view.bounds];
        _voice.delegate = self;
        _voice.view = self.view;
    }
    return _voice;
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
