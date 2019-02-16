//
//  RMTelepresence2ClientViewController.m
//  Romo
//
//  Created on 11/7/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "RMTelepresenceClientViewController.h"
#import "RMTelepresence.h"
#import "RMOpenTokManager.h"
#import "RMDpad.h"
#import "RMDriveTiltSlider.h"
#import "UIView+Additions.h"
#import <Opentok/Opentok.h>
#import <Romo/UIDevice+UDID.h>
#import <Romo/UIApplication+Environment.h>
#import "RMContactManager.h"
#import "RMAlertView.h"
#import "UIFont+RMFont.h"
#import "UILabel+RomoStyles.h"
#import "UIAlertView+RMDismissAll.h"
#import "RMRomoteDriveExpressionsPopover.h"
#import "RMAnalytics.h"
#import "RMSoundEffect.h"

static CGFloat kCallTimeout = 45.0;

@interface RMTelepresenceClientViewController () <RMOpenTokManagerDelegate, RMDpadDelegate, RMRomoteDriveExpressionsPopoverDelegate>

@property (nonatomic, strong) NSString *uuid;
@property (nonatomic, strong) NSString *number;
@property (nonatomic, copy) RMTelepresence2ClientViewControllerCompletion completion;
@property (nonatomic, strong) NSError *error;
@property (nonatomic, assign) RMTelepresenceModeCommand currentMode;

// Views
@property (nonatomic, strong) RMDpad *dpad;
@property (nonatomic, strong) RMDriveTiltSlider *tiltSlider;
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) RMRomoteDriveExpressionsPopover *expressionPanel;
@property (nonatomic, strong) UIImageView *romoModeImageView;

// Sound

@property (nonatomic, strong) RMSoundEffect *ringEffect;

// OpenTok
@property (nonatomic, strong) RMOpenTokManager *otManager;

@end

@implementation RMTelepresenceClientViewController

- (instancetype)initWithNumber:(NSString *)number
                    completion:(RMTelepresence2ClientViewControllerCompletion)completion
{
    self = [super init];
    if (self) {
        _number = number;
        _completion = completion;
        _currentMode = RMTelepresenceModeCommandVideo;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.ringEffect = [[RMSoundEffect alloc] initWithName:@"Space-Trampoline"];
    self.ringEffect.gain = 0.8;
    [self.ringEffect play];
    
    self.view.backgroundColor = [UIColor blackColor];
    
    [self addStandardButtonWithImageNamed:@"menuBarDisconnect" position:CGPointMake(self.view.frame.size.width - 65, 20) action:@selector(handleEndCallPress:)];
    
    self.messageLabel = [UILabel labelWithFrame:CGRectMake(0, 0, self.view.width, 60)
                                   styleOptions:UILabelRomoStyleAlignmentCenter | UILabelRomoStyleShadowed |
                                                (iPad ? UILabelRomoStyleFontSizeLarger : UILabelRomoStyleFontSizeLarge)];
    self.messageLabel.center = self.view.boundsCenter;
    self.messageLabel.text = [NSString stringWithFormat:NSLocalizedString(@"TP-Client-Calling-Title", @"Calling %@"), self.number];
    [self.view addSubview:self.messageLabel];
    
    self.expressionPanel = [RMRomoteDriveExpressionsPopover expressionsPopover];
    self.expressionPanel.top = self.view.height;
    [self.view addSubview:self.expressionPanel];
}

- (UIButton *)addStandardButtonWithTitle:(NSString *)title position:(CGPoint)position action:(SEL)action
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    
    button.frame = CGRectMake(position.x, position.y, 45, 45);
    button.backgroundColor = [UIColor whiteColor];
    [button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [button setTitle:title forState:UIControlStateNormal];
    
    [button addTarget:self action:action forControlEvents:UIControlEventTouchDown];
    
    [self.view addSubview:button];
    
    return button;
}

- (UIButton *)addStandardButtonWithImageNamed:(NSString *)imageName position:(CGPoint)position action:(SEL)action
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    
    button.frame = CGRectMake(position.x, position.y, 45, 45);
    [button setImage:[UIImage imageNamed:imageName] forState:UIControlStateNormal];
    
    [button addTarget:self action:action forControlEvents:UIControlEventTouchDown];
    
    [self.view addSubview:button];
    
    return button;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    
    if (!self.otManager) {
        [self sendCallRequest];
    }
    
    [self.tiltSlider addObserver:self forKeyPath:@"value" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [RMSoundEffect stopBackgroundEffect];
    [self.ringEffect pause];
    
    [UIAlertView dismissAll];
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    
    [self.tiltSlider removeObserver:self forKeyPath:@"value"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object == self.tiltSlider && [keyPath isEqualToString:@"value"]) {
        NSInteger angle = 90;
        
        switch (self.tiltSlider.value) {
            case RMDriveTiltSliderValueUp:
                angle = 110;
                break;
                
            case RMDriveTiltSliderValueCenter:
                angle = 90;
                break;
                
            case RMDriveTiltSliderValueDown:
                angle = 70;
                break;
        }
        
//        [self.otManager.otSession signalWithType:@"tiltToAngle" data:@(angle) completionHandler:^(NSError *error) {}];
    }
}

- (void)sendCallRequest
{
    [[RMAnalytics sharedInstance] track:@"Telepresence Client: New Call" properties:@{@"number": self.number}];
    
    NSString *host = [UIApplication environmentVariableWithKey:@"ROMO_TELEPRESENCE_SERVER"];
    
    NSString *urlString = [NSString stringWithFormat:@"http://%@/hosts/%@/calls", host, self.number];
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    
    NSData *body = [NSJSONSerialization dataWithJSONObject:@{@"udid": [UIDevice currentDevice].UDID} options:0 error:nil];
    
    request.HTTPMethod = @"POST";
    request.HTTPBody = body;
    
    [request addValue:[NSString stringWithFormat:@"%d", body.length] forHTTPHeaderField:@"Content-Length"];
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        NSHTTPURLResponse *httpResponse = (id)response;
        
        if (connectionError == nil && httpResponse.statusCode < 300) {
            NSDictionary *payload = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            
            self.uuid = payload[@"uuid"];
            
            self.otManager = [[RMOpenTokManager alloc] initWithUUID:self.uuid sessionID:payload[@"otSessionID"] token:payload[@"otToken"]];
            self.otManager.delegate = self;
            
            [self.otManager connect];
            [self performSelector:@selector(callDidTimeout) withObject:nil afterDelay:kCallTimeout];
            
            [self.otManager addTarget:self action:@selector(didReceiveWhoamiSignal:) forSignal:@"whoami"];
            
            [[RMAnalytics sharedInstance] track:@"Telepresence Client: Call Sent" properties:@{@"uuid": self.uuid, @"number": self.number}];
            DDLogVerbose(@"[%@] Call request was successful. Starting OpenTok session now.", self.uuid);
            
        } else if (connectionError) {
            [[RMAnalytics sharedInstance] track:@"Telepresence Client: Call Failed" properties:@{@"number": self.number, @"type": @"Connection Error"}];
            
            NSError *error = [NSError errorWithDomain:kTelepresenceErrorDomain
                                                 code:RMTelepresenceCallErrorCodeConnectionFailed
                                             userInfo:@{@"rootError": connectionError}];
            
            self.completion(error);
            
        } else {
            [[RMAnalytics sharedInstance] track:@"Telepresence Client: Call Failed" properties:@{@"number": self.number, @"type": @"Unknown Error"}];
            
            NSError *error = [NSError errorWithDomain:kTelepresenceErrorDomain
                                                 code:RMTelepresenceCallErrorCodeFailed
                                             userInfo:nil];
            self.completion(error);
        }
    }];
}

#pragma mark - Ending the call

- (void)callDidTimeout
{
    [[[RMAlertView alloc] initWithTitle:NSLocalizedString(@"TP-Client-CallFailed-Alert-Title", @"Call failed") message:NSLocalizedString(@"TP-Client-CallFailed-Alert-Message", @"The owner of the remote Romo did not answer.") delegate:nil] show];
    [[RMAnalytics sharedInstance] track:@"Telepresence Client: Call Timeout" properties:@{@"number": self.number}];
    
    [self.otManager disconnect];
}

- (void)handleEndCallPress:(id)sender
{
    [[RMAnalytics sharedInstance] track:@"Telepresence Client: End Call Press" properties:@{@"uuid": self.uuid ? self.uuid : @"call not setup"}];
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(callDidTimeout) object:nil];
    [self.otManager disconnect];
}

#pragma mark - Showing and hiding the expression panel

- (void)showExpressionPanel
{
    [UIView animateWithDuration:0.2 animations:^{
        self.expressionPanel.top = self.view.height - self.expressionPanel.height;
        self.dpad.top = self.dpad.top - self.expressionPanel.height;
        self.tiltSlider.top = self.tiltSlider.top - self.expressionPanel.height;
    }];
}

- (void)hideExpressionPanel
{
    CGFloat offset = self.expressionPanel.top - self.view.height;
    
    [UIView animateWithDuration:0.2 animations:^{
        self.expressionPanel.top = self.expressionPanel.top - offset;
        self.dpad.top = self.dpad.top - offset;
        self.tiltSlider.top = self.tiltSlider.top - offset;
    }];
}

#pragma mark - OpenTok Signals

- (void)didReceiveWhoamiSignal:(NSDictionary *)data
{
    NSString *romoName = data[@"romoName"];
    
    [[[RMContactManager alloc] init] updateOrAddContactWithID:self.number userName:@"" romoName:romoName];
}

#pragma mark - Driving the remote robot

- (void)handleForwardPress:(id)sender
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(stopDriving) object:nil];
    [self performSelector:@selector(handleForwardPress:) withObject:sender afterDelay:1];
//    [self.otManager.otSession signalWithType:@"drive" data:@(RMTelepresenceDriveCommandForward) completionHandler:^(NSError *error) {}];
}

- (void)handleBackwardPress:(id)sender
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(stopDriving) object:nil];
    [self performSelector:@selector(handleBackwardPress:) withObject:sender afterDelay:1];
//    [self.otManager.otSession signalWithType:@"drive" data:@(RMTelepresenceDriveCommandBackward) completionHandler:^(NSError *error) {}];
}

- (void)handleLeftPress:(id)sender
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(stopDriving) object:nil];
    [self performSelector:@selector(handleLeftPress:) withObject:sender afterDelay:1];
//    [self.otManager.otSession signalWithType:@"drive" data:@(RMTelepresenceDriveCommandLeft) completionHandler:^(NSError *error) {}];
}

- (void)handleRightPress:(id)sender
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(stopDriving) object:nil];
    [self performSelector:@selector(handleRightPress:) withObject:sender afterDelay:1];
//    [self.otManager.otSession signalWithType:@"drive" data:@(RMTelepresenceDriveCommandRight) completionHandler:^(NSError *error) {}];
}

- (void)handleDrivePressEnd:(id)sender
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(handleForwardPress:) object:sender];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(handleBackwardPress:) object:sender];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(handleLeftPress:) object:sender];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(handleRightPress:) object:sender];
    
    [self stopDriving];
    
    // Wait 200ms and then re-send the stop driving command. This is to help prevent run away robots.
    [self performSelector:@selector(stopDriving) withObject:nil afterDelay:0.2];
}

- (void)stopDriving
{
//    [self.otManager.otSession signalWithType:@"drive" data:@(RMTelepresenceDriveCommandStop) completionHandler:^(NSError *error) {}];
}

- (void)handleTiltPress:(id)sender
{
//    [self.otManager.otSession signalWithType:@"tiltToAngle" data:@([sender tag]) completionHandler:^(NSError *error) {}];
}

#pragma mark - Switching between Romo and video on the remote robot

- (void)handleModePress:(id)sender
{
    switch (self.currentMode) {
        case RMTelepresenceModeCommandVideo:
            self.currentMode = RMTelepresenceModeCommandRomo;
            self.otManager.otPublisher.publishVideo = NO;
            [sender setImage:[UIImage imageNamed:@"menuBarContacts"] forState:UIControlStateNormal];
            [self showExpressionPanel];
            
            self.romoModeImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"telepresence-romo-mode"]];
            [self.otManager.otPublisher.view addSubview:self.romoModeImageView];
            
            break;
            
        case RMTelepresenceModeCommandRomo:
            self.currentMode = RMTelepresenceModeCommandVideo;
            self.otManager.otPublisher.publishVideo = YES;
            [sender setImage:[UIImage imageNamed:@"emotion-button"] forState:UIControlStateNormal];
            [self hideExpressionPanel];
            
            [self.romoModeImageView removeFromSuperview];
            self.romoModeImageView = nil;
            
            break;
    }
    
//    [self.otManager.otSession signalWithType:@"mode" data:@(self.currentMode) completionHandler:^(NSError *error) {}];
}

#pragma mark - Muting mic and speaker

- (void)handleMuteMicPress:(id)sender
{
    self.otManager.otPublisher.publishAudio = !self.otManager.otPublisher.publishAudio;
    
    if (self.otManager.otPublisher.publishAudio) {
        [sender setImage:[UIImage imageNamed:@"menuBarMuteOn"] forState:UIControlStateNormal];
    } else {
        [sender setImage:[UIImage imageNamed:@"menuBarMute"] forState:UIControlStateNormal];
    }
}

- (void)handleMuteSpeakerPress:(id)sender
{
    self.otManager.otSubscriber.subscribeToAudio = !self.otManager.otSubscriber.subscribeToAudio;
    
    if (self.otManager.otSubscriber.subscribeToAudio) {
        [sender setImage:[UIImage imageNamed:@"menuBarMuteThem"] forState:UIControlStateNormal];
    } else {
        [sender setImage:[UIImage imageNamed:@"menuBarMuteThemOn"] forState:UIControlStateNormal];
    }
}

#pragma mark - RMOpenTokManager

- (void)otSessionManager:(RMOpenTokManager *)manager didEncounterUnhandlableError:(NSError *)error
{
    [[RMAnalytics sharedInstance] track:@"Telepresence Client: OTSession Error" properties:@{@"uuid": self.uuid}];
    
    if (self.completion) {
        self.completion(error);
        self.completion = nil;
    }
}

- (void)otSessionManagerDidDisconnect:(RMOpenTokManager *)manager
{
    [[RMAnalytics sharedInstance] track:@"Telepresence Client: OTSession Disconnected" properties:@{@"uuid": self.uuid}];
    
    if (self.completion) {
        self.completion(nil);
        self.completion = nil;
    }
}

- (void)otSessionManagerDidConnect:(RMOpenTokManager *)manager
{
    [[RMAnalytics sharedInstance] track:@"Telepresence Client: OTSession Connected" properties:@{@"uuid": self.uuid}];
    
    [self.view addSubview:manager.otPublisher.view];
    [self.view sendSubviewToBack:manager.otPublisher.view];

    manager.otPublisher.view.frame = self.view.bounds;
    
    // Remove the toolbar
//    [manager.otPublisher.view.toolbarView removeFromSuperview];
}

- (void)otSessionManager:(RMOpenTokManager *)manager subscriberDidConnect:(OTSubscriber *)subscriber
{
    [[RMAnalytics sharedInstance] track:@"Telepresence Client: Host Connected" properties:@{@"uuid": self.uuid}];
    
    [self.ringEffect pause];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(callDidTimeout) object:nil];
    
    // Move the publisher view to top left corner and add the subscriber's view
    manager.otPublisher.view.frame = CGRectMake(10, 10, 75, 120);
    manager.otPublisher.view.layer.borderColor = [UIColor blackColor].CGColor;
    manager.otPublisher.view.layer.borderWidth = 2.0;
    manager.otPublisher.view.layer.cornerRadius = 3.0;

    subscriber.view.frame = self.view.bounds;
//    [subscriber.view.toolbarView removeFromSuperview];

    [self.view addSubview:subscriber.view];
    [self.view sendSubviewToBack:subscriber.view];
    
    // Add the button to toggle video/romo
    UIButton *modeButton = [self addStandardButtonWithImageNamed:@"emotion-button" position:CGPointMake(70, 30) action:@selector(handleModePress:)];
    modeButton.center = CGPointMake(65, 110);
    
    // Add the mute buttons
    [self addStandardButtonWithImageNamed:@"menuBarMuteOn" position:CGPointMake(self.view.frame.size.width - 65, 85) action:@selector(handleMuteMicPress:)];
    [self addStandardButtonWithImageNamed:@"menuBarMuteThemOn" position:CGPointMake(self.view.frame.size.width - 65, 150) action:@selector(handleMuteSpeakerPress:)];
    
    // Hide the message label
    self.messageLabel.hidden = YES;
}

- (void)otSessionManager:(RMOpenTokManager *)manager didDecodeFirstVideoFrameFromSubscriber:(OTSubscriber *)subscriber
{
    [[RMAnalytics sharedInstance] track:@"Telepresence Client: Received First Frame" properties:@{@"uuid": self.uuid}];
    
    // Create and add the dpad
    self.dpad = [[RMDpad alloc] initWithFrame:CGRectMake(0, 0, 160, 160) imageName:@"R3UI-Dpad" centerSize:CGSizeMake(50, 50)];
    self.dpad.delegate = self;
    self.dpad.bottom = self.view.height - 20;
    self.dpad.right = self.view.width - (iPad ? 160 : 20);
    [self.view addSubview:self.dpad];
    
    // Create and add the tilt slider
    self.tiltSlider = [RMDriveTiltSlider tiltSlider];
    self.tiltSlider.center = self.dpad.center;
    self.tiltSlider.left = iPad ? 160 : 15;
    [self.tiltSlider addObserver:self forKeyPath:@"value" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:nil];
    [self.view addSubview:self.tiltSlider];
}

#pragma mark - RMDPadDelegate

- (void)dPad:(RMDpad *)dpad didTouchSector:(RMDpadSector)sector
{
    switch (sector) {
        case RMDpadSectorUp:
            [self handleForwardPress:dpad];
            break;
            
        case RMDpadSectorDown:
            [self handleBackwardPress:dpad];
            break;
            
        case RMDpadSectorLeft:
            [self handleLeftPress:dpad];
            break;
            
        case RMDpadSectorRight:
            [self handleRightPress:dpad];
            break;
            
        default:
            [self handleDrivePressEnd:dpad];
            break;
    }
}

- (void)dPadTouchEnded:(RMDpad *)dpad
{
    [self handleDrivePressEnd:dpad];
}

#pragma mark - RMRomoteDriveExpressionsPopoverDelegate

- (void)didTouchExpressionsPopoverFace:(RMRomoteDriveExpressionButton *)button
{
//    [self.otManager.otSession signalWithType:@"expression" data:@(button.expression) completionHandler:^(NSError *error) {}];
    self.expressionPanel.enabled = NO;
    
    double delayInSeconds = 5.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        self.expressionPanel.enabled = YES;
    });
}

@end
