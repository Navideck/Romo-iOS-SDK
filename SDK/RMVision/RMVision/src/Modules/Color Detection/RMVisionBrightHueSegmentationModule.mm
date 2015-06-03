//
//  RMVisionBrightHueSegmentationModule.m
//  RMVision
//
//  Created on 11/27/13.
//  Copyright (c) 2013 Romotive, Inc. All rights reserved.
//

#import "RMVisionBrightHueSegmentationModule.h"
#import <RMShared/RMMath.h>
#import "RMVision_Internal.h"
#import "GPUImageBrightHueSegmentation.h"
#import "GPUImage.h"

static const float triggerTimeoutDuration = 4.0; // seconds

@interface RMVisionBrightHueSegmentationModule ()

@property (nonatomic) GPUImageBrightHueSegmentation *hueSegmentation;
@property (nonatomic) GPUImageAverageColor *averageColor;

@property (nonatomic) double previousTriggerTime;

@end

@implementation RMVisionBrightHueSegmentationModule

// Remap the paused property to the GPUImageFilter's property named "enabled"
@synthesize paused = enabled;

// Synthesize the properties from RMVisionModuleProtocol
@synthesize vision = _vision;
@synthesize name = _name;
@synthesize frameNumber = _frameNumber;

#pragma mark - Initialization/teardown

//------------------------------------------------------------------------------
-(id)initWithVision:(RMVision *)core
{
    return [self initModule:NSStringFromClass([self class]) withVision:core];
}

//------------------------------------------------------------------------------
- (id)initModule:(NSString *)moduleName withVision:(RMVision *)core
{
    self = [super init];
    if (self) {
        _vision = core;
        _name = moduleName;
        
        // Arbitrary default value
        _hueFractionThreshold = 0.25;
        
        // Set processing size
        CGSize processingSize = CGSizeMake(288, 352);
        
        // Set up filters
        _hueSegmentation = [[GPUImageBrightHueSegmentation alloc] init];
        [_hueSegmentation forceProcessingAtSize:processingSize];
        [self addFilter:_hueSegmentation];
        
        _averageColor = [[GPUImageAverageColor alloc] init];
        [self addFilter:_averageColor];
        
        __weak RMVisionBrightHueSegmentationModule *weakSelf = self;
        _averageColor.colorAverageProcessingFinishedBlock = ^(CGFloat redComponent, CGFloat greenComponent, CGFloat blueComponent, CGFloat alphaComponent, CMTime frameTime) {
            // Rate-limit how quickly we can trigger
            double time = currentTime();
            if (alphaComponent >= weakSelf.hueFractionThreshold && time - weakSelf.previousTriggerTime > triggerTimeoutDuration) {
                weakSelf.previousTriggerTime = time;
                dispatch_async(dispatch_get_main_queue(), ^(void){
                    if ([weakSelf.delegate respondsToSelector:@selector(hueSegmentationModuleDidDetectHue:)]) {
                        [weakSelf.delegate hueSegmentationModuleDidDetectHue:weakSelf];
                    }
                });
            }
        };
        
        
        // Input filters
        // Multiple filters can act as input filters
        self.initialFilters = @[_hueSegmentation];
        
        // Pipeline
        [_hueSegmentation addTarget:_averageColor];
        
        // Output filter
        // There can only be one
        self.terminalFilter = _hueSegmentation;
    }
    return self;
}

//------------------------------------------------------------------------------
- (void)shutdown
{
    for (GPUImageOutput *filter in filters) {
        if ([filter respondsToSelector:@selector(removeAllTargets)]) {
            [filter removeAllTargets];
        }
    }
}

//------------------------------------------------------------------------------
- (void)processFrame:(const cv::Mat)mat
           videoRect:(CGRect)rect
    videoOrientation:(AVCaptureVideoOrientation)videoOrientation
{
    self.frameNumber++;
}

#pragma mark - Accessors

- (float)saturationThreshold
{
    return _hueSegmentation.saturationThreshold;
}

- (void)setSaturationThreshold:(float)saturationThreshold
{
    _hueSegmentation.saturationThreshold = saturationThreshold;
}


- (float)brightnessThreshold
{
    return _hueSegmentation.brightnessThreshold;
}

- (void)setBrightnessThreshold:(float)brightnessThreshold
{
    _hueSegmentation.brightnessThreshold = brightnessThreshold;
}

- (float)hueLeftBound
{
    return _hueSegmentation.hueLeftBound;
}

- (void)setHueLeftBound:(float)hueLeftBound
{
    _hueSegmentation.hueLeftBound = hueLeftBound;
}

- (float)hueRightBound
{
    return _hueSegmentation.hueRightBound;
}

- (void)setHueRightBound:(float)hueRightBound
{
    _hueSegmentation.hueRightBound = hueRightBound;
}

@end
