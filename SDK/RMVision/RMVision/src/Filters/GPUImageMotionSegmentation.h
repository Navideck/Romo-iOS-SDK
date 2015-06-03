//
//  GPUImageMotionSegmentation.h
//  RMVision
//
//  Created on 10/3/13.
//  Copyright (c) 2013 Romotive, Inc. All rights reserved.
//

#import "GPUImageFilterGroup.h"
#import "GPUImageLowPassFilter.h"

@interface GPUImageMotionSegmentation : GPUImageFilterGroup
{
    GPUImageLowPassFilter *lowPassFilter;
    GPUImageTwoInputFilter *frameComparisonFilter;
}

// This controls the low pass filter strength used to compare the current frame with previous ones to detect motion. This ranges from 0.0 to 1.0, with a default of 0.5.
@property(readwrite, nonatomic) CGFloat lowPassFilterStrength;

// For every frame, this will feed back the calculated centroid of the motion, as well as a relative intensity.
@property(nonatomic, copy) void(^motionDetectionBlock)(CGPoint motionCentroid, CGFloat motionIntensity, CMTime frameTime);

@end
