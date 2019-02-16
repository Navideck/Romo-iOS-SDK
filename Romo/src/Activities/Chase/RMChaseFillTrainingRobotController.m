//
//  RMChaseDemoCameraRobotController.m
//  Romo
//
//  Created on 10/23/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "RMChaseFillTrainingRobotController.h"
#import "RMAppDelegate.h"
#import "UIFont+RMFont.h"
#import <Romo/RMDispatchTimer.h>
#import <Romo/RMVision.h>
#import <Romo/RMVisionDebugBroker.h>
#import "UIButton+RMButtons.h"
#import "UIView+Additions.h"
#import "UIImage+RoundedCorner.h"
#import <Romo/RMVisionObjectTrackingModule.h>
#import "RMVoice.h"

const int COUNTDOWN_TIMER_START = 11; // 10 second count down

@interface RMChaseFillTrainingRobotController () <RMVoiceDelegate>

@property (nonatomic, strong) UIView *cameraView;
@property (nonatomic, strong) UIImageView *debugView;
@property (nonatomic, strong) UIImageView *stillImageView;

@property (nonatomic, strong) UIImage *trainingDataImage;
@property (nonatomic, strong) RMVisionTrainingData *trainingData;
@property (nonatomic, strong) RMVisionObjectTrackingModule *trackingModule;

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, assign) float startingCovarianceScale;
@property (nonatomic, strong) UISlider *covarianceScalingSlider;

@property (nonatomic, strong) UIImageView *ringImageView;
@property (nonatomic, strong) UILabel *countdownLabel;

@property (nonatomic, strong) RMDispatchTimer *timer;

@property (nonatomic, strong) RMVoice *voicePrompt;

@end

@implementation RMChaseFillTrainingRobotController

- (instancetype)initWithCovarianceScaling:(float)scale completion:(RMChaseDemoCameraRobotControllerCompletion)completion
{
    self = [super init];
    if (self) {
        _completion = [completion copy];
        _startingCovarianceScale = scale;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.cameraView = [[UIView alloc] initWithFrame:self.view.bounds];
    
    [self.view addSubview:self.cameraView];
    [self.view addSubview:self.debugView];
    
    self.voicePrompt = [[RMVoice alloc] initWithFrame:self.view.bounds];
    self.voicePrompt.view = self.view;
    self.voicePrompt.delegate = self;
    
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.numberOfLines = 3;
    self.titleLabel.font = [UIFont fontWithSize:32];
    self.titleLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.3];
    self.titleLabel.layer.cornerRadius = 10.0;
    [self.titleLabel sizeToFit];
    [self.view addSubview:self.titleLabel];
    
    [self.covarianceScalingSlider setValue:self.startingCovarianceScale animated:NO];
    
    self.ringImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"ring"]];
    self.ringImageView.center = self.view.center;
    [self.view addSubview:self.ringImageView];
    
    self.countdownLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height - 100, 320, 60)];
    self.countdownLabel.textAlignment = NSTextAlignmentCenter;
    self.countdownLabel.textColor = [UIColor whiteColor];
    self.countdownLabel.font = [UIFont fontWithSize:45];
    self.countdownLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.3];
    self.countdownLabel.layer.cornerRadius = 10.0;
    [self.countdownLabel sizeToFit];
    self.countdownLabel.center = CGPointMake(self.view.center.x, self.view.frame.size.height - 50);
    
    [self startCaptureProcess];
}

- (void)controllerDidBecomeActive
{
    [super controllerDidBecomeActive];
    
    self.Romo.vision.delegate = self;
    
    // 0.25 - 4
    // covariance slider
    
    [RMVisionDebugBroker shared].core = self.Romo.vision;
    [[RMVisionDebugBroker shared] addOutputView:self.cameraView];
    
    [self.Romo.vision startCapture];
}

- (RMRomoFunctionalities)initiallyActiveFunctionalities
{
    return RMRomoFunctionalityVision;
}

- (NSSet *)initiallyActiveVisionModules
{
    // No modules should be active at this point?
    return nil;
}

- (void)showDebugImage:(UIImage *)debugImage
{
    [self.debugView setImage:debugImage];
}

- (void)startCaptureProcess
{
    // Clear out the tracking moduel if it already exists
    if (self.trackingModule) {
        [self.Romo.vision deactivateModule:self.trackingModule];
        self.trackingModule = nil;
    }
    
    [self.view addSubview:self.ringImageView];
    
    [self.view addSubview:self.titleLabel];
    self.titleLabel.text = NSLocalizedString(@"Chase-Fill-Training-Prompt-1", @"Fill the circle with a colorful object");
    self.titleLabel.frame = CGRectMake(25, 20, 280, 60);
    [self.titleLabel sizeToFit];
    
    self.countdownLabel.text = @"";
    [self.view addSubview:self.countdownLabel];
    
    static int count = 0;
    count = COUNTDOWN_TIMER_START;
    
    __weak RMChaseFillTrainingRobotController *weakSelf = self;
    
    self.timer = [[RMDispatchTimer alloc] initWithName:@"com.romotive.PhotoCountdown" frequency:1.0];
    self.timer.eventHandler = ^ {
        dispatch_sync(dispatch_get_main_queue(), ^{
            weakSelf.countdownLabel.text = [NSString stringWithFormat:@" %i ", --count];
            [weakSelf.countdownLabel sizeToFit];
            weakSelf.countdownLabel.center = CGPointMake(weakSelf.view.center.x, weakSelf.view.frame.size.height - 50);
            
            if (count == 0) {
                [weakSelf.timer stopRunning];
                [weakSelf capturePositiveSample];
            }
        });
    };
    
    [self.timer startRunning];
}

- (void)capturePositiveSample
{
    UIImage *image = [self.Romo.vision currentImage];
    
    CGFloat side = self.ringImageView.frame.size.height * (image.size.height / self.view.frame.size.height) - 20;
    CGPoint topLeft = CGPointMake(image.size.width / 2.0 - side / 2.0, image.size.height / 2.0 - side / 2.0);
    
    CGImageRef imageRef = CGImageCreateWithImageInRect([image CGImage], CGRectMake(topLeft.x, topLeft.y, side, side));
    UIImage *cropped = [[UIImage imageWithCGImage:imageRef] roundedCornerImage:side/2.0 borderSize:0];
    CGImageRelease(imageRef);
    
    self.trainingDataImage = cropped;
    
    
    [self.ringImageView removeFromSuperview];
    self.titleLabel.text = NSLocalizedString(@"Chase-Fill-Training-Prompt-2", @"Remove object completely from view");
    [self.titleLabel sizeToFit];
    self.titleLabel.center = self.view.center;

    static int count = 0;
    count = COUNTDOWN_TIMER_START;
    __weak RMChaseFillTrainingRobotController *weakSelf = self;
    
    self.timer = [[RMDispatchTimer alloc] initWithName:@"com.romotive.PhotoCountdown" frequency:1.0];
    self.timer.eventHandler = ^ {
        dispatch_sync(dispatch_get_main_queue(), ^{
            weakSelf.countdownLabel.text = [NSString stringWithFormat:@" %i ", --count];
            [weakSelf.countdownLabel sizeToFit];
            weakSelf.countdownLabel.center = CGPointMake(weakSelf.view.center.x, weakSelf.view.frame.size.height - 50);
            
            if (count == 0) {
                [weakSelf.timer stopRunning];
                [weakSelf captureNegativeSample];
            }
        });
    };
    
    [self.timer startRunning];
}

- (void)captureNegativeSample
{
    UIImage *negativeSample = [self.Romo.vision currentImage];
    
    self.trainingData = [[RMVisionTrainingData alloc] initWithPositiveImage:self.trainingDataImage
                                                  withNegativeExamplesImage:negativeSample];
    
    // Create tracking module for visualization
    self.trackingModule = [[RMVisionObjectTrackingModule alloc] initWithVision:self.Romo.vision];
    [self.trackingModule trainWithData:self.trainingData];
    self.trackingModule.delegate = self;
    self.trackingModule.generateVisualization = YES;
    
    [self.Romo.vision activateModule:self.trackingModule];
    
    [self.titleLabel removeFromSuperview];
    [self.countdownLabel removeFromSuperview];
    
    // Save data
//    NSData *imageData = UIImagePNGRepresentation(cropped);
    
    NSMutableData *data = [NSMutableData data];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
    [self.trainingData encodeWithCoder:archiver];
    [archiver finishEncoding];
    
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    path = [path stringByAppendingString:@"/user-trained2.data"];
    [data writeToFile:path atomically:YES];
    
    [self.voicePrompt ask:NSLocalizedString(@"Chase-Fill-Training-Prompt-Final", @"Wave the object in front of me.\nDo you see it highlighted?")
              withAnswers:@[NSLocalizedString(@"Chase-Fill-Training-Prompt-Again", @"Train again"), NSLocalizedString(@"Generic-Prompt-Yes", @"Yes")]];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesEnded:touches withEvent:event];
    
    // Allows the user to touch to speed up the count down
    if (self.timer) {
        [self.timer trigger];
    }
}


#pragma mark - RMVoiceDelegate

- (void)userDidSelectOptionAtIndex:(int)optionIndex forVoice:(RMVoice *)voice
{
    if (voice == self.voicePrompt) {
        [voice dismiss];
        
        if (optionIndex == 0) {
            
            // Clear the debug image
            self.debugView.image = nil;
            
            [self startCaptureProcess];
        } else {
            [self.Romo.vision deactivateModule:self.trackingModule];
            
            if (self.completion) {
                self.completion(self.trainingData);
            }
        }
    }
}

#pragma mark - Debug view

- (UIImageView *)debugView
{
    if (!_debugView) {
        _debugView = [[UIImageView alloc] initWithFrame:self.view.bounds];
        _debugView.backgroundColor = [UIColor clearColor];
        _debugView.alpha = 0.3;
        _debugView.contentMode = UIViewContentModeScaleAspectFill;
    }
    return _debugView;
}

@end
