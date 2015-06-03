//
//  RMDriveTiltSlider.h
//  Romo
//
//  Created on 11/19/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum {
    RMDriveTiltSliderValueUp,
    RMDriveTiltSliderValueCenter,
    RMDriveTiltSliderValueDown
} RMDriveTiltSliderValue;

@interface RMDriveTiltSlider : UIView

@property (nonatomic, assign, readonly) RMDriveTiltSliderValue value;

+ (id)tiltSlider;

@end
