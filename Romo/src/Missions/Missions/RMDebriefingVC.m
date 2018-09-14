//
//  RMDebriefingVC.m
//  Romo
//

#import "RMDebriefingVC.h"
#import "UIView+Additions.h"
#import "UIFont+RMFont.h"
#import "UIImage+Tint.h"
#import "UIColor+RMColor.h"
#import "UIButton+SoundEffects.h"
#import "RMGradientLabel.h"
#import <RMShared/RMMath.h>
#import "RMMission.h"
#import "RMProgressManager.h"
#import "RMMissionToken.h"
#import "RMChapterPlanet.h"
#import "RMUnlockable.h"
#import "RMSpaceScene.h"
#import "RMActionIcon.h"
#import "RMAction.h"
#import "RMEventIcon.h"
#import "RMSoundEffect.h"
#import "RMFaceActionView.h"
#import "RMFaceActionIcon.h"
#import <RMShared/UIDevice+Hardware.h>

#define successSound @"Missions-Debriefing-Success-%d"
#define failureSound @"Missions-Debriefing-Failure"
#define nthStarSound @"Missions-Debriefing-Star-%d"

NSString *const RMRomoAppStoreURL = @"https://itunes.apple.com/us/app/romo-x/id1436292886";

@interface RMDebriefingVC () <UIAlertViewDelegate>

/** UI */
@property (nonatomic, strong) UIImageView *window;
@property (nonatomic, strong) RMMissionToken *orb;
@property (nonatomic, strong) UIImageView *leftClaw;
@property (nonatomic, strong) UIImageView *rightClaw;
@property (nonatomic, strong) NSMutableArray *successStars;
@property (nonatomic, strong) UILabel *missionLabel;
@property (nonatomic, strong) RMGradientLabel *statusLabel;
@property (nonatomic, strong) UILabel *debriefingLabel;
@property (nonatomic, strong) UIButton *retryButton;
@property (nonatomic, strong) UIButton *continueButton;
@property (nonatomic) BOOL showingUnlockables;

/** Is this current solution valid? If so, how many stars? */
@property (nonatomic) int starCount;
/**
 Unlockables that were just achieved
 Unlockables aren't achieved if they were achieved previously
 */
@property (nonatomic, strong) NSMutableArray *achievedUnlockables;

/**
 Presented when the user hits continue
 e.g. "Rate the app"
 */
@property (nonatomic, strong) NSMutableArray *delayedUnlockables;
@property (nonatomic, copy) void (^completion)();
@property (nonatomic) BOOL continueOnCompletion;

/** If valid, randomly shoots stars from mission orb */
@property (nonatomic, strong) NSTimer *starTimer;

@property (nonatomic, readwrite, strong) RMMission *mission;

@end

@implementation RMDebriefingVC

- (id)initWithMission:(RMMission *)mission
{
    self = [super init];
    if (self) {
        self.mission = mission;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.achievedUnlockables = [NSMutableArray arrayWithCapacity:3];
    self.delayedUnlockables = [NSMutableArray arrayWithCapacity:1];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.starCount = self.mission.starCount;
#ifdef ALWAYS_THREE_STAR_MISSION
    self.starCount = 3;
#endif
    
    if (self.starCount > 0) {
        self.mission.status = self.starCount == 1 ? RMMissionStatusOneStar : self.starCount == 2 ? RMMissionStatusTwoStar : RMMissionStatusThreeStar;
        
        for (RMUnlockable *unlockable in self.mission.unlockables) {
            if (unlockable.type != RMUnlockableOther) {
                BOOL achieved = [[RMProgressManager sharedInstance] achieveUnlockable:unlockable];
                if (achieved && unlockable.type != RMUnlockableMission && unlockable.type != RMUnlockableChapter && unlockable.isPresented) {
                    [self.achievedUnlockables addObject:unlockable];
                }
            } else {
                [self.delayedUnlockables addObject:unlockable];
            }
        }
    } else {
        self.starCount = 0;
        self.mission.status = RMMissionStatusFailed;
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (!self.window.superview) {
        [self.view addSubview:self.window];
        [UIView animateWithDuration:0.75
                         animations:^{
                             self.window.centerY = self.view.height / 2.0 + 64;
                         } completion:^(BOOL finished) {
                             [UIView animateWithDuration:0.25
                                              animations:^{
                                                  self.window.centerY = self.view.height / 2 + 32;
                                              } completion:^(BOOL finished) {
                                                  [self animateClaws];
                                              }];
                         }];
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    [self.starTimer invalidate];
    self.starTimer = nil;
    
    self.mission = nil;
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RMRateAppResponseNotification" object:nil userInfo:@{@"buttonIndex": @(buttonIndex)}];
    
    switch (buttonIndex) {
            // Rate Romo
        case 1: {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:RMRomoAppStoreURL]];
            break;
        }
            
        default:
            break;
    }
    
    if (self.completion) {
        self.completion();
        self.completion = nil;
    }
}

#pragma mark - Private Properties

- (UIImageView *)window
{
    if (!_window) {
        _window = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"debriefingWindow.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(37, 0, 37, 0)]];
        _window.frame = CGRectMake(0, -600, 291, 338);
        _window.centerX = self.view.width / 2;
        _window.userInteractionEnabled = YES;
    }
    return _window;
}

- (UILabel *)missionLabel
{
    if (!_missionLabel) {
        _missionLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _missionLabel.backgroundColor = [UIColor clearColor];
        _missionLabel.textColor = [UIColor whiteColor];
        _missionLabel.font = [UIFont fontWithSize:24.0];
        NSString *missionString = NSLocalizedString(@"Mission", @"Gerenic Mission Title");
        _missionLabel.text = [NSString stringWithFormat:@"%@:", [missionString uppercaseString]];
        _missionLabel.size = [_missionLabel.text sizeWithFont:_missionLabel.font];
    }
    return _missionLabel;
}

- (RMGradientLabel *)statusLabel
{
    if (!_statusLabel) {
        _statusLabel = [[RMGradientLabel alloc] initWithFrame:CGRectZero];
        _statusLabel.backgroundColor = [UIColor clearColor];
        _statusLabel.font = [UIFont fontWithSize:28.0];
        _statusLabel.text = (self.starCount > 0) ? NSLocalizedString(@"Debriefing-Success-Title", @"SUCCESS!") : NSLocalizedString(@"Debriefing-Failure-Title", @"FAILURE");
        _statusLabel.size = [_statusLabel.text sizeWithFont:_statusLabel.font];
        _statusLabel.gradientColor = (self.starCount > 0) ? [UIColor greenColor] : [UIColor magentaColor];
    }
    return _statusLabel;
}

- (NSMutableArray *)successStars
{
    if (!_successStars) {
        _successStars = [NSMutableArray arrayWithCapacity:3];
        
        for (int i = 0; i < 3; i++) {
            UIImageView *noStar = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"debriefingNoStar.png"]];
            [_successStars addObject:noStar];
        }
    }
    return _successStars;
}

- (UILabel *)debriefingLabel
{
    if (!_debriefingLabel) {
        _debriefingLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.window.width - 50, 72)];
        _debriefingLabel.backgroundColor = [UIColor clearColor];
        _debriefingLabel.textColor = [UIColor whiteColor];
        _debriefingLabel.textAlignment = NSTextAlignmentCenter;
        _debriefingLabel.numberOfLines = 0;
        _debriefingLabel.text = [self debriefingMessage];
        
    
        // One larger than desired because we always decrement the first iteration of the while loop
        CGFloat actualFontSize = 17.0;
        CGSize actualLabelSize;
        CGSize extraLargeSize = CGSizeMake(_debriefingLabel.size.width, 2 * _debriefingLabel.size.height);
        
        // To determine an appropriate font size that will fit this area, loop until the largest
        // font size that doesn't get cropped
        do {
            actualFontSize -= 1;
            actualLabelSize = [_debriefingLabel.text sizeWithFont:[UIFont fontWithSize:actualFontSize]
                                                constrainedToSize:extraLargeSize
                                                    lineBreakMode:NSLineBreakByWordWrapping];
        } while (actualLabelSize.height > _debriefingLabel.height);
        
        // The text is too long if it doesn't fit at 12.0
        assert(actualFontSize >= 12.0);
        
        _debriefingLabel.font = [UIFont fontWithSize:actualFontSize];
    }
    return _debriefingLabel;
}

- (UIButton *)continueButton
{
    if (!_continueButton) {
        _continueButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, self.window.width / 2, 64)];
        [_continueButton addTarget:self action:@selector(handleContinueButtonTouch:) forControlEvents:UIControlEventTouchUpInside];
        _continueButton.titleLabel.font = [UIFont fontWithSize:18.0];
        [_continueButton setTitle:NSLocalizedString(@"Debriefing-ContinueButton-Title", @"CONTINUE") forState:UIControlStateNormal];
        
        UIColor *color = (self.starCount > 0) ? [UIColor colorWithPatternImage:[RMGradientLabel gradientImageForColor:[UIColor greenColor] label:_continueButton.titleLabel]] : [UIColor blueTextColor];
        [_continueButton setTitleColor:color forState:UIControlStateNormal];
        [_continueButton setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
        
        NSString *thumbnailName = (self.starCount > 0) ? @"debriefingContinueChevronGreen.png" : @"debriefingContinueChevron.png";
        [_continueButton setImage:[UIImage imageNamed:thumbnailName] forState:UIControlStateNormal];
        [_continueButton setImage:[[UIImage imageNamed:thumbnailName] tintedImageWithColor:[UIColor colorWithWhite:1.0 alpha:0.65]] forState:UIControlStateHighlighted];
        
        _continueButton.titleEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 38);
        _continueButton.imageEdgeInsets = UIEdgeInsetsMake(0, _continueButton.width - 44, 0, 0);
    }
    return _continueButton;
}

- (UIButton *)retryButton
{
    if (!_retryButton) {
        _retryButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, self.window.width / 2, 64)];
        [_retryButton addTarget:self action:@selector(handleRetryButtonTouch:) forControlEvents:UIControlEventTouchUpInside];
        _retryButton.titleLabel.font = [UIFont fontWithSize:18.0];
        
        NSString *title = (self.starCount > 0) ? NSLocalizedString(@"Debriefing-RetryButton-Replay", @"REPLAY?") : NSLocalizedString(@"Debriefing-RetryButton-TryAgain", @"TRY AGAIN");
        [_retryButton setTitle:title forState:UIControlStateNormal];
        
        UIColor *color = (self.starCount > 0) ? [UIColor blueTextColor] : [UIColor colorWithPatternImage:[RMGradientLabel gradientImageForColor:[UIColor greenColor] label:_retryButton.titleLabel]];
        [_retryButton setTitleColor:color forState:UIControlStateNormal];
        [_retryButton setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
        
        NSString *thumbnailName = (self.starCount > 0) ? @"debriefingRetry.png" : @"debriefingRetryGreen.png";
        [_retryButton setImage:[UIImage imageNamed:thumbnailName] forState:UIControlStateNormal];
        [_retryButton setImage:[[UIImage imageNamed:thumbnailName] tintedImageWithColor:[UIColor colorWithWhite:1.0 alpha:0.65]] forState:UIControlStateHighlighted];
        
        _retryButton.titleEdgeInsets = UIEdgeInsetsMake(0, 20, 0, 0);
        _retryButton.imageEdgeInsets = UIEdgeInsetsMake(0, 6, 0, 0);
    }
    return _retryButton;
}

- (UIView *)successStar
{
    UIView *successStar = [[UIView alloc] initWithFrame:CGRectZero];
    
    UIImageView *star = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"debriefingStar.png"]];
    successStar.size = star.size;
    [successStar addSubview:star];
    
    if ([UIDevice currentDevice].isFastDevice) {
        UIImageView *successBurst1 = [self successBurst1];
        successBurst1.center = CGPointMake(successStar.width / 2.0, successStar.height / 2.0);
        [successStar insertSubview:successBurst1 atIndex:0];
        
        UIImageView *successBurst2 = [self successBurst2];
        successBurst2.center = CGPointMake(successStar.width / 2.0, successStar.height / 2.0);
        [successStar insertSubview:successBurst2 atIndex:0];
    }
    
    return successStar;
}

- (UIImageView *)successBurst1
{
    UIImageView *successBurst1 = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"debriefingSuccessBurst1.png"]];
    
    CABasicAnimation *fullRotation = [CABasicAnimation animationWithKeyPath:@"transform.rotation"];
    fullRotation.fromValue = @(0.0);
    fullRotation.toValue = @(DEG2RAD(360.0));
    fullRotation.duration = 6.0;
    fullRotation.repeatCount = HUGE_VALF;
    [successBurst1.layer addAnimation:fullRotation forKey:@"fullRotation"];
    
    return successBurst1;
}

- (UIImageView *)successBurst2
{
    UIImageView *successBurst2 = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"debriefingSuccessBurst2.png"]];
    
    CABasicAnimation *fullRotation = [CABasicAnimation animationWithKeyPath:@"transform.rotation"];
    fullRotation.fromValue = @(0.0);
    fullRotation.toValue = @(DEG2RAD(-360.0));
    fullRotation.duration = 8.0;
    fullRotation.repeatCount = HUGE_VALF;
    [successBurst2.layer addAnimation:fullRotation forKey:@"fullRotation"];
    
    return successBurst2;
}

#pragma mark - Button Handlers

- (void)handleRetryButtonTouch:(UIButton *)retryButton
{
    [RMSoundEffect playForegroundEffectWithName:generalButtonSound repeats:NO gain:1.0];
    if (self.starCount > 0) {
        self.continueOnCompletion = NO;
        [self presentDelayedUnlockableAtIndex:0];
    } else {
        [self.delegate debriefingVCDidSelectTryAgain:self];
    }
}

- (void)handleContinueButtonTouch:(UIButton *)continueButton
{
    if (self.starCount > 0 && !self.showingUnlockables && self.achievedUnlockables.count) {
        [RMSoundEffect playForegroundEffectWithName:unlockButtonSound repeats:NO gain:1.0];
        [self collapseStars];
    } else {
        [RMSoundEffect playForegroundEffectWithName:generalButtonSound repeats:NO gain:1.0];
        self.continueOnCompletion = YES;
        [self presentDelayedUnlockableAtIndex:0];
    }
}

#pragma mark - Animation

- (void)animateClaws
{
    self.leftClaw = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"debriefingLeftClaw.png"]];
    self.leftClaw.right = -self.window.left - 64;
    self.leftClaw.centerY = 1.0;
    [self.window addSubview:self.leftClaw];
    
    self.rightClaw = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"debriefingRightClaw.png"]];
    self.rightClaw.left = self.window.width + (self.view.width - self.window.right) + 64;
    self.rightClaw.centerY = 1.0;
    [self.window addSubview:self.rightClaw];
    
    self.orb = [[RMMissionToken alloc] initWithChapter:self.mission.chapter index:self.mission.index status:RMMissionStatusFailed];
    self.orb.center = CGPointMake(self.rightClaw.left - 15, self.rightClaw.centerY);
    self.orb.userInteractionEnabled = NO;
    [self.window addSubview:self.orb];
    [self.orb stopAnimating];
    
    self.missionLabel.center = CGPointMake(self.window.width / 2, 24);
    self.missionLabel.alpha = 0.0;
    [self.window addSubview:self.missionLabel];
    
    for (int i = 0; i < self.successStars.count; i++) {
        UIImageView *noStar = self.successStars[i];
        noStar.center = CGPointMake(_window.width / 2.0 - 64 + 64*i, 132 - 32);
        noStar.alpha = 0.0;
        [self.window addSubview:noStar];
    }
    
    [UIView animateWithDuration:0.65 delay:0.5 options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         self.leftClaw.left = -self.window.left - 3;
                         self.rightClaw.right = self.window.width + (self.view.width - self.window.right) + 3;
                         
                         self.orb.centerX = self.window.width / 2;
                         
                         self.missionLabel.centerY = 60;
                         self.missionLabel.alpha = 1.0;
                         
                         for (int i = 0; i < self.successStars.count; i++) {
                             UIImageView *noStar = self.successStars[i];
                             noStar.center = CGPointMake(_window.width / 2.0 - 64 + 64*i, 132);
                             noStar.alpha = 1.0;
                         }
                     } completion:^(BOOL finished) {
                         [self animateStatus];
                     }];
}

- (void)animateStatus
{
    self.statusLabel.transform = CGAffineTransformMakeScale(4.5, 4.5);
    self.statusLabel.top = self.view.height;
    self.statusLabel.centerX = self.window.width / 2;
    [self.window addSubview:self.statusLabel];
    
    float animationDelay = 1.85f;
    
    if (self.starCount > 0) {
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(animationDelay * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self animateShootingStars];
        });
    }
    
    NSString *successSoundToPlay = [NSString stringWithFormat:successSound, (arc4random_uniform(2) + 1)];
    [RMSoundEffect playBackgroundEffectWithName:self.starCount ? successSoundToPlay : failureSound repeats:NO gain:1.0];
    
    [UIView animateWithDuration:0.35 delay:animationDelay options:UIViewAnimationOptionCurveLinear
                     animations:^{
                         self.statusLabel.transform = CGAffineTransformIdentity;
                         
                         CGFloat w = self.missionLabel.width + self.statusLabel.width + 10;
                         self.missionLabel.left = (self.window.width - w) / 2.0;
                         self.statusLabel.origin = CGPointMake((self.window.width + w) / 2.0 - self.statusLabel.width,
                                                               self.missionLabel.top - (self.statusLabel.height - self.missionLabel.height) / 2.0);
                     } completion:^(BOOL finished) {
                         if (self.starCount > 0) {
                             [self animateSuccessStars];
                             [self animateShootingStars];
                         } else {
                             [self animateHint];
                         }
                     }];
}

- (void)animateSuccessStars
{
    for (int i = 0; i < self.starCount; i++) {
        UIView *emptyStar = self.successStars[i];
        UIView *successStar = [self successStar];
        successStar.alpha = 0.0;
        successStar.center = [self.successStars[i] center];
        [self.window addSubview:successStar];
        [self.successStars replaceObjectAtIndex:i withObject:successStar];
        
        double delayInSeconds = 0.65 * (i + 1);
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            successStar.alpha = 1.0;
            [emptyStar removeFromSuperview];
            
            [RMSoundEffect playForegroundEffectWithName:[NSString stringWithFormat:nthStarSound, i+1] repeats:NO gain:1.0];
            
            if (i == self.starCount - 1) {
                [self pulseSuccessStars];
                [self animateHint];
            }
        });
    }
}

- (void)pulseSuccessStars
{
    for (int i = 0; i < self.starCount; i++) {
        UIView *successStar = self.successStars[i];
        [UIView animateWithDuration:0.25 delay:0.4*i options:UIViewAnimationOptionCurveEaseIn
                         animations:^{
                             successStar.transform = CGAffineTransformMakeScale(1.1, 1.1);
                         } completion:^(BOOL finished) {
                             if (finished && !self.showingUnlockables) {
                                 [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut
                                                  animations:^{
                                                      successStar.transform = CGAffineTransformIdentity;
                                                  } completion:^(BOOL finished) {
                                                      double delayInSeconds = 2.0;
                                                      dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                                                      dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                                                          if (finished && i == self.starCount - 1 && !self.showingUnlockables) {
                                                              [self pulseSuccessStars];
                                                          }
                                                      });
                                                  }];
                             }
                         }];
    }
}

- (void)animateShootingStars
{
    int shootingStarCount = [UIDevice currentDevice].isFastDevice ? 80 : 40;
    for (int i = 0; i < shootingStarCount; i++) {
        UIImageView *star = [self randomStar];
        star.center = self.orb.center;
        star.transform = CGAffineTransformMakeScale(0.25, 0.25);
        [self.window insertSubview:star belowSubview:self.orb];
        
        CGFloat randomDelay = (float)(arc4random() % 2500) / 1000.0;
        CGFloat randomDuration = 1.0 + (float)(arc4random() % 500) / 1000.0;
        [UIView animateWithDuration:randomDuration delay:randomDelay options:UIViewAnimationOptionCurveEaseIn
                         animations:^{
                             [self animateShootingStar:star];
                         } completion:^(BOOL finished) {
                             [star removeFromSuperview];
                         }];
    }
    
    self.starTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(shootStar) userInfo:nil repeats:NO];
}

- (void)shootStar
{
    [self.starTimer invalidate];
    
    UIImageView *star = [self randomStar];
    star.center = self.orb.center;
    star.transform = CGAffineTransformMakeScale(0.25, 0.25);
    [self.window insertSubview:star belowSubview:self.orb];
    
    CGFloat randomDuration = 1.0 + (float)(arc4random() % 500) / 1000.0;
    [UIView animateWithDuration:randomDuration delay:0.0 options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
                         [self animateShootingStar:star];
                     } completion:^(BOOL finished) {
                         [star removeFromSuperview];
                     }];
    
    if (self.view.superview) {
        BOOL fast = [UIDevice currentDevice].isFastDevice;
        CGFloat randomDelay = (fast ? 0 : 0.15) + (float)(arc4random() % 25) / 100.0;
        self.starTimer = [NSTimer scheduledTimerWithTimeInterval:randomDelay target:self selector:@selector(shootStar) userInfo:nil repeats:NO];
    }
}

- (void)animateShootingStar:(UIImageView *)star
{
    star.transform = CGAffineTransformMakeScale(1.25, 1.25);
    
    CGFloat randomTheta = DEG2RAD((float)(arc4random() % 3600) / 10.0);
    CGFloat radius = 90.0 + MAX(self.view.width, self.view.height);
    CGFloat x = radius * sin(randomTheta);
    CGFloat y = radius * cos(randomTheta);
    star.center = CGPointMake(x, y);
}

- (void)animateHint
{
    self.debriefingLabel.center = CGPointMake(self.window.width / 2, self.window.height / 2 + 44);
    self.debriefingLabel.alpha = 0.0;
    [self.window addSubview:self.debriefingLabel];
    
    [UIView animateWithDuration:0.25
                     animations:^{
                         self.debriefingLabel.alpha = 1.0;
                     } completion:^(BOOL finished) {
                         [self animateControls];
                     }];
}

- (void)animateControls
{
    UIImageView *bar = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"debriefingWindowBar.png"]];
    bar.centerX = self.window.width / 2;
    bar.bottom = self.window.height - 10;
    bar.alpha = 0.0;
    [self.window addSubview:bar];
    
    if (self.starCount > 0) {
        self.continueButton.bottom = bar.bottom;
        if (self.achievedUnlockables.count) {
            self.continueButton.centerX = self.window.width / 2.0 + 8;
            self.continueButton.alpha = 0.0;
            [self.window addSubview:self.continueButton];
            
            [UIView animateWithDuration:0.65
                             animations:^{
                                 bar.alpha = 1.0;
                                 self.continueButton.alpha = 1.0;
                             }];
        } else {
            bar.alpha = 1.0;
            [self reanimateControls];
        }
    } else {
        self.retryButton.bottom = bar.bottom;
        self.retryButton.alpha = 0.0;
        [self.window addSubview:self.retryButton];
        
        self.continueButton.bottom = bar.bottom;
        self.continueButton.right = self.window.width;
        self.continueButton.alpha = 0.0;
        [self.window addSubview:self.continueButton];
        
#ifdef FAST_MISSIONS
        UIButton *replayButton = [[UIButton alloc] initWithFrame:CGRectMake(12, bar.top - 32, 140, 40)];
        replayButton.backgroundColor = [UIColor redColor];
        [replayButton setTitle:@"RUN AGAIN" forState:UIControlStateNormal];
        [replayButton addTarget:self.delegate action:@selector(replay) forControlEvents:UIControlEventTouchUpInside];
        [self.window addSubview:replayButton];
#endif
        
        [UIView animateWithDuration:0.65
                         animations:^{
                             bar.alpha = 1.0;
                             self.retryButton.alpha = 1.0;
                             self.continueButton.alpha = 1.0;
                         }];
    }
}

- (void)collapseStars
{
    self.showingUnlockables = YES;
    
    [UIView animateWithDuration:0.65
                     animations:^{
                         self.missionLabel.top -= 60;
                         self.missionLabel.alpha = 0.0;
                         
                         self.statusLabel.top -= 60;
                         self.statusLabel.alpha = 0.0;
                         
                         self.debriefingLabel.top -= 60;
                         self.debriefingLabel.alpha = 0.0;
                         
                         for (int i = 1; i <= self.successStars.count; i++) {
                             UIView *successStar = self.successStars[i - 1];
                             successStar.transform = CGAffineTransformMakeScale(0.25, 0.25);
                             successStar.center = CGPointMake(self.window.width / 2.0 - 17.5 + 17.5*(i-1), self.orb.bottom - 10 - (i % 2) * 4.5);
                         }
                     } completion:^(BOOL finished) {
                         [self.missionLabel removeFromSuperview];
                         [self.debriefingLabel removeFromSuperview];
                         [self animateUnlockables];
                     }];
}

- (void)animateUnlockables
{
    // For now, the only unlockables we show to users are actions
    NSMutableArray *unlockedItems = [NSMutableArray arrayWithCapacity:self.achievedUnlockables.count];
    for (RMUnlockable *unlockable in self.achievedUnlockables) {
        UIView *unlockedItem = nil;
        switch (unlockable.type) {
            case RMUnlockableChapter: {
                int chapter = [unlockable.value intValue];
                unlockedItem = [[RMChapterPlanet alloc] initWithChapter:chapter status:RMChapterStatusNew];
                break;
            }
                
            case RMUnlockableAction: {
                unlockedItem = [[RMActionIcon alloc] initWithAction:unlockable.value];
                break;
            }

            case RMUnlockableEvent: {
                RMEventIcon *unlockedEventIcon = [[RMEventIcon alloc] initWithEvent:unlockable.value];
                unlockedEventIcon.showsTitle = YES;
                unlockedItem = unlockedEventIcon;
                break;
            }
                
            default: break;
        }
        
        unlockedItem.transform = CGAffineTransformMakeScale(2.5, 2.5);
        unlockedItem.top = self.view.height - self.window.top;
        unlockedItem.centerX = self.window.width / 2.0 + (unlockedItems.count * 64);
        unlockedItem.userInteractionEnabled = NO;
        [unlockedItems addObject:unlockedItem];
        [self.window addSubview:unlockedItem];
    }
    
    UILabel *unlockedLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    unlockedLabel.backgroundColor = [UIColor clearColor];
    unlockedLabel.textColor = [UIColor whiteColor];
    unlockedLabel.font = [UIFont largeFont];
    unlockedLabel.text = NSLocalizedString(@"Unlocked-Title",@"UNLOCKED");
    unlockedLabel.size = [unlockedLabel.text sizeWithFont:unlockedLabel.font];
    unlockedLabel.center = CGPointMake(self.window.width / 2.0, self.window.height / 2.0 - 82);
    unlockedLabel.alpha = 0.0;
    [self.window addSubview:unlockedLabel];
    
    if (unlockedItems.count) {
        CGFloat w = 108;
        for (int i = 0; i < unlockedItems.count; i++) {
            UIImageView *unlockedIcon = unlockedItems[i];
            
            [UIView animateWithDuration:0.35 delay:0.2 * i options:UIViewAnimationOptionCurveLinear
                             animations:^{
                                 CGFloat centerX = (self.window.width / 2.0) - ((w / 2.0) * (int)(unlockedItems.count / 2)) + (w * i);
                                 if ([unlockedIcon isKindOfClass:[RMActionIcon class]]) {
                                     unlockedIcon.transform = CGAffineTransformIdentity;
                                 } else if ([unlockedIcon isKindOfClass:[RMChapterPlanet class]]) {
                                     unlockedIcon.transform = CGAffineTransformMakeScale(0.75, 0.75);
                                 } else {
                                     unlockedIcon.transform = CGAffineTransformIdentity;
                                 }

                                 unlockedIcon.center = CGPointMake(centerX, self.window.height / 2.0 + 4.0);
                                 if (i == 0) {
                                     unlockedLabel.alpha = 1.0;
                                 }
                             } completion:^(BOOL finished) {
                                 // TODO: Clean this logic up, shouldn't be checking for this selector
                                 if ([unlockedIcon respondsToSelector:@selector(startAnimating)]) {
                                     [unlockedIcon startAnimating];
                                 }
                                 
                                 if (i == unlockedItems.count - 1) {
                                     [self reanimateControls];
                                 }
                             }];
        }
    } else {
        [self reanimateControls];
    }
}

- (void)reanimateControls
{
    self.continueButton.centerX = self.window.width / 2.0 + 8;
    self.continueButton.alpha = 0.0;
    [self.window addSubview:self.continueButton];
    
    [UIView animateWithDuration:0.65
                     animations:^{
                         self.continueButton.alpha = 1.0;
                     }];
}

#pragma mark - Unlockables

- (void)presentDelayedUnlockable:(RMUnlockable *)unlockable completion:(void (^)())completion
{
    self.completion = completion;
    
    if ([unlockable.value isEqual:RMRomoRateAppKey]) {
        BOOL achieved = [[RMProgressManager sharedInstance] achieveUnlockable:unlockable];
        
        if (achieved) {
            UIAlertView* rateAlert = [[UIAlertView alloc] init];
            rateAlert.title = NSLocalizedString(@"RateApp-Alert-Title", @"Rate Me Five Stars!");
            rateAlert.message = NSLocalizedString(@"RateApp-Alert-Message", @"Your app review encourages me to keep training!");
            rateAlert.delegate = self;
            rateAlert.cancelButtonIndex = 0;
            [rateAlert addButtonWithTitle:NSLocalizedString(@"RateApp-Alert-No", @"No thanks")];
            [rateAlert addButtonWithTitle:NSLocalizedString(@"RateApp-Alert-Yes", @"Rate App")];
            [rateAlert show];
        } else {
            if (completion) {
                completion();
                self.completion = nil;
            }
        }
    } else if ([unlockable.value isEqualToString:RMRepeatUnlockedKey]) {
        [[RMProgressManager sharedInstance] achieveUnlockable:unlockable];
        if (completion) {
            completion();
            self.completion = nil;
        }
    }
}

#pragma mark - Private Methods

- (void)presentDelayedUnlockableAtIndex:(int)index
{
    if (index < self.delayedUnlockables.count) {
        [self presentDelayedUnlockable:self.delayedUnlockables[index]
                            completion:^{
                                [self presentDelayedUnlockableAtIndex:index + 1];
                            }];
    } else {
        if (self.continueOnCompletion) {
            [self.delegate debriefingVCDidSelectContinue:self];
        } else {
            [self.delegate debriefingVCDidSelectReplay:self];
        }
    }
}

- (UIImageView *)randomStar
{
    CGFloat randomSize = 4 + (arc4random() % 30);
    
    UIImageView *randomStar = [[UIImageView alloc] initWithFrame:CGRectZero];
    randomStar.size = CGSizeMake(randomSize, randomSize);
    
    int randomColor = arc4random() % 2;
	if (randomColor) {
		randomStar.image = [UIImage imageNamed:@"purpleStar.png"];
	} else {
		randomStar.image = [UIImage imageNamed:@"blueStar.png"];
    }
    
    return randomStar;
}

- (NSString *)debriefingMessage
{
    if (self.starCount == 3) {
        return self.mission.congratsDebriefing;
    } else if (self.starCount) {
        return [NSLocalizedString(@"Debriefing-HINT:", @"HINT: ") stringByAppendingString:self.mission.successDebriefing];
    } else {
        switch (self.mission.reasonForFailing) {
            case RMMissionFailureReasonNone: return self.mission.successDebriefing;
            case RMMissionFailureReasonWrongInput: return [NSLocalizedString(@"Debriefing-HINT:", @"HINT: ")  stringByAppendingString:self.mission.failureDebriefing];
            case RMMissionFailureReasonUndocked: return NSLocalizedString(@"Debriefing-FailForRobotDisconnect", @"You can't undock me before I complete my mission!");
            case RMMissionFailureReasonFlipped: return NSLocalizedString(@"Debriefing-FailForFlip", @"There's no way I'm gonna win the Robot Space Race if I keep flipping over.");
            case RMMissionFailureReasonTilting: return NSLocalizedString(@"Debriefing-FailForTilt", @"I couldn't tilt all the way. Make sure we're training on flat ground!");
            case RMMissionFailureReasonTimedOut: return NSLocalizedString(@"Debriefing-FailForTimeout", @"Time ran out! Let's try again.");
            case RMMissionFailureReasonTurning: return NSLocalizedString(@"Debriefing-FailForTurn", @"I got stuck when trying to turn! Make sure I'm on solid ground & there's nothing in my way.");
        }
    }
}

@end
