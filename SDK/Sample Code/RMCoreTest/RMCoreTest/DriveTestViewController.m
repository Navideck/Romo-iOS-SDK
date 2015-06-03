//
//  DriveTestViewController.m
//  RMCoreTest
//
//  Created by Mark Schnittman on 2/28/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
//  Testing the motors:
//  Each UISlider actively tells the protocol to update the correct motor

#import "DriveTestViewController.h"
#import "RMCoreTestAppDelegate.h"
//#import "RMIMUHandler.h"

@implementation DriveTestViewController
{
    //RMIMUHandler *_IMUHandle;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    self.title = @"Drive";
    
    // setup IMU access
    //_IMUHandle = [RMIMUHandler sharedInstance];
    //[_IMUHandle enableIMU];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

- (void)viewDidUnload
{
    // stop motors
    [self stopDrive:nil];
    
    [self setSpeedLabel:nil];
    [self setRadiusLabel:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

#pragma mark - IBAction methods

- (IBAction)stopDrive:(id)sender
{
    [ROBOT driveWithPower:0];
}

- (IBAction)speedChanged:(UISlider *)sender
{
    self.speedLabel.text = [NSString stringWithFormat:
                                              @"Speed (%1.2f)", sender.value ];
    [self.speedLabel sizeToFit];
}

- (IBAction)radiusChanged:(UISlider *)sender
{
    self.radiusLabel.text = [NSString stringWithFormat:
                                            @"Radius (%1.2f)", sender.value ];
    [self.radiusLabel sizeToFit];
}

- (IBAction)startDrive:(id)sender
{
    switch(self.driveMode.selectedSegmentIndex)
    {
        case POWER:
        {
            [ROBOT driveWithLeftMotorPower:self.leftPower.value
                           rightMotorPower:self.rightPower.value ];
            break;
        }
        case HEADING_WITH_POWER:
        {
            //[_IMUHandle.IMU updateConditionedData];
            //CMQuaternion heading = [_IMUHandle.IMU getAttitudeAsQuaternion];
            //
            //[ROBOT driveWithHeading: heading power:self.leftPower.value];
            
            float avgPower = (self.leftPower.value + self.rightPower.value )/2.;
            [ROBOT driveWithPower:avgPower];
            
            break;
        }
        case HEADING_WITH_SPEED:
        {
            //[_IMUHandle.IMU updateConditionedData];
            //CMQuaternion heading = [_IMUHandle.IMU getAttitudeAsQuaternion];
            //
            //[ROBOT driveWithHeading:heading speed:self.speed.value];
            if(self.speed.value > 0)
            {
                [ROBOT driveForwardWithSpeed:self.speed.value];
            }
            else
            {
                [ROBOT driveBackwardWithSpeed:fabsf(self.speed.value)];
            }
            
            break;
        }
        case HEADING_WITH_RADIUS:
        {
            [ROBOT driveWithRadius:self.radius.value speed:self.speed.value];
            break;
        }
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

@end
