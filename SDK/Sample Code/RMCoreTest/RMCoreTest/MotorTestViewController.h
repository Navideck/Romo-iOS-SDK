//
//  MotorTestViewController.h
//  RMCoreTest
//
//  Created by Dan Kane on 6/26/12.
//  Copyright (c) 2012 DK Technologies. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MotorTestViewController : UIViewController <UIAlertViewDelegate> {
    NSTimer *throttle;
}

@property (weak, nonatomic) IBOutlet UISlider *bothDriveMotors;
@property (weak, nonatomic) IBOutlet UISlider *leftDriveMotor;
@property (weak, nonatomic) IBOutlet UISlider *rightDriveMotor;
@property (weak, nonatomic) IBOutlet UISlider *tiltMotor;
@property (weak, nonatomic) IBOutlet UISlider *tiltAngle;

- (IBAction)updateMotors:(id)sender;

@end

typedef enum
{ 
    MOTOR_LEFT=3,
    MOTOR_RIGHT=4,
    MOTOR_TILT=5,
    TILT_ANGLE=6,
} MOTORS;
