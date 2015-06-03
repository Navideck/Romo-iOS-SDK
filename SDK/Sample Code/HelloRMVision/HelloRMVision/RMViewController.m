//
//  RMViewController.m
//  HelloRMVision
//
//  Created by Adam Setapen on 6/16/13.
//  Copyright (c) 2013 Romotive, Inc. All rights reserved.
//

#import "RMViewController.h"
#import <RMVision/RMVisionDebugBroker.h>

//#import <RMVision/RMFakeVision.h>

#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)

#define horizMargin 20
#define rowHeight   40
#define totalWidth  [UIScreen mainScreen].bounds.size.width

@interface RMViewController ()

@property (nonatomic, strong) UIView *visionView;
@property (nonatomic, strong) UIView *textDebugView;

@property (nonatomic, strong) UILabel *fpsLabel;
@property (nonatomic, strong) UILabel *label1;
@property (nonatomic, strong) UILabel *label2;
@property (nonatomic, strong) UILabel *label3;

@property (nonatomic, strong) UISwitch *visionSwitch;
@property (nonatomic, strong) UISwitch *faceSwitch;
@property (nonatomic, strong) UISwitch *eyesSwitch;
@property (nonatomic, strong) UISwitch *motionSwitch;
@property (nonatomic, strong) UISwitch *videoSwitch;
@property (nonatomic, strong) UIButton *pictureButton;

@end

@implementation RMViewController

//------------------------------------------------------------------------------
- (void)viewDidLoad
{
    [super viewDidLoad];
    [UIApplication sharedApplication].statusBarHidden = YES;
    
    // Set up vision
#ifdef FAKE_VISION
    NSString *testVidPath = [[NSBundle mainBundle] pathForResource:@"face" ofType:@"mov"];
    NSURL *testVideo = [NSURL fileURLWithPath:testVidPath];
    self.vision = [[RMFakeVision alloc] initWithFileURL:testVideo inRealtime:NO];
#else
    self.vision = [[RMVision alloc] initWithCamera:RMCamera_Front
                                        andQuality:RMCameraQuality_High];
#endif
    
    self.vision.delegate = self;
    [self.vision startCapture];
    
    [self initDebugView];
}

#pragma mark - Vision Debugging
//------------------------------------------------------------------------------
- (void)initDebugView
{
    self.view.backgroundColor = [UIColor colorWithRed:0.90196
                                                green:0.90196 
                                                 blue:0.90196
                                                alpha:1.0];
    [self initLabels];
    [self addDebugLabels];
    
    // Add switches and buttons
    [self.view addSubview:self.visionSwitch];
    [self.view addSubview:self.faceSwitch];
    [self.view addSubview:self.eyesSwitch];
    [self.view addSubview:self.motionSwitch];
    [self.view addSubview:self.videoSwitch];
    
    [self.view addSubview:self.pictureButton];
    
    [RMVisionDebugBroker shared].core = self.vision;
    [[RMVisionDebugBroker shared] addOutputView:self.visionView];
    [RMVisionDebugBroker shared].showFPS = YES;
    
    [self.view addSubview:self.visionView];
}

//------------------------------------------------------------------------------
- (void)initLabels
{
    // Add labels
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, totalWidth, rowHeight-10)];
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.text = @"HelloRMVision";
    titleLabel.backgroundColor = [UIColor clearColor];
    [self.view addSubview:titleLabel];
    
    UILabel *visionLabel = [[UILabel alloc] initWithFrame:CGRectMake(horizMargin, rowHeight-(rowHeight/2), totalWidth * .65, rowHeight)];
    visionLabel.text = @"Vision Core";
    visionLabel.backgroundColor = [UIColor clearColor];
    
    UILabel *faceLabel = [[UILabel alloc] initWithFrame:CGRectMake(horizMargin, rowHeight*2-(rowHeight/2), totalWidth * .65, rowHeight)];
    faceLabel.text = @"Face Detection";
    faceLabel.backgroundColor = [UIColor clearColor];
    
    UILabel *eyesLabel = [[UILabel alloc] initWithFrame:CGRectMake(horizMargin, rowHeight*3-(rowHeight/2), totalWidth * .65, rowHeight)];
    eyesLabel.text = @"Eye Detection";
    eyesLabel.backgroundColor = [UIColor clearColor];
    
    UILabel *motionLabel = [[UILabel alloc] initWithFrame:CGRectMake(horizMargin, rowHeight*4-(rowHeight/2), totalWidth * .65, rowHeight)];
    motionLabel.text = @"Motion Detection";
    motionLabel.backgroundColor = [UIColor clearColor];
    
    UILabel *videoLabel = [[UILabel alloc] initWithFrame:CGRectMake(horizMargin, rowHeight*5-(rowHeight/2), totalWidth * .65, rowHeight)];
    videoLabel.text = @"Take Video";
    videoLabel.backgroundColor = [UIColor clearColor];
    
    [self.view addSubview:visionLabel];
    [self.view addSubview:faceLabel];
    [self.view addSubview:eyesLabel];
    [self.view addSubview:motionLabel];
    [self.view addSubview:videoLabel];
}

//------------------------------------------------------------------------------
- (void)addDebugLabels
{
    CGSize screenSize = [[UIScreen mainScreen] bounds].size;
    
//    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(didLongPress:)];
//    [_visionView addGestureRecognizer:longPress];
    
    // Set up the text debugging view
    _textDebugView = [[UIView alloc] initWithFrame:CGRectMake(5, screenSize.height - 110, screenSize.width - 148, 105)];
    _textDebugView.backgroundColor = [UIColor whiteColor];
    _textDebugView.alpha = 0.8;
    _textDebugView.layer.borderColor = [UIColor grayColor].CGColor;
    _textDebugView.layer.borderWidth = 2.0f;
    _textDebugView.layer.cornerRadius = 15.0f;
    
    // Label 1 (general debug)
    _label1 = [[UILabel alloc] initWithFrame:CGRectMake(10, 5, 165, 31)];
    _label1.font = [UIFont systemFontOfSize:16.0];
    _label1.backgroundColor = [UIColor clearColor];
    [_label1 setText:@"Attn: --"];
    [_textDebugView addSubview:_label1];
    
    // Label 2 (general debug)
    _label2 = [[UILabel alloc] initWithFrame:CGRectMake(10, 36, 165, 32)];
    _label2.font = [UIFont systemFontOfSize:16.0];
    _label2.backgroundColor = [UIColor clearColor];
    [_label2 setText:@" Loc: --"];
    [_textDebugView addSubview:_label2];
    
    // Label 3 (general debug)
    _label3 = [[UILabel alloc] initWithFrame:CGRectMake(10, 68, 165, 32)];
    _label3.font = [UIFont systemFontOfSize:16.0];
    _label3.backgroundColor = [UIColor clearColor];
    [_label3 setText:@"Dist: --"];
    [_textDebugView addSubview:_label3];
    
    [self.view addSubview:_textDebugView];
}

#pragma mark - UI Callbacks
//------------------------------------------------------------------------------
- (void)toggleVision:(id)sender
{
    if (sender == self.visionSwitch) {
        if ([sender isOn]) {
            self.vision = [[RMVision alloc] init];
            self.vision.delegate = self;
            
            [self.vision startCapture];
            
            [self.faceSwitch setEnabled:YES];
            [self.eyesSwitch setEnabled:YES];
            [self.motionSwitch setEnabled:YES];
            [self.videoSwitch setEnabled:YES];
            [self.pictureButton setEnabled:YES];
            
            [RMVisionDebugBroker shared].core = self.vision;
            [[RMVisionDebugBroker shared] addOutputView:self.visionView];
            [RMVisionDebugBroker shared].showFPS = YES;
            
            [self.view addSubview:self.visionView];
            
        } else {
            [RMVisionDebugBroker shared].core = nil;
            [[RMVisionDebugBroker shared] removeOutputView:self.visionView];
            [RMVisionDebugBroker shared].showFPS = NO;
            
            [self.visionView removeFromSuperview];
            self.visionView = nil;
            
            [self.vision stopCapture];
            
            self.vision.delegate = nil;
            self.vision = nil;
            
            [self.faceSwitch setOn:NO];
            [self.faceSwitch setEnabled:NO];
            
            [self.eyesSwitch setOn:NO];
            [self.eyesSwitch setEnabled:NO];
            
            [self.motionSwitch setOn:NO];
            [self.motionSwitch setEnabled:NO];
            
            [self.videoSwitch setOn:NO];
            [self.videoSwitch setEnabled:NO];
            
            [self.pictureButton setEnabled:NO];
        }
    }
}

//------------------------------------------------------------------------------
- (void)toggleModule:(id)sender
{
    NSString *moduleIdentifier;
    if (sender == self.faceSwitch) {
        moduleIdentifier = RMVisionModule_FaceDetection;
    } else if (sender == self.eyesSwitch) {
        moduleIdentifier = RMVisionModule_EyeDetection;
    } else if (sender == self.videoSwitch) {
        moduleIdentifier = RMVisionModule_TakeVideo;
    } else {
        moduleIdentifier = nil;
        return;
    }
    if ([sender isOn]) {
        [self.vision activateModuleWithName:moduleIdentifier];
    } else {
        [self.vision deactivateModuleWithName:moduleIdentifier];
    }
}

// Callback for Picture button
//------------------------------------------------------------------------------
- (void)pictureButtonPressed:(id)sender
{
    [self.vision activateModuleWithName:RMVisionModule_TakePicture];
}

#pragma mark - Vision delegates
// Faces
//------------------------------------------------------------------------------
- (void)didDetectFace:(RMFace *)face
{
    [[RMVisionDebugBroker shared] loseObject:@"Motion"];
    
    [[RMVisionDebugBroker shared] objectAt:face.boundingBox
                              withRotation:face.rotation
                                  withName:@"Face"];
    
    [[RMVisionDebugBroker shared] setAttention:face.location];
}

//------------------------------------------------------------------------------
- (void)didLoseFace
{
//    [[RMVisionDebugBroker shared] setDebugLabel:@"Attn: --" atIndex:1];
    [[RMVisionDebugBroker shared] loseAttention];
    [[RMVisionDebugBroker shared] loseObject:@"Face"];
}

// Motion
//------------------------------------------------------------------------------
- (void)didDetectMotion:(RMMotion *)motion
{
//    [[RMVisionDebugBroker shared] objectAt:motion.boundingBox
//                              withRotation:0
//                                  withName:@"Motion"];
//    
//    [[RMVisionDebugBroker shared] objectAt:motion.centroid
//                              withDistance:motion.area
//                                  withName:@"Motion"];
//    
//    [[RMVisionDebugBroker shared] setAttention:motion.centroid];
}

//------------------------------------------------------------------------------
- (void)didLoseMotion
{
//    [[RMVisionDebugBroker shared] setDebugLabel:@"Attn: --" atIndex:1];
//    [[RMVisionDebugBroker shared] loseAttention];
//    [[RMVisionDebugBroker shared] loseObject:@"Motion"];
}

#pragma mark - UI Initializers
//------------------------------------------------------------------------------
- (UIView *)visionView
{
    if (!_visionView) {
        CGRect screenSize = [[UIScreen mainScreen] bounds];
        _visionView = [[UIView alloc] initWithFrame:CGRectMake(screenSize.size.width - 138, screenSize.size.height - 168, 133, 163)];
        _visionView.backgroundColor = [UIColor blackColor];
        _visionView.layer.borderColor = [UIColor grayColor].CGColor;
        _visionView.layer.borderWidth = 2.0f;
        _visionView.contentMode = UIViewContentModeCenter;
        _visionView.clipsToBounds = YES;
        _visionView.layer.cornerRadius = 15.0f;
    }
    return _visionView;
}

//------------------------------------------------------------------------------
- (UISwitch *)visionSwitch
{
    if (!_visionSwitch) {
        _visionSwitch = [[UISwitch alloc] initWithFrame:CGRectMake((totalWidth * .6)+(horizMargin*2),
                                                                   rowHeight-(rowHeight/2)+(rowHeight/4),
                                                                   (totalWidth * .35) - (horizMargin*3),
                                                                   rowHeight)];
        [_visionSwitch addTarget:self action:@selector(toggleVision:) forControlEvents:UIControlEventValueChanged];
        [_visionSwitch setOn:YES];
    }
    return _visionSwitch;
}

//------------------------------------------------------------------------------
- (UISwitch *)faceSwitch
{
    if (!_faceSwitch) {
        _faceSwitch = [[UISwitch alloc] initWithFrame:CGRectMake((totalWidth * .6)+(horizMargin*2) , rowHeight*2-(rowHeight/2)+(rowHeight/4), (totalWidth * .35) - (horizMargin*3), rowHeight)];
        [_faceSwitch addTarget:self action:@selector(toggleModule:) forControlEvents:UIControlEventValueChanged];
        
    }
    return _faceSwitch;
}

//------------------------------------------------------------------------------
- (UISwitch *)eyesSwitch
{
    if (!_eyesSwitch) {
        _eyesSwitch = [[UISwitch alloc] initWithFrame:CGRectMake((totalWidth * .6)+(horizMargin*2), rowHeight*3-(rowHeight/2)+(rowHeight/4), (totalWidth * .35) - (horizMargin*3), rowHeight)];
        [_eyesSwitch addTarget:self action:@selector(toggleModule:) forControlEvents:UIControlEventValueChanged];
    }
    return _eyesSwitch;
}

//------------------------------------------------------------------------------
- (UISwitch *)videoSwitch
{
    if (!_videoSwitch) {
        _videoSwitch = [[UISwitch alloc] initWithFrame:CGRectMake((totalWidth * .6)+(horizMargin*2), rowHeight*5-(rowHeight/2)+(rowHeight/4), (totalWidth * .35) - (horizMargin*3), rowHeight)];
        [_videoSwitch addTarget:self action:@selector(toggleModule:) forControlEvents:UIControlEventValueChanged];
        
    }
    return _videoSwitch;
}

//------------------------------------------------------------------------------
- (UIButton *)pictureButton
{
    if (!_pictureButton) {
        _pictureButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        _pictureButton.frame = CGRectMake(horizMargin, rowHeight*6-(rowHeight/2)+5, totalWidth - (horizMargin*2), rowHeight);
        _pictureButton.contentMode = UIViewContentModeScaleAspectFill;
        _pictureButton.userInteractionEnabled = YES;
        [_pictureButton setTitle:@"Take Picture" forState:UIControlStateNormal];
        [_pictureButton addTarget:self action:@selector(pictureButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _pictureButton;
}

@end
