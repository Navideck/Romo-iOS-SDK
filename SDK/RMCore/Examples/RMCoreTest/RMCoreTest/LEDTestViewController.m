//
//  LEDTestViewController.m
//  RMCoreTest
//
//  Created by Dan Kane on 6/26/12.
//  Copyright (c) 2012 Romotive. All rights reserved.


#import "LEDTestViewController.h"
#import "RMCoreTestAppDelegate.h"

@interface LEDTestViewController ()

- (void)configureView;

@end

@implementation LEDTestViewController

#pragma mark - Managing the detail item

- (void)configureView
{
    self.ledMode.selectedSegmentIndex = ROBOT.LEDs.mode;

    _brightnessSlider.value = ROBOT.LEDs.brightness;
    _dutyCycleSlider.value = ROBOT.LEDs.dutyCycle;
    _periodSlider.value = ROBOT.LEDs.period;
    [_brightnessText setText:[NSString stringWithFormat:@"%.2f",ROBOT.LEDs.brightness]];
    [_dutyCycleText setText:[NSString stringWithFormat:@"%.2f",ROBOT.LEDs.dutyCycle]];
    [_periodText setText:[NSString stringWithFormat:@"%.2f",ROBOT.LEDs.period]];
    
    [_brightnessSlider setHidden:(_ledMode.selectedSegmentIndex != RMCoreLEDModeSolid)];
    [_brightnessLabel  setHidden:(_ledMode.selectedSegmentIndex != RMCoreLEDModeSolid)];
    [_brightnessText   setHidden:(_ledMode.selectedSegmentIndex != RMCoreLEDModeSolid)];
    [_dutyCycleSlider  setHidden:(_ledMode.selectedSegmentIndex != RMCoreLEDModeBlink)];
    [_dutyCycleLabel   setHidden:(_ledMode.selectedSegmentIndex != RMCoreLEDModeBlink)];
    [_dutyCycleText    setHidden:(_ledMode.selectedSegmentIndex != RMCoreLEDModeBlink)];
    [_periodSlider setHidden:(_ledMode.selectedSegmentIndex != RMCoreLEDModeBlink)
                          && (_ledMode.selectedSegmentIndex != RMCoreLEDModePulse)];
    [_periodLabel  setHidden:(_ledMode.selectedSegmentIndex != RMCoreLEDModeBlink)
                          && (_ledMode.selectedSegmentIndex != RMCoreLEDModePulse)];
    [_periodText   setHidden:(_ledMode.selectedSegmentIndex != RMCoreLEDModeBlink)
                          && (_ledMode.selectedSegmentIndex != RMCoreLEDModePulse)];
    [_pulseDirection setHidden:(_ledMode.selectedSegmentIndex != RMCoreLEDModePulse)];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    [self configureView];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    //[_romo setDelegate:self];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.title = @"LED Tests";
    }
    return self;
}

#pragma mark - IBAction methods

- (IBAction)updateLEDs:(id) sender
{
    if (sender == self.ledMode) {
        [_brightnessSlider setHidden:(_ledMode.selectedSegmentIndex != RMCoreLEDModeSolid)];
        [_brightnessLabel  setHidden:(_ledMode.selectedSegmentIndex != RMCoreLEDModeSolid)];
        [_brightnessText   setHidden:(_ledMode.selectedSegmentIndex != RMCoreLEDModeSolid)];
        [_dutyCycleSlider  setHidden:(_ledMode.selectedSegmentIndex != RMCoreLEDModeBlink)];
        [_dutyCycleLabel   setHidden:(_ledMode.selectedSegmentIndex != RMCoreLEDModeBlink)];
        [_dutyCycleText    setHidden:(_ledMode.selectedSegmentIndex != RMCoreLEDModeBlink)];
        [_periodSlider setHidden:(_ledMode.selectedSegmentIndex != RMCoreLEDModeBlink)
                              && (_ledMode.selectedSegmentIndex != RMCoreLEDModePulse)];
        [_periodLabel  setHidden:(_ledMode.selectedSegmentIndex != RMCoreLEDModeBlink)
                              && (_ledMode.selectedSegmentIndex != RMCoreLEDModePulse)];
        [_periodText   setHidden:(_ledMode.selectedSegmentIndex != RMCoreLEDModeBlink)
                              && (_ledMode.selectedSegmentIndex != RMCoreLEDModePulse)];
        [_pulseDirection setHidden:(_ledMode.selectedSegmentIndex != RMCoreLEDModePulse)];
        if (self.ledMode.selectedSegmentIndex == RMCoreLEDModeBlink)
            self.periodSlider.maximumValue = 2.0;
        else if (self.ledMode.selectedSegmentIndex == RMCoreLEDModePulse)
            self.periodSlider.maximumValue = 9.5;
        if (self.periodSlider.value > self.periodSlider.maximumValue)
            self.periodSlider.value = self.periodSlider.maximumValue;
        [_periodText setText:[NSString stringWithFormat:@"%.2f",self.periodSlider.value]];
        
    }
    else if (sender == self.brightnessSlider) {
        [_brightnessText setText:[NSString stringWithFormat:@"%.2f",self.brightnessSlider.value]];
    }
    else if (sender == self.dutyCycleSlider) {
        [_dutyCycleText setText:[NSString stringWithFormat:@"%.2f",self.dutyCycleSlider.value]];
    }
    else if (sender == self.periodSlider) {
        [_periodText setText:[NSString stringWithFormat:@"%.2f",self.periodSlider.value]];
    }
    
    switch (self.ledMode.selectedSegmentIndex) {
        case RMCoreLEDModeOff:
            [ROBOT.LEDs turnOff];
            break;
        case RMCoreLEDModeSolid:
            [ROBOT.LEDs setSolidWithBrightness:self.brightnessSlider.value];
            break;
        case RMCoreLEDModeBlink:
            [ROBOT.LEDs blinkWithPeriod:self.periodSlider.value
                              dutyCycle:self.dutyCycleSlider.value
                             brightness:1.0];
            break;
        case RMCoreLEDModePulse:
            [ROBOT.LEDs pulseWithPeriod:self.periodSlider.value
                              direction:self.pulseDirection.selectedSegmentIndex - 1];
            break;
        default:
            break;
    }
}
@end
