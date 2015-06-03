//
//  RMRomoteDriveVC.m
//  RMRomoteDriveVC
//

#import "RMWiFiDriveRemoteVC.h"
#import "RMCommandSubscriber.h"
#import "RAVService.h"
#import "Analytics/Analytics.h"
#import <RMShared/UIDevice+Hardware.h>
#import "RMAppDelegate.h"
#import "RMAlertView.h"
#import "UIColor+RMColor.h"
#import "RMCommandMessage.h"
#import "UIImage+Save.h"
#import "RMSessionManager.h"
#import "RMRomoteDriveExpressionsPopover.h"
#import "RMRomoteDrivePopoverController.h"
#import "RMJoystick.h"
#import "RMTankSlider.h"
#import "RMDpad.h"
#import "RMTiltController.h"
#import "RMRemoteControlService.h"
#import "RMSession.h"
#import "RMPeer.h"
#import "RMRomotePhotoVC.h"
#import "RMControlDriveActionBar.h"
#import "RMControlInputMenu.h"
#import "UIView+Additions.h"

@interface RMWiFiDriveRemoteVC () <RMRomoteDriveExpressionsPopoverDelegate, RMJoystickDelegate, RMDpadDelegate, RMTiltControllerDelegate, RMSessionDelegate,
RMRemoteControlServiceDelegate, RMTankSliderDelegate> {
    RAVService *_avService;
    RMCommandSubscriber *_commandSubscriber;
    RMRemoteControlService *_romoteService;

    NSMutableArray *_activeDriveViews;
    
    BOOL _hasTilted;
    NSTimer *_tiltHintTimer;
}

@property (nonatomic, strong) RMControlDriveActionBar *actionBar;
@property (nonatomic, strong) RMControlInputMenu *inputMenu;
@property (nonatomic, strong) RMRomoteDriveExpressionsPopover* expressionsPopover;
@property (nonatomic, strong) RMRomoteDrivePopoverController* settingsPopoverController;

@property (nonatomic, strong) NSMutableArray *capturedPhotos;

@property (nonatomic, strong) RMTiltController *tilt;
@property (nonatomic, strong) UIView *videoView;

@property (nonatomic, strong) NSTimer *timeoutTimer;
@property (nonatomic, strong) RMAlertView *failureAlertView;

@property (nonatomic, strong) RMSession *session;
@property (nonatomic, getter=isInSession) BOOL inSession;

@property (nonatomic, strong) UIImageView *flippedRomoIndicator;
@property (nonatomic, strong) UIButton *backButton;

/** If shit's gone down, let's abort and cleanup as best we can */
- (void)shutdownEverything;

@end

@implementation RMWiFiDriveRemoteVC

#pragma mark - View Management

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.frame = [[UIScreen mainScreen] bounds];
    self.view.backgroundColor = [UIColor romoLightGray];
    self.view.clipsToBounds = YES;
    
    self.tilt = [[RMTiltController alloc] initWithFrame:self.view.bounds];
    self.tilt.delegate = self;
    [self.view addSubview:self.tilt];
    
    _activeDriveViews = [NSMutableArray arrayWithCapacity:3];
    self.capturedPhotos = [NSMutableArray arrayWithCapacity:5];
    
    self.wantsFullScreenLayout = YES;
    
    // Create the control menu
    self.inputMenu = [[RMControlInputMenu alloc] initWithFrame:CGRectZero];
    CGSize inputMenuSize = [self.inputMenu desiredSize];
    
    self.backButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.backButton setImage:[UIImage imageNamed:@"drive-back"] forState:UIControlStateNormal];
    
    if (iPad) {
        self.inputMenu.frame = CGRectMake(self.view.right - inputMenuSize.width - 30, 30, inputMenuSize.width, inputMenuSize.height);
        self.backButton.frame = CGRectMake(25, 25, 64, 64);
    } else {
        self.inputMenu.frame = CGRectMake(self.view.right - inputMenuSize.width - 10, 25, inputMenuSize.width, inputMenuSize.height);
        self.backButton.frame = CGRectMake(5, 20, 64, 64);
    }
    
    // Create the action bar
    self.actionBar = [[RMControlDriveActionBar alloc] initWithFrame:CGRectZero];
    self.actionBar.frame = CGRectMake(0, CGRectGetMaxY(self.view.bounds) - [self.actionBar desiredHeight], CGRectGetMaxX(self.view.bounds), [self.actionBar desiredHeight]);
    self.actionBar.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    
    // Add the target-actions
    [self.actionBar.cameraButton addTarget:self action:@selector(didTouchCameraButton:) forControlEvents:UIControlEventTouchUpInside];
    [self.actionBar.photoRollButton addTarget:self action:@selector(didTouchPhotosButton:) forControlEvents:UIControlEventTouchUpInside];
    [self.actionBar.emotionButton addTarget:self action:@selector(didTouchExpressionsButton:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.inputMenu.dpadButton addTarget:self action:@selector(didSelectDPad) forControlEvents:UIControlEventTouchUpInside];
    [self.inputMenu.tankButton addTarget:self action:@selector(didSelectTankDrive) forControlEvents:UIControlEventTouchUpInside];
    [self.inputMenu.joystickButton addTarget:self action:@selector(didSelectJoystick) forControlEvents:UIControlEventTouchUpInside];
    
    [self.backButton addTarget:self action:@selector(didTouchBackButton:) forControlEvents:UIControlEventTouchUpInside];
    
    // Add the subviews
    [self.view addSubview:self.actionBar];
    [self.view addSubview:self.inputMenu];
    [self.view addSubview:self.backButton];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    
    if (!self.isInSession) {
        self.view.backgroundColor = [UIColor colorWithWhite:0.6 alpha:1];
        
        if (self.remotePeer) {
            [self.videoView removeFromSuperview];

            if (!self.session) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    self.session = [[RMSessionManager shared] initiateSessionWithPeer:self.remotePeer];
                    self.session.delegate = self;
                });
                self.timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:3.0 target:self selector:@selector(attemptToConnectFailed) userInfo:nil repeats:NO];
            }

            [self updateDrivingMethod];
        } else {
            [self dismissDriveVC];
        }
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.timeoutTimer invalidate];
    [_tiltHintTimer invalidate];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    [self dismissDriveVC];
}

- (UIView *)characterView
{
    return nil;
}

#pragma mark - SessionDelegate Methods

- (void)sessionBegan:(RMSession *)session
{
    self.inSession = YES;
    [self.timeoutTimer invalidate];

    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.session.state == STATE_CONNECTED) {
            [self startController];
        } else {
            [self attemptToConnectFailed];
        }
    });
}

- (void)session:(RMSession *)session receivedService:(RMService *)service
{
    if ([service isKindOfClass:[RMCommandService class]]) {
        _commandSubscriber = (RMCommandSubscriber *)[service subscribe];
    }
}

- (void)session:(RMSession *)session startedService:(RMService *)service
{
    if ([service isKindOfClass:[RAVService class]]) {
        dispatch_async(dispatch_get_main_queue(), ^() {
            self.videoView = _avService.peerView;
            if ([[UIScreen mainScreen] bounds].size.height == 568) {
                self.videoView.center = CGPointMake(self.view.width/2, self.view.height/2);
            }
            [self.view insertSubview:self.videoView atIndex:0];
            self.view.backgroundColor = [UIColor romoBlack];
        });
    }
}

- (void)session:(RMSession *)session finishedService:(RMService *)service
{
    if ([service isKindOfClass:[RMCommandService class]]) {
        _commandSubscriber = nil;
    }
}

- (void)sessionEnded:(RMSession *)session
{
    [self shutdownEverything];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self dismissDriveVC];
    });
}

#pragma mark - Connecting & Disconnecting

- (void)startController
{
    self.remotePeer = nil;
    
    _avService = [RAVService service];
    [self.session startService:_avService];
    
    _romoteService = [RMRemoteControlService service];
    _romoteService.delegate = self;
    [self.session startService:_romoteService];
    
    _hasTilted = [[NSUserDefaults standardUserDefaults] boolForKey:@"romo-3 has tilted"];
    if (!_hasTilted) {
        _tiltHintTimer = [NSTimer scheduledTimerWithTimeInterval:16.0 target:self selector:@selector(showTiltTip) userInfo:nil repeats:NO];
    }
}

- (void)attemptToConnectFailed
{
    if (!self.inSession) {
        [self dismissDriveVC];
        if (!self.failureAlertView) {
            self.failureAlertView = [[RMAlertView alloc] initWithTitle:NSLocalizedString(@"RomoControl-CallFailed-Title", @"Call Failed") message:NSLocalizedString(@"RomoControl-CallFailed-Message", @"Romo couldn't be reached") delegate:nil];
        }
        [self.failureAlertView show];
    }
}

- (void)shutdownEverything
{
    [self.timeoutTimer invalidate];
    self.timeoutTimer = nil;

    [self.session stopService:_avService];
    [_avService stop];
    _avService = nil;
    
    [self.session stopService:_romoteService];
    [_romoteService stop];
    _romoteService = nil;

    [_commandSubscriber stop];
    _commandSubscriber = nil;
    
    self.remotePeer = nil;
    self.session = nil;
    self.inSession = NO;
}

#pragma mark - UI

- (void)dismissPopovers
{
    if (self.expressionsPopover.top < self.view.height) {
        [UIView animateWithDuration:0.2 animations:^{
            self.expressionsPopover.top = self.view.height;
        } completion:^(BOOL finished) {
            [self.expressionsPopover removeFromSuperview]; 
        }];
        
        [UIView animateWithDuration:0.2 delay:0.2 options:0 animations:^{
            self.actionBar.bottom = self.view.height;
        } completion:nil];
    }
    
    if (self.inputMenu.isOpen) {
        [self.inputMenu closeMenu];
    }
}

- (void)showTiltTip
{
    [_tiltHintTimer invalidate];
    self.tilt.showHint = YES;
}

#pragma mark - Top Bar Delegation

- (void)didTouchBackButton:(UIButton *)backButton
{
    [self dismissDriveVC];
}

#pragma mark - Bottom Bar Delegation

- (void)didTouchPhotosButton:(id)sender
{
    [self dismissPopovers];

    RMRomotePhotoVC *photoVC = [[RMRomotePhotoVC alloc] init];
    photoVC.photos = self.capturedPhotos;
    [photoVC.dismissButton addTarget:self action:@selector(handlePhotoVCDismissButtonTouch:) forControlEvents:UIControlEventTouchUpInside];
    [self presentViewController:photoVC animated:YES completion:nil];
}

- (void)handlePhotoVCDismissButtonTouch:(UIButton *)button
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)didTouchCameraButton:(id)sender
{
    [self dismissPopovers];
    
    [_commandSubscriber sendTakePicture];
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(pictureTimedOut) object:nil];
    [self performSelector:@selector(pictureTimedOut) withObject:nil afterDelay:3.5];
    
    self.actionBar.waitingForPicture = YES;
}

- (void)didTouchExpressionsButton:(id)sender
{
    if (!self.expressionsPopover) {
        self.expressionsPopover = [RMRomoteDriveExpressionsPopover expressionsPopover];
        self.expressionsPopover.popoverDelegate = self;
    }
    self.expressionsPopover.top = self.view.height;
    [self.view addSubview:self.expressionsPopover];
    
    [UIView animateWithDuration:0.2 animations:^{
        self.actionBar.top += self.actionBar.height;
    }];
    
    [UIView animateWithDuration:0.2 delay:0.2 options:0 animations:^{
        self.expressionsPopover.bottom = self.view.height;
    } completion:nil];
}

#pragma mark - RMRomoteDrivePopoverDelegate


- (void)didSelectJoystick
{
    [[NSUserDefaults standardUserDefaults] setObject:@"joystick" forKey:@"romo-3 romo driving-method"];
    [self updateDrivingMethod];
    
    [self.inputMenu closeMenu];
}

- (void)didSelectTankDrive
{
    [[NSUserDefaults standardUserDefaults] setObject:@"tank" forKey:@"romo-3 romo driving-method"];
    [self updateDrivingMethod];
    
    [self.inputMenu closeMenu];
}

- (void)didSelectDPad
{
    [[NSUserDefaults standardUserDefaults] setObject:@"dpad" forKey:@"romo-3 romo driving-method"];
    [self updateDrivingMethod];
    
    [self.inputMenu closeMenu];
}

#pragma mark - Expressions Popover Delegation

- (void)didTouchExpressionsPopoverFace:(RMRomoteDriveExpressionButton *)expressionButton
{
    [_commandSubscriber sendExpression:expressionButton.expression];
}

#pragma mark - Romote Control Service Delegate

- (void)remoteExpressionAnimationDidStart
{
    self.expressionsPopover.enabled = NO;
}

- (void)remoteExpressionAnimationDidFinish
{
    self.expressionsPopover.enabled = YES;
}

- (void)robotDidFlipOver
{
    if (!self.flippedRomoIndicator.superview) {
        if (!self.flippedRomoIndicator) {
            self.flippedRomoIndicator = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"romoFlipped.png"]];
            self.flippedRomoIndicator.center = CGPointMake(self.view.width/2, self.view.height/2);
            self.flippedRomoIndicator.alpha = 0.0;
        }
        [self.view addSubview:self.flippedRomoIndicator];
        
        [UIView animateWithDuration:0.25
                         animations:^{
                             self.flippedRomoIndicator.alpha = 1.0;
                             for (UIView* subview in self.view.subviews) {
                                 if (subview != self.videoView && subview != self.flippedRomoIndicator) {
                                     subview.alpha = 0.0;
                                 }
                             }
                             for (UIView *driveView in _activeDriveViews) {
                                 [driveView touchesCancelled:nil withEvent:nil];
                             }
                         } completion:^(BOOL finished) {
                             [UIView animateWithDuration:0.25 delay:3.0 options:0
                                              animations:^{
                                                  self.flippedRomoIndicator.alpha = 0;
                                                  for (UIView* subview in self.view.subviews) {
                                                      if (subview != self.videoView && subview != self.flippedRomoIndicator) {
                                                          subview.alpha = 1.0;
                                                      }
                                                  }
                                              } completion:^(BOOL finished) {
                                                  [self.flippedRomoIndicator removeFromSuperview];
                                              }];
                         }];
    }
}

- (void)didReceivePicture:(UIImage *)picture
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(pictureTimedOut) object:nil];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UIGraphicsBeginImageContextWithOptions(picture.size, NO, picture.scale);
        [picture drawInRect:(CGRect){0, 0, picture.size}];
        UIImage *reorientedPicture = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        [UIImage writeToSavedPhotoAlbumWithImage:reorientedPicture
                                completionTarget:nil
                              completionSelector:nil
                                     contextInfo:nil];
        
        UIImageView* pictureView = [[UIImageView alloc] initWithImage:reorientedPicture];
        pictureView.frame = self.view.bounds;
        pictureView.contentMode = UIViewContentModeScaleAspectFill;
        pictureView.alpha = 0.5;
        pictureView.backgroundColor = [UIColor clearColor];
        pictureView.clipsToBounds = YES;
        [self.view addSubview:pictureView];
        
        CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"cornerRadius"];
        animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
        animation.fromValue = [NSNumber numberWithFloat:0.0];
        animation.toValue = [NSNumber numberWithFloat:20.0];
        animation.duration = 0.25;
        [pictureView.layer addAnimation:animation forKey:@"cornerRadius"];
        pictureView.layer.cornerRadius = 20.0;
        
        [UIView animateWithDuration:0.35 animations:^{
            pictureView.layer.cornerRadius = 20.0;
            pictureView.alpha = 1.0;
            pictureView.frame = CGRectMake(self.actionBar.left + self.actionBar.photoRollButton.left,
                                           self.actionBar.top + self.actionBar.photoRollButton.top,
                                           self.actionBar.photoRollButton.size.width,
                                           self.actionBar.photoRollButton.size.height);
        } completion:^(BOOL finished) {
            [pictureView removeFromSuperview];
//          self.bottomBar.photosButton.photo = pictureView.image;
        }];
        
        self.actionBar.waitingForPicture = NO;
        [self.capturedPhotos addObject:reorientedPicture];
    });
}

- (void)pictureTimedOut
{
    [self.actionBar pictureDidTimeOut];
}

- (void)dismissDriveVC
{
    [self shutdownEverything];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate dismissDriveVC:self];
    });
}

#pragma mark - Control Method UI

- (void)updateDrivingMethod
{
    [_activeDriveViews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [_activeDriveViews removeAllObjects];

    [self dismissPopovers];

    self.inputMenu.joystickButton.selected = NO;
    self.inputMenu.tankButton.selected = NO;
    self.inputMenu.dpadButton.selected = NO;
    
    NSString *method = [[NSUserDefaults standardUserDefaults] objectForKey:@"romo-3 romo driving-method"];
    if ([method isEqualToString:@"tank"]) {
        [self addTank];
        self.inputMenu.tankButton.selected = YES;
    } else if ([method isEqualToString:@"joystick"]) {
        [self addJoystick];
        self.inputMenu.joystickButton.selected = YES;
    } else if ([method isEqualToString:@"dpad"]) {
        [self addDPad];
        self.inputMenu.dpadButton.selected = YES;
    } else {
        [[NSUserDefaults standardUserDefaults] setObject:@"dpad" forKey:@"romo-3 romo driving-method"];
        [self addDPad];
        self.inputMenu.dpadButton.selected = YES;
    }
    
    for (UIView *subview in _activeDriveViews) {
        subview.alpha = 1.0;
    }
}

- (void)addTank
{
    RMTankSlider *leftTank = [RMTankSlider tankSlider];
    leftTank.bottom = self.actionBar.top - 16;
    leftTank.left = 10;
    leftTank.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    leftTank.delegate = self;
    leftTank.gripperText = @"L";
    [_activeDriveViews addObject:leftTank];
    [self.view addSubview:leftTank];

    RMTankSlider *rightTank = [RMTankSlider tankSlider];
    rightTank.bottom = self.actionBar.top - 16;
    rightTank.right = self.view.width - 10;
    rightTank.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    rightTank.delegate = self;
    rightTank.gripperText = @"R";
    [_activeDriveViews addObject:rightTank];
    [self.view addSubview:rightTank];
}

- (void)addDPad
{
    RMDpad *dPad = [[RMDpad alloc] initWithFrame:CGRectMake(0, 0, 160, 160) imageName:@"R3UI-Dpad" centerSize:CGSizeMake(50, 50)];
    dPad.delegate = self;
    dPad.centerX = self.view.width/2;
    dPad.bottom = self.actionBar.top - 16;
    [self.view addSubview:dPad];
    [dPad setAutoresizingMask:UIViewAutoresizingFlexibleTopMargin];
    [_activeDriveViews addObject:dPad];
}

- (void)addJoystick
{
    int joystickWidth = (iPad) ? 280 : 160;
    RMJoystick *joystick = [[RMJoystick alloc] initWithFrame:CGRectMake(0, 0, joystickWidth, joystickWidth)];
    joystick.delegate = self;
    joystick.centerX = self.view.width/2;
    joystick.bottom = self.actionBar.top - 16;
    joystick.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    [self.view addSubview:joystick];
    [_activeDriveViews addObject:joystick];
}

#pragma mark - Tank Delegate

- (void)slider:(RMTankSlider *)slider didChangeToValue:(CGFloat)sliderValue
{
    static float leftValue = 0;
    static float rightValue = 0;

    if (slider.left < self.view.width / 2) {
        leftValue = sliderValue;
    } else {
        rightValue = sliderValue;
    }

    [_commandSubscriber sendTankSlidersLeft:leftValue right:rightValue];
    [self dismissPopovers];
}

#pragma mark - DPad Delegate

- (void)dPad:(RMDpad *)dpad didTouchSector:(RMDpadSector)sector
{
    [_commandSubscriber sendDpadSector:sector];
    [self dismissPopovers];
}

- (void)dPadTouchEnded:(RMDpad *)dpad
{
    [_commandSubscriber sendDpadSector:RMDpadSectorNone];
    [self dismissPopovers];
}

#pragma mark - Joystick Delegate

- (void)joystick:(RMJoystick *)joystick didMoveToAngle:(float)angle distance:(float)distance
{
    [_commandSubscriber sendJoystickDistance:distance angle:angle];
    [self dismissPopovers];
}

#pragma mark - Tilt Delgate

- (void)tiltWithVelocity:(CGFloat)velocity {
    [self dismissPopovers];
    
    if (!_hasTilted && ABS(velocity) > 0.35) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"romo-3 has tilted"];
        _hasTilted = YES;
        [_tiltHintTimer invalidate];
        self.tilt.showHint = NO;
    }
    if (ABS(velocity) < 0.005) {
        [_commandSubscriber sendTiltMotorPower:0.0];
    } else {
        float tiltMotorPower = (velocity*0.85) + (velocity > 0 ? 1 : -1) * 0.15;
        [_commandSubscriber sendTiltMotorPower:-tiltMotorPower];
    }
}

@end