//
//  RMDockingRequiredVC.m
//  Romo
//

#import "RMDockingRequiredVC.h"
#import <RMCore/RMCore.h>
#import <RMShared/UIDevice+Hardware.h>
#import "UIView+Additions.h"
#import "UIFont+RMFont.h"
#import "RMGradientLabel.h"
#import "RMMissionEditorVC.h"
#import "RMPopupWebview.h"
#import "UIButton+RMButtons.h"
#import "RMSoundEffect.h"

NSString *const RMRomoControlAppStoreURL = @"https://itunes.apple.com/us/app/romo-x-control/id1436338304";

@interface RMDockingRequiredVC () <UIAlertViewDelegate>

@property (nonatomic, strong) RMGradientLabel *titleLabel;
@property (nonatomic, strong) UIButton *dismissButton;
@property (nonatomic, strong) RMPopupWebview *buyRomoView;
@property (nonatomic, strong) UIButton *purchaseButton;
@property (nonatomic, strong) UIButton *controlButton;

@end

@implementation RMDockingRequiredVC

#pragma mark -- View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    CGFloat heightOffset = self.view.height <= 480 ? 40 : 0;
    
    UIImageView *background = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"dockingBackground.png"]];
    background.contentMode = UIViewContentModeBottom;
    background.frame = self.view.bounds;
    background.height = self.view.height + heightOffset;
    [self.view addSubview:background];
    
    BOOL lightning = [UIDevice currentDevice].hasLightningConnector;
    NSString *connectorName = lightning ? @"Lightning" : @"ThirtyPin";
    
    UIImageView *connector = [[UIImageView alloc] initWithImage:[UIImage imageNamed:[NSString stringWithFormat:@"docking%@Connector.png", connectorName]]];
    connector.centerX = self.view.width / 2;
    connector.top = self.view.height - (lightning ? 231 : 234) + heightOffset;
    [self.view addSubview:connector];
    
    UIImageView *stars = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"dockingStars.png"]];
    stars.origin = CGPointMake(5, 0);
    [self.view addSubview:stars];
    
    UIImageView *connectorIcon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:[NSString stringWithFormat:@"docking%@Icon.png",connectorName]]];
    connectorIcon.center = CGPointMake(self.view.width / 2, 66);
    [self.view addSubview:connectorIcon];
    
    [self.view addSubview:self.titleLabel];
    
    UILabel *subtitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 164, self.view.width, 54)];
    subtitleLabel.text = NSLocalizedString(@"DockingRequired-Subtitle", @"Before we get started, please\nconnect me to my base!");
    subtitleLabel.textColor = [UIColor whiteColor];
    subtitleLabel.font = [UIFont fontWithSize:20];
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    subtitleLabel.numberOfLines = 2;
    subtitleLabel.backgroundColor = [UIColor clearColor];
    [self.view addSubview:subtitleLabel];
    
    [self.view addSubview:self.controlButton];
    
    if (self.showsPurchaseButton) {
        self.controlButton.center = CGPointMake(self.view.width / 2, self.view.height - self.controlButton.height/2 - 48);
    } else {
        self.controlButton.center = CGPointMake(self.view.width / 2.0, self.view.height - self.controlButton.height/2 - 12);
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
#if !defined(USE_SIMULATED_ROBOT) || defined(SOUND_DEBUG)
    [RMSoundEffect playForegroundEffectWithName:creaturePowerDownSound repeats:NO gain:1.0];
#endif
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleRobotDidConnectNotification:)
                                                 name:RMCoreRobotDidConnectNotification
                                               object:nil];
    
#ifdef DEBUG
#ifdef USE_SIMULATED_ROBOT
    double delayInSeconds = 1.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [RMCore connectToSimulatedRobot];
    });
#endif
#endif
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Public Properties

- (void)setShowsDismissButton:(BOOL)showsDismissButton
{
    if (showsDismissButton != _showsDismissButton) {
        _showsDismissButton = showsDismissButton;
        
        if (showsDismissButton) {
            [self.view addSubview:self.dismissButton];
        } else {
            [self.dismissButton removeFromSuperview];
        }
    }
}

- (void)setShowsPurchaseButton:(BOOL)showsPurchaseButton
{
    if (showsPurchaseButton != _showsPurchaseButton) {
        _showsPurchaseButton = showsPurchaseButton;
        
        if (showsPurchaseButton) {
            self.controlButton.centerY = self.view.height - self.controlButton.height/2 - 48;
            self.purchaseButton.center = CGPointMake(self.view.width / 2, self.view.height - self.purchaseButton.height/2 - 16);
            [self.view addSubview:self.purchaseButton];
            
            self.titleLabel.text = NSLocalizedString(@"DockingRequired-Title", @"Wheels, please!");
        } else {
            self.controlButton.centerY = self.view.height - self.controlButton.height/2 - 12;
            [self.purchaseButton removeFromSuperview];
            self.titleLabel.text = NSLocalizedString(@"DockingRequired-titleLabelDefaultText", @"Almost Ready.");
        }
    }
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 1) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:RMRomoControlAppStoreURL]];
    }
}

#pragma mark - Private methods

- (UIButton *)purchaseButton
{
    if (!_purchaseButton) {
        _purchaseButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, self.view.width - 100, 48)];
        [_purchaseButton addTarget:self action:@selector(handlePurchaseButtonTouch:) forControlEvents:UIControlEventTouchUpInside];
        _purchaseButton.showsTouchWhenHighlighted = YES;
        
        UILabel *purchaseLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 0, 48)];
        purchaseLabel.text = NSLocalizedString(@"DockingRequired-BuyButton-Title", @"Adopt a Romo now");
        purchaseLabel.textColor = [UIColor whiteColor];
        purchaseLabel.font = [UIFont fontWithSize:20];
        purchaseLabel.textAlignment = NSTextAlignmentCenter;
        purchaseLabel.backgroundColor = [UIColor clearColor];
        purchaseLabel.width = [purchaseLabel.text sizeWithFont:purchaseLabel.font].width;
        purchaseLabel.centerX = _purchaseButton.width / 2;
        [_purchaseButton addSubview:purchaseLabel];
        
        UIView *underscore = [[UIView alloc] initWithFrame:CGRectMake(purchaseLabel.left, purchaseLabel.bottom - 16, purchaseLabel.width, 1)];
        underscore.backgroundColor = [UIColor whiteColor];
        [_purchaseButton addSubview:underscore];
    }
    return _purchaseButton;
}

- (UIButton *)controlButton
{
    if (!_controlButton) {
        _controlButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, self.view.width - 100, 48)];
        [_controlButton addTarget:self action:@selector(handleControlButtonTouch:) forControlEvents:UIControlEventTouchUpInside];
        _controlButton.showsTouchWhenHighlighted = YES;
        
        UILabel *controlLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 0, 48)];
        controlLabel.text = NSLocalizedString(@"DockingRequired-controlButtonTitle", @"Control another Romo");
        controlLabel.textColor = [UIColor whiteColor];
        controlLabel.font = [UIFont fontWithSize:20];
        controlLabel.textAlignment = NSTextAlignmentCenter;
        controlLabel.backgroundColor = [UIColor clearColor];
        controlLabel.width = [controlLabel.text sizeWithFont:controlLabel.font].width;
        controlLabel.centerX = _controlButton.width / 2;
        [_controlButton addSubview:controlLabel];

        UIView *underscore = [[UIView alloc] initWithFrame:CGRectMake(controlLabel.left, controlLabel.bottom - 16, controlLabel.width, 1)];
        underscore.backgroundColor = [UIColor whiteColor];
        [_controlButton addSubview:underscore];
    }
    return _controlButton;
}

- (UIButton *)dismissButton
{
    if (!_dismissButton) {
        _dismissButton = [UIButton backButtonWithImage:nil];
        [_dismissButton addTarget:self action:@selector(handleDismissButtonTouch:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _dismissButton;
}

- (RMGradientLabel *)titleLabel
{
    if (!_titleLabel) {
        _titleLabel = [[RMGradientLabel alloc] initWithFrame:CGRectMake(0, 122, self.view.width, 36)];
        _titleLabel.text = NSLocalizedString(@"DockingRequired-titleLabelDefaultText", nil);
        _titleLabel.gradientColor = [UIColor greenColor];
        _titleLabel.font = [UIFont fontWithSize:29.5];
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.backgroundColor = [UIColor clearColor];
    }
    return _titleLabel;
}

- (RMPopupWebview *)buyRomoView
{
    if (!_buyRomoView) {
        _buyRomoView = [[RMPopupWebview alloc] initWithFrame:[UIScreen mainScreen].bounds];
        NSURLRequest *requestStore = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:@"https://www.amazon.com/s?field-keywords=romotive"]];
        [_buyRomoView.webView loadRequest:requestStore];
        [_buyRomoView.dismissButton addTarget:self action:@selector(handleDismissBuyRomoViewButtonTouch:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _buyRomoView;
}

- (void)handleRobotDidConnectNotification:(NSNotification *)notification
{
#if !defined(USE_SIMULATED_ROBOT) || defined(SOUND_DEBUG)
    [RMSoundEffect playBackgroundEffectWithName:creaturePowerUpSound repeats:NO gain:1.0];
#endif
    if (self.childViewControllers.count) {
        [self dismissViewControllerAnimated:YES completion:^{
            [self.delegate dockingRequiredVCDidDock:self];
        }];
    } else {
        [self.delegate dockingRequiredVCDidDock:self];
    }
}

- (void)handleDismissButtonTouch:(UIButton *)dismissButton
{
    [RMSoundEffect playBackgroundEffectWithName:backButtonSound repeats:NO gain:1.0];
    [self.delegate dockingRequiredVCDidDismiss:self];
}

- (void)handleControlButtonTouch:(UIButton *)driveButton
{
    [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"DockingRequired-RomoControl-Download-Alert-Title", @"Download Romo Control")
                                message:NSLocalizedString(@"DockingRequired-RomoControl-Download-Alert-Message", @"To take control of a Romo, download the all-new Romo Control app from the App Store")
                               delegate:self
                      cancelButtonTitle:NSLocalizedString(@"DockingRequired-RomoControl-Download-Alert-No", @"Don't control")
                      otherButtonTitles:NSLocalizedString(@"DockingRequired-RomoControl-Download-Alert-Yes", @"Download"), nil] show];
}

- (void)handlePurchaseButtonTouch:(UIButton *)getOneButton
{
    self.buyRomoView.top = self.view.bottom;
    [self.view addSubview:self.buyRomoView];
    [UIView animateWithDuration:0.35 delay:0 options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         self.buyRomoView.top = 0;
                     } completion:nil];
}

- (void)handleDismissBuyRomoViewButtonTouch:(UIButton *)dismissButton
{
    [UIView animateWithDuration:0.35 delay:0 options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
                         self.buyRomoView.top = self.view.height;
                     } completion:^(BOOL finished) {
                         [self.buyRomoView removeFromSuperview];
                         self.buyRomoView = nil;
                     }];
}

@end
