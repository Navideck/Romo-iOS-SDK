//
//  MotorTestViewController.m
//  RMCoreTest
//
//  Created by Dan Kane on 6/26/12.
//  Copyright (c) 2012 DK Technologies. All rights reserved.
//
//  Testing the motors:
//  Each UISlider actively tells the protocol to update the correct motor

#import "MotorTestViewController.h"
#import "RMCoreTestAppDelegate.h"


@implementation MotorTestViewController

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
    
    self.title = @"Motors";
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if (ROBOT.isConnected) {
        self.tiltAngle.value = ROBOT.headAngle;
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
//    [ROBOT stopAllMotion];
    [super viewWillDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - IBAction methods

- (IBAction)updateMotors:(id)sender {
    switch ([sender tag]) {
        case 0:
            //All Stop
            [self.bothDriveMotors setValue:0];
            [self.leftDriveMotor setValue:0];
            [self.rightDriveMotor setValue:0];
            [self.tiltMotor setValue:0];
            [ROBOT stopAllMotion];
            break;
        case 2:
            //Both drive motors
            [self.leftDriveMotor setValue:((UISlider *)sender).value];
            [self.rightDriveMotor setValue:((UISlider *)sender).value];
        case MOTOR_LEFT:
        case MOTOR_RIGHT:
            [ROBOT driveWithLeftMotorPower:self.leftDriveMotor.value
                           rightMotorPower:self.rightDriveMotor.value];
            break;
        case MOTOR_TILT:
            //Tilt Motor
            [ROBOT tiltWithMotorPower:((UISlider *)sender).value];
            break;
        case TILT_ANGLE:
        {
            [ROBOT tiltToAngle:((UISlider *)sender).value completion:^(BOOL success) {
                self.tiltAngle.value = ROBOT.headAngle;
            }];
        }
            break;
        default:
            break;
    }
}

@end
