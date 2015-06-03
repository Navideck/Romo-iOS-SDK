//
//  DriveTestViewController.h
//  RMCoreTest
//
//  Created by Mark Schnittman on 2/28/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import <UIKit/UIKit.h>

enum driveModes
{
    POWER = 0,
    HEADING_WITH_POWER,
    HEADING_WITH_SPEED,
    HEADING_WITH_RADIUS
};

@interface DriveTestViewController : UIViewController <UIAlertViewDelegate> {
    NSTimer *throttle;
}

@property (weak, nonatomic) IBOutlet UISlider *leftPower;
@property (weak, nonatomic) IBOutlet UISlider *rightPower;
@property (weak, nonatomic) IBOutlet UISlider *speed;
@property (weak, nonatomic) IBOutlet UISlider *radius;
@property (weak, nonatomic) IBOutlet UISegmentedControl *driveMode;
@property (weak, nonatomic) IBOutlet UILabel *speedLabel;
@property (weak, nonatomic) IBOutlet UILabel *radiusLabel;

- (IBAction)startDrive:(id)sender;
- (IBAction)stopDrive:(id)sender;
- (IBAction)speedChanged:(UISlider *)sender;
- (IBAction)radiusChanged:(UISlider *)sender;

@end

