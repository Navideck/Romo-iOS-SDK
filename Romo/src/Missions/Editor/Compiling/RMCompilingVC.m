//
//  RMCompilingVC.m
//  Romo
//

#import "RMCompilingVC.h"
#import <QuartzCore/QuartzCore.h>
#import <Romo/RMMath.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "UIView+Additions.h"
#import "UIFont+RMFont.h"
#import "RMGradientLabel.h"
#import "RMMission.h"
#import "RMEvent.h"
#import "RMAction.h"
#import "RMParameter.h"
#import "RMSoundEffect.h"
#import "RMAlertView.h"

#define compileStepCount 3
#define kNumCompilingSounds 8

@interface RMCompilingVC () <RMAlertViewDelegate>

@property (nonatomic, strong) UIImageView *progressBar;
@property (nonatomic, strong) RMGradientLabel *titleLabel;
@property (nonatomic) int step;
@property (nonatomic) float progress;

@end

@implementation RMCompilingVC

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.titleLabel.center = CGPointMake(self.view.width / 2, self.view.height / 2 - 50);
    self.titleLabel.text = NSLocalizedString(@"Compile-Stage-1", @"Quantizing...");
    [self.view addSubview:self.titleLabel];
    
    UIImage *backgroundImage = [[UIImage imageNamed:@"compilingProgressBarBackground.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 17, 0, 17)];
    UIImageView *progressBarBackground = [[UIImageView alloc] initWithImage:backgroundImage];
    progressBarBackground.frame = CGRectMake(50, 0, self.view.width - 100, 32);
    progressBarBackground.centerY = self.view.height / 2;
    [self.view addSubview:progressBarBackground];
    
    self.progressBar = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"compilingProgressBar.png"]];
    self.progressBar.frame = CGRectMake(9, 9, 0, 14);
    self.progressBar.layer.cornerRadius = 7.0;
    self.progressBar.clipsToBounds = YES;
    [progressBarBackground addSubview:self.progressBar];
}

- (void)compile
{
    if (self.view.superview) {
        switch (self.step) {
            case 0: {
                // Play random compiling sound
                int randomCompilingNum = arc4random_uniform(kNumCompilingSounds) + 1;
                [RMSoundEffect playForegroundEffectWithName:[NSString stringWithFormat:@"Missions-State Compile-%d", randomCompilingNum]
                                                    repeats:NO
                                                       gain:1.0];
                
                self.progress = 0.25 + (float)(arc4random() % 15)/100.0;
                self.titleLabel.text = NSLocalizedString(@"Compile-Stage-1", nil);
                // check for nil-valued parameters in events
                for (RMEvent *event in self.mission.events) {
                    if (event.parameter != nil && event.parameter.value == nil) {
                        if ([self.delegate respondsToSelector:@selector(compilingVCDidFailToCompile:)]) {
                            [self.delegate compilingVCDidFailToCompile:self];
                        }
                        return;
                    }
                }
                // check for nil-valued parameters in actions
                for (NSArray *script in self.mission.inputScripts) {
                    for (RMAction *action in [RMMission flattenedScript:script]) {
                        for (RMParameter *parameter in action.parameters) {
                            if (parameter.value == nil) {
                                if ([self.delegate respondsToSelector:@selector(compilingVCDidFailToCompile:)]) {
                                    [self.delegate compilingVCDidFailToCompile:self];
                                }
                                return;
                            }
                        }
                    }
                }
            }
                break;
                
            case 1: {
                self.progress = 0.55 + (float)(arc4random() % 15)/100.0;
                self.titleLabel.text = NSLocalizedString(@"Compile-Stage-2", @"Compiling...");
                
                if (self.missionNeedsToSavePhotos) {
                    if (!self.hasPermissionToSavePhotos) {
                        [[[RMAlertView alloc] initWithTitle:NSLocalizedString(@"Compile-PhotoPerms-Alert-Title", @"Photo Permission Needed")
                                                    message:NSLocalizedString(@"Compile-PhotoPerms-Alert-Message", @"For Romo to take photos and videos, allow access to your Photo Library.\n\nOpen the Settings app > Privacy > Photos.\n\nThen enable access for Romo.")
                                                   delegate:self] show];
                        return;
                    }
                }
                break;
            }
                
            case 2:
                self.progress = 0.8 + (float)(arc4random() % 15)/100.0;
                self.titleLabel.text = NSLocalizedString(@"Compile-Stage-3", @"Sandboxing...");
                
                if (self.missionNeedsMicrophone && !self.hasMicrophonePermission) {
                    [[[RMAlertView alloc] initWithTitle:NSLocalizedString(@"Compile-MicPerms-Alert-Title", @"Microphone Permission Needed")
                                                message:NSLocalizedString(@"Compile-MicPerms-Alert-Message", @"For Romo to hear loud sounds, allow access to your microphone.\n\nOpen the Settings app > Privacy > Microphone.\n\nThen enable access for Romo.")
                                               delegate:self] show];
                    return;
                }
                break;
                
            default:
                self.progress = 1.0;
                self.titleLabel.text = NSLocalizedString(@"Compile-Stage-4", @"Deploying...");
                [self finishCompiling];
                break;
        }
        self.step++;
        
        if (self.step <= 3) {
            double delayInSeconds = 0.65;
#ifdef FAST_MISSIONS
            delayInSeconds = 0.05;
#endif
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                [self compile];
            });
        }
    }
}

#pragma mark - RMAlertViewDelegate

- (void)alertViewDidDismiss:(RMAlertView *)alertView
{
    // We were telling the user they either need to grant microphone or photo library access
    // When they dismiss it, fail compilation so they can retry once they've fixed the problem
    [self.delegate compilingVCDidFailToCompile:self];
}

#pragma mark - Private Properties

- (BOOL)missionNeedsToSavePhotos
{
    __block BOOL hasCameraAction = NO;
    [self.mission.inputScripts enumerateObjectsUsingBlock:^(NSArray *script, NSUInteger idx, BOOL *stop) {
        [script enumerateObjectsUsingBlock:^(RMAction *action, NSUInteger idx, BOOL *scriptStop) {
            if ([action.library isEqualToString:@"Camera"]) {
                hasCameraAction = YES;
                *stop = YES;
                *scriptStop = YES;
            }
        }];
    }];
    return hasCameraAction;
}

- (BOOL)missionNeedsMicrophone
{
    __block BOOL hasLoudSoundEvent = NO;
    [self.mission.events enumerateObjectsUsingBlock:^(RMEvent *event, NSUInteger idx, BOOL *stop) {
        if (event.type == RMEventHearsLoudSound) {
            hasLoudSoundEvent = YES;
            *stop = YES;
        }
    }];
    return hasLoudSoundEvent;
}

- (BOOL)hasPermissionToSavePhotos
{
    return [ALAssetsLibrary authorizationStatus] == ALAuthorizationStatusAuthorized;
}

- (BOOL)hasMicrophonePermission
{
    // Older versions of iOS don't require permission to access the microphone    
    __block BOOL hasMicrophonePermission = NO;
    if (@available(iOS 7.0, *)) {
        [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
            hasMicrophonePermission = granted;
        }];
        return hasMicrophonePermission;
    } else {
        // Fallback on earlier versions
        return YES;
    }
}

- (RMGradientLabel *)titleLabel
{
    if (!_titleLabel) {
        _titleLabel = [[RMGradientLabel alloc] initWithFrame:CGRectMake(0, 0, 240, 36)];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.gradientColor = [UIColor greenColor];
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.font = [UIFont largeFont];
    }
    return _titleLabel;
}

#pragma mark - Private Methods

- (void)setProgress:(float)progress
{
    progress = CLAMP(0.0, progress, 1.0);
    _progress = progress;
    
    [UIView animateWithDuration:0.35
                     animations:^{
                         self.progressBar.width = progress * 202.0;
                     }];
}

- (void)finishCompiling
{
    double delayInSeconds = 0.45;
#ifdef FAST_MISSIONS
    delayInSeconds = 0.05;
#endif
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self.delegate compilingVCDidFinishCompiling:self];
    });
}

@end
