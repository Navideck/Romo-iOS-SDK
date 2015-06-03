//==============================================================================
//                             _
//                            | | (_)
//   _ __ ___  _ __ ___   ___ | |_ ___   _____
//  | '__/ _ \| '_ ` _ \ / _ \| __| \ \ / / _ \
//  | | | (_) | | | | | | (_) | |_| |\ V /  __/
//  |_|  \___/|_| |_| |_|\___/ \__|_| \_/ \___|
//
//==============================================================================
//
//  ViewController.h
//  HelloRMCore
//
//  Created by Romotive on 5/21/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
//==============================================================================
#import <UIKit/UIKit.h>
#import <RMCore/RMCore.h>

@interface ViewController : UIViewController <RMCoreDelegate>

@property (nonatomic, strong) RMCoreRobot<HeadTiltProtocol, DriveProtocol, LEDProtocol> *robot;

// UI
@property (nonatomic, strong) UIView *connectedView;
@property (nonatomic, strong) UILabel *batteryLabel;
@property (nonatomic, strong) UIButton *driveInCircleButton;
@property (nonatomic, strong) UIButton *tiltUpButton;
@property (nonatomic, strong) UIButton *tiltDownButton;

@property (nonatomic, strong) UIView *unconnectedView;

- (void)didTouchDriveInCircleButton:(UIButton *)sender;
- (void)didTouchTiltDownButton:(UIButton *)sender;
- (void)didTouchTiltUpButton:(UIButton *)sender;

@end
