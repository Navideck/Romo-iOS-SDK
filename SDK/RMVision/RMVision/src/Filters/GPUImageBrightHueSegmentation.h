//
//  GPUImageBrightHueSegmentation.h
//  RMVision
//
//  Created on 11/26/13.
//  Copyright (c) 2013 Romotive, Inc. All rights reserved.
//

#import "GPUImageFilter.h"

@interface GPUImageBrightHueSegmentation : GPUImageFilter

@property (nonatomic) float saturationThreshold;
@property (nonatomic) float brightnessThreshold;

@property (nonatomic) float hueLeftBound;
@property (nonatomic) float hueRightBound;

@end
