//
//  RMChaseRobotController.m
//  Romo
//

#import "RMChaseRobotController.h"
#import "RMChaseTrainingRobotController.h"

#import "RMAppDelegate.h"
#import "RMLineView.h"
#import "UIButton+RMButtons.h"

#import <Romo/RMVisionDebugBroker.h>
#import <Romo/RMImageUtils.h>

#import <Romo/RMMath.h>
#import <Romo/UIDevice+Hardware.h>

typedef enum {
    RMLineFollowState_Streaming,
    RMLineFollowState_Overdrawing,
    RMLineFollowState_Processing
} RMLineFollowState;

@interface RMChaseRobotController ()

@property (nonatomic, strong) RMCoreRobot<HeadTiltProtocol, DriveProtocol, LEDProtocol, RobotMotionProtocol, DifferentialDriveProtocol> *robot;
@property (nonatomic, strong) RMVision *vision;

@property (nonatomic, strong) UIView *visionView;
@property (nonatomic, strong) UIImageView *visionOverlayView;

@property (nonatomic, strong) UIImage *sampleImage;
@property (nonatomic, strong) UIImage *annotationsImage;
@property (nonatomic, strong) UIImageView *sampleImageView;

@property (nonatomic, strong) UIButton *followingButton;
@property (nonatomic, strong) UIButton *liveViewButton;

@property (nonatomic, strong) UIButton *pictureButton;
@property (nonatomic, strong) UIButton *goButton;
@property (nonatomic, strong) UIButton *resetButton;

@property (nonatomic, strong) UISlider *KpSlider;
@property (nonatomic, strong) UISlider *KiSlider;
@property (nonatomic, strong) UISlider *KdSlider;

@property (nonatomic, strong) CAGradientLayer *gradientLayer;

@property (nonatomic, strong) RMLineView *drawer;

@property (nonatomic) BOOL beganTouch;
@property (nonatomic) BOOL movedTouch;
@property (nonatomic) BOOL hintedDuringMove;

@property (nonatomic) BOOL trainingComplete;

@property (nonatomic) RMLineFollowState state;

// PID controller
@property (nonatomic) RMCoreControllerPID *controller;
@property (nonatomic) float Kp;
@property (nonatomic) float Ki;
@property (nonatomic) float Kd;
@property (nonatomic) float setPointPID;

@property (nonatomic) RMCoreControllerPIDTuningUI *controllerTuningUI;

// Robot control state variables
@property (nonatomic) float angleToLineCentroid;
@property (nonatomic) float constantPower;
@property (nonatomic) float trackPointY;

@property (nonatomic, strong) UIButton *trainButton;
@property (nonatomic, strong) UIButton *trainDrawButton;

// Searching
@property (nonatomic, getter=isSearching) BOOL searching;
@property (nonatomic) float timeSearching;
@property (nonatomic, strong) RMLine *lastObject;

@end

@implementation RMChaseRobotController

- (id)init
{
    self = [super init];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.trainButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.trainButton.frame = CGRectMake(0, 0, 90, 90);
    [self.trainButton setTitle:@"TRAIN" forState:UIControlStateNormal];
    self.trainButton.backgroundColor = [UIColor whiteColor];
    [self.trainButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    self.trainButton.layer.cornerRadius = 45;
    self.trainButton.center = CGPointMake(self.view.frame.size.width / 2.0, self.view.frame.size.height - 80);
    [self.trainButton addTarget:self action:@selector(handleTrainPress:) forControlEvents:UIControlEventTouchUpInside];

    self.trainDrawButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    self.trainDrawButton.frame = CGRectMake(CGRectGetMidX(self.view.frame) - 50, CGRectGetMaxY(self.view.frame) - 75, 100, 50);
    self.trainDrawButton.frame = CGRectMake(125, 10, 150, 50);
    [self.trainDrawButton setTitle:@"Train by Drawing" forState:UIControlStateNormal];
    [self.trainDrawButton addTarget:self action:@selector(transitionToLiveFeed:) forControlEvents:UIControlEventTouchUpInside];
    
    self.vision = [[RMVision alloc] initWithCamera:RMCamera_Front];
    
    self.vision.delegate = self;
    [self.vision startCapture];
    
    self.controllerTuningUI = [RMCoreControllerPIDTuningUI createTuningUIForController:self.controller andShow:NO];
}

- (void)controllerDidBecomeActive
{
    [super controllerDidBecomeActive];
    
    // Ensure we have a fresh robot object
    if ([self.Romo.robot isKindOfClass:[RMCoreRobotRomo3 class]]) {
        self.robot = (RMCoreRobotRomo3 *)self.Romo.robot;
    }
    
    self.vision = [[RMVision alloc] initWithCamera:RMCamera_Front];
    
    self.vision.delegate = self;
    [self.vision startCapture];
    
    self.controllerTuningUI = [RMCoreControllerPIDTuningUI createTuningUIForController:self.controller andShow:NO];
    
    [self transitionToFollowing];
}

-(void)transitionToLiveFeed
{
    [self transitionToFollowing];
    [self.view addSubview:self.trainButton];
    [self.view addSubview:self.trainDrawButton];
    
    [self.Romo.character setEmotion:RMCharacterEmotionCurious];
}

#pragma mark - Handling UI events

- (void)handleTrainPress:(id)sender
{
    [self.vision stopCapture];
    
    self.vision = [[RMVision alloc] initWithCamera:RMCamera_Front];
    self.vision.delegate = self;
    
    [self.vision startCapture];
    
    RMChaseTrainingRobotController *controller = [[RMChaseTrainingRobotController alloc] initWithVision:self.vision completion:^(NSError *error, UIColor *color, RMVisionTrainingData *trainingData) {
        [(RMAppDelegate *)[UIApplication sharedApplication].delegate popRobotController];
        
        self.vision.delegate = self;
        self.trainButton.backgroundColor = color;
        self.trainButton.layer.borderWidth = 2;
        self.trainButton.layer.borderColor = [UIColor whiteColor].CGColor;
        [self.trainButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];

        [UIView animateWithDuration:0.15
                         animations:^{
                             self.trainButton.transform = CGAffineTransformMakeScale(1.25, 1.25);
                         } completion:^(BOOL finished) {
                             [UIView animateWithDuration:0.15
                                              animations:^{
                                                  self.trainButton.transform = CGAffineTransformMakeScale(0.92, 0.92);
                                              } completion:^(BOOL finished) {
                                                  [UIView animateWithDuration:0.15
                                                                   animations:^{
                                                                       self.trainButton.transform = CGAffineTransformIdentity;
                                                                   }];
                                              }];
                         }];
        
//        [self.vision trainModule:RMVisionModule_LineFollow withData:trainingData];
        
        [self.gradientLayer removeFromSuperlayer];
        
        self.gradientLayer = [CAGradientLayer layer];
        self.gradientLayer.frame = self.view.bounds;
        self.gradientLayer.colors = @[ (id)[color colorWithAlphaComponent:0.0].CGColor, (id)color.CGColor ];
        self.gradientLayer.locations = @[ @0.0, @1.0 ];
        self.gradientLayer.startPoint = CGPointMake(0.0, 0.45);
        self.gradientLayer.endPoint = CGPointMake(0.0, 1.0);

//        UIView *colorView = [[UIView alloc] initWithFrame:self.view.bounds];
//        colorView.alpha = 0.0;
//        colorView.backgroundColor = [UIColor clearColor];
//        [colorView.layer addSublayer:gradientLayer];
        
        CABasicAnimation *fadeIn = [CABasicAnimation animationWithKeyPath:@"opacity"];
        fadeIn.fromValue = @(0);
        fadeIn.toValue = @(1);
        fadeIn.duration = 0.2;
        [self.gradientLayer addAnimation:fadeIn forKey:@"fadeIn"];
        
        [self.view.layer insertSublayer:self.gradientLayer atIndex:1];
    }];
    
    [(RMAppDelegate *)[UIApplication sharedApplication].delegate pushRobotController:controller];
}

#pragma mark -

-(void)transitionToLiveFeed:(id)sender
{
    // if we're coming from training, load that data
    if (_drawer.superview) {
        [self sendTrainingData];
    }
    [self clearAllForTransition];
    
    [RMVisionDebugBroker shared].core = self.vision;
    [[RMVisionDebugBroker shared] addOutputView:self.visionView];
    
//    [self.view addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(transitionToTraining)]];
    
    [self.view addSubview:self.visionView];
    [self.view addSubview:self.visionOverlayView];
    [self.view addSubview:self.followingButton];
    
    self.controller.enabled = YES;
    
    [self.controllerTuningUI present];
    
}

-(void)transitionToTraining
{
    [self clearAllForTransition];
    
    self.visionView.frame = self.view.bounds;
    
    // Save the current image from RMVision as the sampleImage
    UIImage *currentImage = [RMImageUtils imageWithImage:[self.vision currentImage] scaledToSize:self.view.bounds.size];
    self.sampleImage = currentImage;
    
    // Create UIImageView from the UIImage
    self.sampleImageView = [[UIImageView alloc] initWithImage:self.sampleImage];
    self.sampleImageView.frame = self.view.bounds;
    self.sampleImageView.contentMode = UIViewContentModeScaleToFill;
    [self.view addSubview:self.sampleImageView];
    
    self.drawer.frame = self.view.bounds;
    self.drawer.image = nil;
    [self.view addSubview:self.drawer];
    
    [self.view addSubview:self.liveViewButton];
    
    [self.robot driveWithLeftMotorPower:0.0 rightMotorPower:0.0];
    
}

-(void)transitionToFollowing
{
    [self clearAllForTransition];
    
//    [self.view addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(transitionToLiveFeed)]];

    self.controller.enabled = YES;
}

-(void)clearAllForTransition
{
    self.controller.enabled = NO;
    [self.controllerTuningUI dismiss];
    
    
    for (UIGestureRecognizer *gestureRecognizer in self.view.gestureRecognizers) {
        [self.view removeGestureRecognizer:gestureRecognizer];
    }
    
    // Remove live view views
    
    if (_followingButton) {
        [self.followingButton removeFromSuperview];
        self.followingButton = nil;
    }
    
    //
    if (_visionView) {
        [[RMVisionDebugBroker shared] removeOutputView:self.visionView];
        [self.visionView removeFromSuperview];
        [self.visionOverlayView removeFromSuperview];
    }
    
    if (_drawer) {
        [self.drawer removeFromSuperview];
        self.drawer = nil;
    }
    
    if (_sampleImageView) {
        [self.sampleImageView removeFromSuperview];
        self.sampleImageView = nil;
    }
    
    // Remove training views
    
    if (_liveViewButton) {
        [self.liveViewButton removeFromSuperview];
        self.liveViewButton = nil;
    }
    
    self.annotationsImage = nil;
    self.sampleImage = nil;
}

#pragma mark - RMVision delegates

//------------------------------------------------------------------------------
- (void)moduleFinishedTraining:(NSString *)module
{
//    if ([module isEqualToString:RMVisionModule_LineFollow]) {
//        [self.vision activateModuleWithName:RMVisionModule_LineFollow];
//        
//        self.trainingComplete = YES;
//    }
}

//------------------------------------------------------------------------------
- (void)showDebugImage:(UIImage *)debugImage
{
    // colorMasking is: Rmin, Rmax, Gmin, Gmax, Bmin, Bmax
    // If a pixel falls within this range, it is set to clear and allows the background through
    const float colorMasking[6] = {0, 2, 0, 2, 0, 2};
    CGImageRef imageRef = CGImageCreateWithMaskingColors(debugImage.CGImage, colorMasking);
    
    UIImage *image = [UIImage imageWithCGImage:imageRef];
    
    [self.visionOverlayView setImage:image];
    
    CGImageRelease(imageRef);
}

//------------------------------------------------------------------------------
- (void)didDetectLine:(RMLine *)line
{
    self.searching = NO;
    self.lastObject = line;
//    NSLog(@"Centroid: (%f, %f)", self.lastObject.centroid.x, self.lastObject.centroid.y);
    
    float x = line.centroid.x - 0.5;
    
    self.trackPointY = 0.5 - line.centroid.y;
    
    self.angleToLineCentroid = -x * M_PI;
    
    [self.controller triggerController];
    
    [self.Romo.character lookAtPoint:RMPoint3DMake(2*(line.centroid.x - 0.5),
                                                   2*(line.centroid.y - 0.5),
                                                   1.0)
                                    animated:YES];
}

//------------------------------------------------------------------------------
- (void)didLoseLine:(RMLine *)line
{
    self.Romo.character.emotion = RMCharacterEmotionCurious;
    
    self.searching = YES;
}

-(void)sendTrainingData
{
//    UIColor *negativeLabelColor = RMLINE_NEGATIVE_COLOR;
//    UIColor *positiveLabelColor = RMLINE_POSITIVE_COLOR;
//    NSArray *labelColors = @[negativeLabelColor, positiveLabelColor];
//    
//    self.annotationsImage = self.drawer.image;
//    
//    if (self.sampleImage && self.annotationsImage) {
//        [self.vision trainModule:RMVisionModule_LineFollow
//                        withData:@[self.sampleImage, self.annotationsImage, labelColors]];
//    }
}

#pragma mark - Robot Initialization / Teardown
- (void)robotDidConnect:(RMCoreRobot *)robot
{
    // Ensure we have a fresh robot object
    if ([self.Romo.robot isKindOfClass:[RMCoreRobotRomo3 class]]) {
        self.robot = (RMCoreRobotRomo3 *)self.Romo.robot;
        [self.Romo.character setExpression:RMCharacterExpressionNone
                               withEmotion:RMCharacterEmotionCurious];
    }
}

- (void)robotDidDisconnect:(RMCoreRobot *)robot
{
    if (robot == self.robot) {
        self.robot = nil;
        [self.Romo.character setExpression:RMCharacterExpressionNone
                               withEmotion:RMCharacterEmotionSad];
    }
}

#pragma mark - Touch handlers
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    self.beganTouch = YES;
    self.movedTouch = NO;
    
    if (_drawer.superview) {
        [self.drawer touchesBegan:touches withEvent:event];
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    self.movedTouch = YES;
    if (_drawer.superview) {
        [self.drawer touchesMoved:touches withEvent:event];
        if (!self.hintedDuringMove) {
            self.hintedDuringMove = YES;
        }
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (_drawer.superview) {
        self.hintedDuringMove = NO;
        if (!self.movedTouch) {
            
            self.drawer.userInteractionEnabled = NO;
            if (self.pictureButton.isHidden) {
                if (self.drawer) {
                    self.drawer.userInteractionEnabled = NO;
                }
            } else {
                if (self.drawer) {
                    self.drawer.userInteractionEnabled = YES;
                }
            }
            
        } else {
            self.drawer.drawingPositives = !self.drawer.drawingPositives;
        }
    }
    self.beganTouch = NO;
    self.movedTouch = NO;
    self.hintedDuringMove = NO;
}

#pragma mark - Custom Setters / Getters

- (RMLineView *)drawer
{
    if (!_drawer)
        {
        // Drawer (canvas view)
        _drawer = [[RMLineView alloc] initWithFrame:self.visionView.frame];
        _drawer.drawingPositives = YES;
        }
    
    return _drawer;
}

- (UIView *)visionView
{
    if (!_visionView)
        {
        _visionView = [[UIView alloc] initWithFrame:self.view.bounds];
        _visionView.contentMode = UIViewContentModeScaleAspectFit;
        }
    
    return _visionView;
}

- (UIImageView *)visionOverlayView
{
    if (!_visionOverlayView) {
        _visionOverlayView = [[UIImageView alloc] initWithFrame:self.visionView.bounds];
        _visionOverlayView.backgroundColor = [UIColor clearColor];
        _visionOverlayView.alpha = 0.8;
    }
    return _visionOverlayView;
}

- (UIButton *)followingButton
{
    if (!_followingButton) {
        _followingButton = [UIButton backButtonWithImage:[UIImage imageNamed:@"backButtonImageCreature.png"]];
        [_followingButton addTarget:self action:@selector(transitionToFollowing) forControlEvents:UIControlEventTouchUpInside];
    }
    return _followingButton;
}

- (UIButton *)liveViewButton
{
    if (!_liveViewButton) {
        _liveViewButton = [UIButton backButtonWithImage:[UIImage imageNamed:@"backButtonChevron.png"]];
        [_liveViewButton addTarget:self action:@selector(transitionToLiveFeed) forControlEvents:UIControlEventTouchUpInside];
    }
    return _liveViewButton;
}

- (RMCoreControllerPID *)controller
{
    if (!_controller) {
        // PID Controller
        //        _Kp = 1.0;
        //        _Ki = 0.5;
        //        _Kd = 0.02;
        _Kp = 0.8;
        _Ki = 0.0;
        _Kd = 0.01;
        
        self.setPointPID = 0.0;
        
        float driveDirection;
        if (self.vision.camera == RMCamera_Front)
            driveDirection = -1.0;
        else
            driveDirection = 1.0;
        
        if ([UIDevice currentDevice].isFastDevice)
            {
            self.constantPower = 0.7;
            }
        else
            self.constantPower = 0.3;
        
        __weak RMChaseRobotController *weakSelf = self;
        _controller = [[RMCoreControllerPID alloc] initWithProportional:self.Kp
                                                               integral:self.Ki
                                                             derivative:self.Kd
                                                               setpoint:self.setPointPID
                                                            inputSource:^float{
                                                                return weakSelf.angleToLineCentroid;
                                                            }
                                                             outputSink:^(float PIDControllerOutput, RMControllerPIDState *contollerState) {
                                                                 
                                                                 float tiltByAngle = self.trackPointY * 60; // max is 0.5 * 60 deg so 30 deg max.
                                                                 [weakSelf.robot tiltByAngle:tiltByAngle completion:nil];
                                                                 
                                                                 weakSelf.constantPower = 1.0 - fabs(self.trackPointY) / 0.3;
//                                                                 NSLog(@"weakSelf.constantPower: %f self.trackPointY %f", weakSelf.constantPower, self.trackPointY);
//                                                                 DDLogVerbose(@"power: %f", weakSelf.constantPower);
                                                                 if (ABS(weakSelf.constantPower) < 0.28) {
                                                                     self.Romo.character.emotion = RMCharacterEmotionExcited;
                                                                 } else {
                                                                     self.Romo.character.emotion = RMCharacterEmotionHappy;
                                                                 }
                                                                 
                                                                 weakSelf.Kp = weakSelf.controller.P;
                                                                 weakSelf.Ki = weakSelf.controller.I;
                                                                 weakSelf.Kd = weakSelf.controller.D;
                                                                 
                                                                 float turnPower = PIDControllerOutput;
                                                                 float leftDrivePower = -driveDirection*(weakSelf.constantPower + turnPower);
                                                                 float rightDrivePower = -driveDirection*(weakSelf.constantPower - turnPower);
                                                                 
//                                                                 NSLog(@"leftDrivePower: %f rightDrivePower: %f", leftDrivePower, rightDrivePower);
                                                                 [weakSelf.robot driveWithLeftMotorPower:leftDrivePower rightMotorPower:rightDrivePower];
                                                                 
                                                                 
                                                                 
                                                                 
                                                                 
                                                             }];
    }
    
    return _controller;
}

- (void)setSearching:(BOOL)searching
{
    if (_searching != searching) {
        _searching = searching;
        
        if (!_searching) {
            [self.robot stopAllMotion];
        } else {
            [self searchForObject:self.lastObject];
        }
    }
}

- (void)searchForObject:(RMLine *)object
{
    float theta = atan2((0.5 - object.centroid.y), (object.centroid.x - 0.5));
    NSLog(@"Theta: %f", theta);
    
    if (object.centroid.y > 0.75 || object.centroid.y < 0.25) {
        if (theta > 0) {
            [self.Romo.character say:@"AndrewChambersIsKing"];
            [self.Romo.character lookAtPoint:RMPoint3DMake(0, -0.8, 0.75) animated:YES];
            [self.robot tiltToAngle:self.robot.maximumHeadTiltAngle
                         completion:^(BOOL success) {
                             if (self.searching) {
                                 [self.robot turnByAngle:180
                                              withRadius:RM_DRIVE_RADIUS_TURN_IN_PLACE
                                         finishingAction:RMCoreTurnFinishingActionStopDriving
                                              completion:nil];
                                 [self.Romo.character lookAtPoint:RMPoint3DMake(0, 0.2, 0.75) animated:YES];
                                 [self.robot tiltToAngle:90 completion:nil];
                             }
                         }];
            NSLog(@"Up");
        } else {
            NSLog(@"Down");
        }
    }
    
    else if (object.centroid.x > 0.7 || object.centroid.x < 0.3) {
        if (self.robot.headAngle > 95) {
            [self.robot tiltToAngle:90 completion:nil];
        }
        if (fabs(theta) < M_PI_2) {
            NSLog(@"Left");
            [self.Romo.character lookAtPoint:RMPoint3DMake(-0.8, 0, 0.75) animated:YES];
            [self.robot driveWithLeftMotorPower:-0.75
                                rightMotorPower:0.65];
        } else {
            NSLog(@"Right");
            [self.Romo.character lookAtPoint:RMPoint3DMake(0.8, 0, 0.75) animated:YES];
            [self.robot driveWithLeftMotorPower:0.65
                                rightMotorPower:-0.75];
        }
        double delayInSeconds = 6.0;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            if (self.searching) {
                [self.robot stopAllMotion];
            }
        });
    }
}

- (void)setKp:(float)Kp
{
    _Kp = Kp;
    if (self.controller)
        self.controller.P = _Kp;
    
}

- (void)setKi:(float)Ki
{
    _Ki = Ki;
    if (self.controller)
        self.controller.I = _Ki;
    
}

- (void)setKd:(float)Kd
{
    _Kd = Kd;
    if (self.controller)
        self.controller.D = _Kd;
    
}

@end
