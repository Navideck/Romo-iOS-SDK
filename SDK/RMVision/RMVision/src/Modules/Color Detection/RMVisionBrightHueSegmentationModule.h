//
//  RMVisionBrightHueSegmentationModule.h
//  RMVision
//
//  Created on 11/27/13.
//  Copyright (c) 2013 Romotive, Inc. All rights reserved.
//

#import "GPUImageFilterGroup.h"
#import "RMVisionModuleProtocol.h"

@protocol RMVisionBrightHueSegmentationModuleDelegate;

@interface RMVisionBrightHueSegmentationModule : GPUImageFilterGroup <RMVisionModuleProtocol, GPUImageInput>

@property (nonatomic, weak) id<RMVisionBrightHueSegmentationModuleDelegate> delegate;

// Sets the threshold to trigger the hueSegmentationModuleDidDetectHue method
// This is the fraction of pixels in the image that pass the bright hue segmentation filter.
// Set in the range from [0.0 to 1.0].
@property (nonatomic) float hueFractionThreshold;

// Saturation threshold for pixels to pass the filter
// Set in the range from [0.0 to 1.0].
@property (nonatomic) float saturationThreshold;

// Brightness threshold for pixels to pass the filter
// Set in the range from [0.0 to 1.0].
@property (nonatomic) float brightnessThreshold;


// Allows you to set the range of hue values that pass the filter
// Set in the range from [0.0 to 1.0].

// For example:
// hueLeftBound = 0.95 and hueRightBound = 0.05 would allow red
// or
// hueLeftBound = 0.2 and hueRightBound = 0.3 would allow green
@property (nonatomic) float hueLeftBound;
@property (nonatomic) float hueRightBound;

@end


@protocol RMVisionBrightHueSegmentationModuleDelegate <NSObject>

- (void)hueSegmentationModuleDidDetectHue:(RMVisionBrightHueSegmentationModule *)module;

@end
