//
//  LEDTestViewController.h
//  RMCoreTest
//
//  Created by Dan Kane on 6/26/12.
//  Copyright (c) 2012 Romotive. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface LEDTestViewController : UIViewController {//<RomoDelegate> {
    uint8_t cnt;
    uint8_t step;
}

@property (weak, nonatomic) IBOutlet UISegmentedControl *ledMode;

@property (weak, nonatomic) IBOutlet UISlider *brightnessSlider;
@property (weak, nonatomic) IBOutlet UILabel *brightnessLabel;
@property (weak, nonatomic) IBOutlet UITextField *brightnessText;

@property (weak, nonatomic) IBOutlet UISlider *dutyCycleSlider;
@property (weak, nonatomic) IBOutlet UILabel *dutyCycleLabel;
@property (weak, nonatomic) IBOutlet UITextField *dutyCycleText;

@property (weak, nonatomic) IBOutlet UISlider *periodSlider;
@property (weak, nonatomic) IBOutlet UILabel *periodLabel;
@property (weak, nonatomic) IBOutlet UITextField *periodText;

@property (weak, nonatomic) IBOutlet UISegmentedControl *pulseDirection;

- (IBAction)updateLEDs:(id) sender;
//- (IBAction)executeBlinkPattern:(id)sender;
//- (void)sendLEDData:(NSTimer *)theTimer;

@end
