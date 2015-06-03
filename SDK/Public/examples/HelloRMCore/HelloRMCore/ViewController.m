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
//  ViewController.m
//  HelloRMCore
//
//  Created by Romotive on 5/21/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
//==============================================================================
#import "ViewController.h"

@interface ViewController ()

- (void)layoutForConnected;
- (void)layoutForUnconnected;

@end

@implementation ViewController

#pragma mark -- View Lifecycle --

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Assume the Robot is not connected
    [self layoutForUnconnected];

    // To receive messages when Robots connect & disconnect, set RMCore's delegate to self
    [RMCore setDelegate:self];
}


#pragma mark -- RMCoreDelegate Methods --

- (void)robotDidConnect:(RMCoreRobot *)robot
{
    // Currently the only kind of robot is Romo3, which supports all of these
    //  protocols, so this is just future-proofing
    if (robot.isDrivable && robot.isHeadTiltable && robot.isLEDEquipped) {
        
        self.robot = (RMCoreRobot<HeadTiltProtocol, DriveProtocol, LEDProtocol> *) robot;
        
        // Change the robot's LED to be solid at 80% power
        [self.robot.LEDs setSolidWithBrightness:0.8];
        
        [self layoutForConnected];
    }
}

- (void)robotDidDisconnect:(RMCoreRobot *)robot
{
    if (robot == self.robot) {
        self.robot = nil;
        
        [self layoutForUnconnected];
    }
}

#pragma mark -- IBAction Methods --

- (void)didTouchDriveInCircleButton:(UIButton *)sender
{
    // If the robot is driving, let's stop driving
    if (self.robot.isDriving) {
        // Change the robot's LED to be solid at 80% power
        [self.robot.LEDs setSolidWithBrightness:0.8];
        
        // Tell the robot to stop
        [self.robot stopDriving];
        
        [sender setTitle:@"Drive in circle" forState:UIControlStateNormal];
    } else {
        // Change the robot's LED to pulse
        [self.robot.LEDs pulseWithPeriod:1.0 direction:RMCoreLEDPulseDirectionUpAndDown];
        
        // Romo's top speed is around 0.75 m/s
        float speedInMetersPerSecond = 0.5;
        
        // Drive a circle about 0.25 meter in radius
        float radiusInMeters = 0.25;
        
        // Give the robot the drive command
        [self.robot driveWithRadius:radiusInMeters speed:speedInMetersPerSecond];
        
        [sender setTitle:@"Stop Driving" forState:UIControlStateNormal];
    }
}

- (void)didTouchTiltUpButton:(UIButton *)sender
{
    // If the robot is tilting, stop tilting
    if (self.robot.isTilting) {
        
        // Tell the robot to stop tilting
        [self.robot stopTilting];
        
        [sender setTitle:@"Tilt Up" forState:UIControlStateNormal];
        
    } else {
        
        [sender setTitle:@"Stop" forState:UIControlStateNormal];
        
        // Tilt down by ten degrees
        float tiltByAngleInDegrees = 10.0;
        
        [self.robot tiltByAngle:tiltByAngleInDegrees
                     completion:^(BOOL success) {
                         // Reset button title on the main queue
                         dispatch_async(dispatch_get_main_queue(), ^{
                             [sender setTitle:@"Tilt Up" forState:UIControlStateNormal];
                         });
                     }];
    }
}

- (void)didTouchTiltDownButton:(UIButton *)sender
{
    // If the robot is tilting, stop tilting
    if (self.robot.isTilting) {
        
        // Tell the robot to stop tilting
        [self.robot stopTilting];
        
        [sender setTitle:@"Tilt Down" forState:UIControlStateNormal];
        
    } else {
        
        [sender setTitle:@"Stop" forState:UIControlStateNormal];
        
        // Tilt up by ten degrees
        float tiltByAngleInDegrees = -10.0;
        
        [self.robot tiltByAngle:tiltByAngleInDegrees
                     completion:^(BOOL success) {
                         // Reset button title on the main queue
                         dispatch_async(dispatch_get_main_queue(), ^{
                             [sender setTitle:@"Tilt Down" forState:UIControlStateNormal];
                         });
                     }];
    }
}

#pragma mark -- Private Methods: Build the UI --

- (void)layoutForConnected
{
    // Lets make some buttons so we can tell the robot to do stuff
    if (!self.connectedView) {
        self.connectedView = [[UIView alloc] initWithFrame:self.view.bounds];
        self.connectedView.backgroundColor = [UIColor whiteColor];
        
        self.driveInCircleButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        self.driveInCircleButton.frame = CGRectMake(70, 50, 180, 60);
        [self.driveInCircleButton setTitle:@"Drive in circle" forState:UIControlStateNormal];
        [self.driveInCircleButton addTarget:self action:@selector(didTouchDriveInCircleButton:) forControlEvents:UIControlEventTouchUpInside];
        [self.connectedView addSubview:self.driveInCircleButton];
        
        self.tiltDownButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        self.tiltDownButton.frame = CGRectMake(70, 130, 80, 60);
        [self.tiltDownButton setTitle:@"Tilt Up" forState:UIControlStateNormal];
        [self.tiltDownButton addTarget:self action:@selector(didTouchTiltUpButton:) forControlEvents:UIControlEventTouchUpInside];
        [self.connectedView addSubview:self.tiltDownButton];
        
        self.tiltUpButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        self.tiltUpButton.frame = CGRectMake(170, 130, 80, 60);
        [self.tiltUpButton setTitle:@"Tilt Down" forState:UIControlStateNormal];
        [self.tiltUpButton addTarget:self action:@selector(didTouchTiltDownButton:) forControlEvents:UIControlEventTouchUpInside];
        [self.connectedView addSubview:self.tiltUpButton];
    }
    
    [self.unconnectedView removeFromSuperview];
    [self.view addSubview:self.connectedView];
}

- (void)layoutForUnconnected
{
    // If we aren't connected to a robotic base, just show a label
    if (!self.unconnectedView) {
        self.unconnectedView = [[UIView alloc] initWithFrame:self.view.bounds];
        self.unconnectedView.backgroundColor = [UIColor whiteColor];
        
        UILabel *notConnectedLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, self.view.center.y, self.view.frame.size.width, 40)];
        notConnectedLabel.textAlignment = NSTextAlignmentCenter;
        notConnectedLabel.text = @"Romo Not Connected";
        [self.unconnectedView addSubview:notConnectedLabel];
    }

    [self.connectedView removeFromSuperview];
    [self.view addSubview:self.unconnectedView];
}

@end
