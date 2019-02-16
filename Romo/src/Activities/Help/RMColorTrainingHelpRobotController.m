//
//  RMColorTrainingHelpRobotController.m
//  Romo
//

#import "RMColorTrainingHelpRobotController.h"
#import <Romo/RMVision.h>
#import <Romo/RMThroughRomosEyesModule.h>
#import <Romo/RMMotionTriggeredColorTrainingModule.h>
#import <Romo/RMDispatchTimer.h>
#import "UIView+Additions.h"
#import "UIColor+RMColor.h"
#import "RMAppDelegate.h"
#import <Romo/RMCharacterColorFill.h>
#import <Romo/RMMath.h>
#import "RMSoundEffect.h"
#import "RMAudioUtils.h"

/** The size of the blur effect on Romo's vision */
static const float boxBlurAmount = 4.0;

static const CGFloat zoomedCharacterOffsetX = -780;
static const CGFloat zoomedCharacterOffsety = 425;

//static const CGFloat voiceBgHeight = 200.0;

//static const float tiltMotorPower = 0.32;
//static const float tiltDuration = 1.5;

static const int motionTriggeredDuration = 3.25; // sec

@interface RMColorTrainingHelpRobotController () <RMMotionTriggeredColorTrainingModuleDelegate>

@property (nonatomic, strong) UIView *characterView;
@property (nonatomic, strong) UIView *visionView;
@property (nonatomic, strong) RMVoice *voice;
@property (nonatomic, strong) RMCharacterColorFill *colorFill;

@property (nonatomic, strong) RMThroughRomosEyesModule *throughRomosEyes;
@property (nonatomic, strong) RMMotionTriggeredColorTrainingModule *motionTriggeredModule;

@property (nonatomic, strong) RMDispatchTimer *colorFillAnimationTimer;

@property (nonatomic, strong) RMSoundEffect *backgroundMusic;
@property (nonatomic, strong) NSTimer *promptTimer;
@property (nonatomic) int promptNumber;

@end

@implementation RMColorTrainingHelpRobotController

- (void)controllerDidBecomeActive
{
    [super controllerDidBecomeActive];
    
    self.promptNumber = 0;
    [self.promptTimer invalidate];
    
    // Play background music
    self.backgroundMusic = [[RMSoundEffect alloc] initWithName:@"musicActivity"];
    self.backgroundMusic.repeats = YES;
    self.backgroundMusic.gain = 0.75;
    [self.backgroundMusic play];
    
    self.Romo.character.emotion = RMCharacterEmotionCurious;
    
    [self startHelp];
}

- (void)controllerWillResignActive
{
    [super controllerWillResignActive];
    [self.promptTimer invalidate];
    self.backgroundMusic = nil;
}

- (UIView *)characterView
{
    if (!_characterView) {
        _characterView = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
        [self.view addSubview:_characterView];
    }
    return _characterView;
}

- (NSSet *)initiallyActiveVisionModules
{
    return nil;
}

- (RMRomoFunctionalities)initiallyActiveFunctionalities
{
    return RMRomoFunctionalityBroadcasting | RMRomoFunctionalityCharacter | RMRomoFunctionalityVision;
}

- (RMRomoInterruptions)initiallyAllowedInterruptions
{
    return RMRomoInterruptionCharacterUnlocks | RMRomoInterruptionRomotion | RMRomoInterruptionSelfRighting | RMRomoInterruptionWakefulness;
}

#pragma mark - RMMotionTriggeredColorTrainingModuleDelegate

- (void)motionTriggeredTrainingModule:(RMMotionTriggeredColorTrainingModule *)module didUpdateWithProgress:(float)progress withEstimatedColor:(UIColor *)color
{
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
        
        __weak RMColorTrainingHelpRobotController *weakSelf = self;
        self.colorFillAnimationTimer.eventHandler = ^{
            static float lastPercentage = 0.0;
            double dt = currentTime() - lastTime;
            float percentage = (thisProgress + weakSelf.Romo.vision.targetFrameRate * dt * (thisProgress - lastProgress));
            
            if (ABS(percentage - lastPercentage) > 0.02) {
                // Smooth out rough changes so we always animate smoothly
                percentage = (percentage + lastPercentage) / 2.0;
            }
            
            weakSelf.colorFill.fillAmount = percentage;
            weakSelf.colorFill.fillColor = goodColor;
            
            lastPercentage = percentage;
        };
        [self.colorFillAnimationTimer startRunning];
    }
}

- (void)motionTriggeredTrainingModule:(RMMotionTriggeredColorTrainingModule *)module didFinishWithColor:(UIColor *)color withTrainingData:(RMVisionTrainingData *)trainingData
{
    [self.colorFillAnimationTimer stopRunning];
    self.colorFill.fillAmount = 1.0;

    [self finishTraining];
}

#pragma mark - Private Methods

- (void)startHelp
{    
    // add the filtered vision to the view
    self.throughRomosEyes.outputView = self.visionView;
    self.throughRomosEyes.blurSize = boxBlurAmount;
    [self.Romo.vision activateModule:self.throughRomosEyes];
    
    self.visionView.alpha = 0.0;
    self.visionView.frame = CGRectMake(self.view.width / 2.0 + 18.0, self.view.height / 2.0 - 33, 29, 29);
    self.visionView.layer.cornerRadius = self.visionView.width / 2.0;
    [self.view addSubview:self.visionView];
    
    // zoom in on Romo's pupil
    [UIView animateWithDuration:0.55 delay:0.0 options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
                         self.characterView.transform = CGAffineTransformMakeScale(24.0, 24.0);
                         self.characterView.center = CGPointMake(self.view.width / 2.0 + zoomedCharacterOffsetX,
                                                                 self.view.height / 2.0 + zoomedCharacterOffsety);
                         self.characterView.alpha = 0.25;
                         
                         self.visionView.frame = self.view.bounds;
                         self.visionView.alpha = 1.0;
                     } completion:^(BOOL finished) {
                         [self.characterView removeFromSuperview];
                         self.characterView = nil;
                         self.Romo.activeFunctionalities = disableFunctionality(RMRomoFunctionalityCharacter, self.Romo.activeFunctionalities);
                         
                         self.visionView.layer.cornerRadius = 0.0;
                         
                         [self showPrompt:self.promptTimer];
                     }];
}

- (void)showPrompt:(NSTimer *)timer
{
    [timer invalidate];
    BOOL shouldSetupNextPrompt = YES;
    
    float timeout = 4.0; // Default timeout is 4 seconds
    if (self.promptNumber == 0) {
        [self.voice say:NSLocalizedString(@"FavColor-ColorTrainingHelpPrompt1", @"This is how I\nsee the world!") withStyle:RMVoiceStyleLLS autoDismiss:NO];
    } else if (self.promptNumber == 1) {
        [self.voice dismiss];
        [self.voice say:NSLocalizedString(@"FavColor-ColorTrainingHelpPrompt2", @"I can only see\nCOLORFUL stuff") withStyle:RMVoiceStyleLLS autoDismiss:NO];
    } else if (self.promptNumber == 2) {
        [self.voice dismiss];
        [self.voice say:NSLocalizedString(@"FavColor-ColorTrainingHelpPrompt3", @"And moving colors\ngrab my attention.") withStyle:RMVoiceStyleLLS autoDismiss:NO];
    } else if (self.promptNumber == 3) {
        [self.voice dismiss];
        timeout = 2.0;
    } else if (self.promptNumber == 4) {
        [self.voice say:NSLocalizedString(@"FavColor-ColorTrainingHelpPrompt4", @"Go ahead!") withStyle:RMVoiceStyleLLS autoDismiss:NO];
        timeout = 2.0;
    } else if (self.promptNumber == 5) {
        [self.voice dismiss];
        [self.voice say:NSLocalizedString(@"FavColor-ColorTrainingHelpPrompt5", @"Wave around\nsomething colorful!") withStyle:RMVoiceStyleLLS autoDismiss:NO];
        timeout = 0.5;
    } else if (self.promptNumber == 6) {
        shouldSetupNextPrompt = NO;
        [self startMotionTriggeredTraining];
    } else if (self.promptNumber == 7) {
        [self.voice dismiss];
        [self.voice say:NSLocalizedString(@"FavColor-ColorTrainingHelpPrompt6", @"There you go!") withStyle:RMVoiceStyleLLS autoDismiss:NO];
        timeout = 2.0;
    } else if (self.promptNumber == 8) {
        [self.voice dismiss];
        [self.voice say:NSLocalizedString(@"FavColor-ColorTrainingHelpPrompt7", @"Now let’s get back\nto that game") withStyle:RMVoiceStyleLLS autoDismiss:NO];
        timeout = 3.0;
    } else if (self.promptNumber == 9) {
        shouldSetupNextPrompt = NO;
        [self.Romo.vision deactivateModule:self.throughRomosEyes];
        self.throughRomosEyes = nil;
        [(RMAppDelegate *)[UIApplication sharedApplication].delegate popRobotController];
    }
    
    self.promptNumber++;
    
    if (shouldSetupNextPrompt) {
        self.promptTimer = [NSTimer scheduledTimerWithTimeInterval:timeout
                                                            target:self
                                                          selector:@selector(showPrompt:)
                                                          userInfo:nil
                                                           repeats:NO];
    }
}

- (void)startMotionTriggeredTraining
{
    self.colorFill.fillAmount = 0.0;
    [self.view insertSubview:self.colorFill belowSubview:self.voice];
    
    self.motionTriggeredModule.capturingPositiveTrainingData = YES;
    [self.Romo.vision activateModule:self.motionTriggeredModule];
}

- (void)finishTraining
{
    [self.Romo.vision deactivateModule:self.motionTriggeredModule];
    self.motionTriggeredModule = nil;
    
    [self showPrompt:self.promptTimer];
}

#pragma mark - Private Properties

- (RMMotionTriggeredColorTrainingModule *)motionTriggeredModule
{
    if (!_motionTriggeredModule) {
        _motionTriggeredModule = [[RMMotionTriggeredColorTrainingModule alloc] initWithVision:self.Romo.vision];
        _motionTriggeredModule.delegate = self;
        _motionTriggeredModule.triggerCountThreshold = ceilf(self.Romo.vision.targetFrameRate * motionTriggeredDuration);
    }
    return _motionTriggeredModule;
}

- (RMThroughRomosEyesModule *)throughRomosEyes
{
    if (!_throughRomosEyes) {
        _throughRomosEyes = [[RMThroughRomosEyesModule alloc] initWithVision:self.Romo.vision];
    }
    return _throughRomosEyes;
}

- (UIView *)visionView
{
    if (!_visionView) {
        _visionView = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
        _visionView.contentMode = UIViewContentModeScaleAspectFill;
        _visionView.clipsToBounds = YES;
        
        UIImageView *vignette = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"visionVignette.png"]];
        vignette.frame = _visionView.bounds;
        [_visionView addSubview:vignette];
    }
    return _visionView;
}

- (RMVoice *)voice
{
    if (!_voice) {
        _voice = [[RMVoice alloc] initWithFrame:CGRectMake(0, 0, self.view.width, 0)];
        _voice.view = self.view;
    }
    return _voice;
}

- (RMCharacterColorFill *)colorFill
{
    if (!_colorFill) {
        _colorFill = [[RMCharacterColorFill alloc] initWithFrame:self.view.bounds];
        _colorFill.hasBackgroundFill = NO;
        _colorFill.alpha = 0.65;
    }
    return _colorFill;
}

- (RMDispatchTimer *)colorFillAnimationTimer
{
    if (!_colorFillAnimationTimer) {
        _colorFillAnimationTimer = [[RMDispatchTimer alloc] initWithQueue:dispatch_get_main_queue() frequency:30.0];
    }
    return _colorFillAnimationTimer;
}

#pragma mark - Touch Handlers
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self.promptTimer invalidate];
    [self showPrompt:self.promptTimer];
}

@end
