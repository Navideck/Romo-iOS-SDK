//
//  RMCharacterUnlockedVC.m
//  Romo
//

#import "RMCharacterUnlockedRobotController.h"
#import "UIView+Additions.h"
#import "UIFont+RMFont.h"
#import "UIButton+SoundEffects.h"
#import "UIImage+Tint.h"
#import "RMFaceActionIcon.h"
#import "RMFaceActionView.h"
#import "RMSpaceScene.h"
#import "RMSoundEffect.h"
#import "RMGradientLabel.h"

@interface RMCharacterUnlockedRobotController ()

@property (nonatomic) RMCharacterExpression expression;

/** UI */
@property (nonatomic, strong) RMFaceActionIcon *faceIcon;
@property (nonatomic, strong) UIImageView *window;
@property (nonatomic, strong) UIButton *continueButton;

@property (nonatomic, strong) NSTimer *autoDismissTimer;

@end

@implementation RMCharacterUnlockedRobotController

- (id)initWithExpression:(RMCharacterExpression)expression
{
    self = [super init];
    if (self) {
        _expression = expression;
    }
    return self;
}

- (RMRomoFunctionalities)initiallyActiveFunctionalities
{
    // Only allow the character
    return RMRomoFunctionalityCharacter | RMRomoFunctionalityBroadcasting;
}

- (RMRomoInterruptions)initiallyAllowedInterruptions
{
    // Don't allow any interruptions
    return RMRomoInterruptionNone;
}

- (UIView *)characterView
{
    return nil;
}

- (void)controllerDidBecomeActive
{
    [super controllerDidBecomeActive];
    
    // As a precautionary measure, stop all motion
    [self.Romo.robot stopDriving];
    
    RMSpaceScene *spaceScene = [[RMSpaceScene alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:spaceScene];
    
    [self.view addSubview:self.window];
    
    self.faceIcon.title = [RMFaceActionView nameForExpression:self.expression];
    self.faceIcon.expression = self.expression;
    self.faceIcon.center = CGPointMake(self.view.width / 2.0, self.view.height / 2.0 - 32);
    self.faceIcon.transform = CGAffineTransformMakeScale(5.5, 5.5);
    [self.view addSubview:self.faceIcon];
    
    UIView *characterView = [[UIView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:characterView];
    [self.Romo.character addToSuperview:characterView];
    
    [RMSoundEffect playForegroundEffectWithName:unlockButtonSound repeats:NO gain:1.0];
    [UIView animateWithDuration:0.65
                     animations:^{
                         CGFloat xScale = 54 / self.view.width;
                         CGFloat yScale = 81 / self.view.height;
                         characterView.transform = CGAffineTransformMakeScale(xScale, yScale);
                         characterView.centerY = self.view.height / 2.0 - 32;
                         characterView.alpha = 0.0;
                         
                         self.faceIcon.transform = CGAffineTransformIdentity;
                         self.faceIcon.center = CGPointMake(self.view.width / 2.0, self.view.height / 2.0 - 32);
                         
                         self.window.centerY = self.view.height / 2.0;
                     } completion:^(BOOL finished) {
                         [characterView removeFromSuperview];
                         self.Romo.activeFunctionalities = disableFunctionality(RMRomoFunctionalityCharacter, self.Romo.activeFunctionalities);

                         UIImageView *bar = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"debriefingWindowBar.png"]];
                         bar.centerX = self.window.width / 2;
                         bar.bottom = self.window.height - 10;
                         bar.alpha = 0.0;
                         [self.window addSubview:bar];
                         
                         self.continueButton.bottom = bar.bottom;
                         self.continueButton.centerX = self.window.width / 2.0 + 8;
                         self.continueButton.alpha = 0.0;
                         [self.window addSubview:self.continueButton];
                         
                         UILabel *unlockedLabel = [[UILabel alloc] initWithFrame:CGRectZero];
                         unlockedLabel.backgroundColor = [UIColor clearColor];
                         unlockedLabel.textColor = [UIColor whiteColor];
                         unlockedLabel.font = [UIFont largeFont];
                         unlockedLabel.text = NSLocalizedString(@"Unlocked-Title", @"UNLOCKED:");
                         unlockedLabel.size = [unlockedLabel.text sizeWithFont:unlockedLabel.font];
                         unlockedLabel.center = CGPointMake(self.window.width / 2.0, self.window.height / 2.0 - 116);
                         unlockedLabel.alpha = 0.0;
                         [self.window addSubview:unlockedLabel];
                         
                         UILabel *unlockedMessageLabel = [[UILabel alloc] initWithFrame:CGRectZero];
                         unlockedMessageLabel.backgroundColor = [UIColor clearColor];
                         unlockedMessageLabel.textColor = [UIColor whiteColor];
                         unlockedMessageLabel.font = [UIFont fontWithSize:16.0];
                         unlockedMessageLabel.textAlignment = NSTextAlignmentCenter;
                         unlockedMessageLabel.numberOfLines = 0;
                         unlockedMessageLabel.text = NSLocalizedString(@"Unlock-Message", @"You've discovered a hidden item!");
                         unlockedMessageLabel.size = [unlockedMessageLabel.text sizeWithFont:unlockedMessageLabel.font constrainedToSize:CGSizeMake(self.window.width - 50, 72)];
                         unlockedMessageLabel.alpha = 0.0;
                         unlockedMessageLabel.center = CGPointMake(self.window.width / 2.0, self.window.height / 2.0 + 54);
                         [self.window addSubview:unlockedMessageLabel];
                         
                         [UIView animateWithDuration:0.65
                                          animations:^{
                                              unlockedLabel.alpha = 1.0;
                                              unlockedMessageLabel.alpha = 1.0;
                                              bar.alpha = 1.0;
                                              self.continueButton.alpha = 1.0;
                                          }];
                     }];
    
    // If autoDismissInterval is set > 1, then have a timer dismiss the current view
    if (self.autoDismissInterval > 1) {
        
        if ([self.autoDismissTimer isValid]) {
            [self.autoDismissTimer invalidate];
        }
        
        self.autoDismissTimer = [NSTimer timerWithTimeInterval:self.autoDismissInterval
                                                            target:self
                                                          selector:@selector(autoDismissTimerCallback)
                                                          userInfo:nil
                                                           repeats:NO];
        [[NSRunLoop mainRunLoop] addTimer:self.autoDismissTimer forMode:NSRunLoopCommonModes];
    }
}



#pragma mark - Private Properties

- (RMFaceActionIcon *)faceIcon
{
    if (!_faceIcon) {
        _faceIcon = [[RMFaceActionIcon alloc] initWithFrame:CGRectMake(0, 0, 102, 124)];
        _faceIcon.userInteractionEnabled = NO;
    }
    return _faceIcon;
}

- (UIImageView *)window
{
    if (!_window) {
        _window = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"debriefingWindow.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(37, 0, 37, 0)]];
        _window.frame = CGRectMake(0, -600, 291, 328);
        _window.centerX = self.view.width / 2;
        _window.userInteractionEnabled = YES;
    }
    return _window;
}

- (UIButton *)continueButton
{
    if (!_continueButton) {
        _continueButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, self.window.width / 2, 64)];
        [_continueButton addTarget:self action:@selector(handleContinueButtonTouch:) forControlEvents:UIControlEventTouchUpInside];
        _continueButton.titleLabel.font = [UIFont fontWithSize:18.0];
        [_continueButton setTitle:NSLocalizedString(@"Unlocked-Continue-Button-Title", @"CONTINUE") forState:UIControlStateNormal];
        
        UIColor *color = [UIColor colorWithPatternImage:[RMGradientLabel gradientImageForColor:[UIColor greenColor] label:_continueButton.titleLabel]];
        [_continueButton setTitleColor:color forState:UIControlStateNormal];
        [_continueButton setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
        
        NSString *thumbnailName = @"debriefingContinueChevronGreen.png";
        [_continueButton setImage:[UIImage imageNamed:thumbnailName] forState:UIControlStateNormal];
        [_continueButton setImage:[[UIImage imageNamed:thumbnailName] tintedImageWithColor:[UIColor colorWithWhite:1.0 alpha:0.65]] forState:UIControlStateHighlighted];
        
        _continueButton.titleEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 38);
        _continueButton.imageEdgeInsets = UIEdgeInsetsMake(0, _continueButton.width - 44, 0, 0);
    }
    return _continueButton;
}

#pragma mark - Private Methods

- (void)handleContinueButtonTouch:(UIButton *)continueButton
{
    if ([self.autoDismissTimer isValid]) {
        [self.autoDismissTimer invalidate];
    }
    [RMSoundEffect playForegroundEffectWithName:generalButtonSound repeats:NO gain:1.0];
    [self.delegate dismissCharacterUnlockedVC:self];
}

- (void)autoDismissTimerCallback
{
    [self handleContinueButtonTouch:self.continueButton];
}

@end
