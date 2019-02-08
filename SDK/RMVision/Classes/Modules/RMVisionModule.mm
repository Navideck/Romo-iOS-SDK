//
//  RMVisionModule.m
//  RMVision
//
//  Created on 4/9/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "RMVisionModule.h"
#import "UIDevice+VisionHardware.h"

@interface RMVisionModule ()

@property (nonatomic, readwrite) int width;
@property (nonatomic, readwrite) int height;

@property (nonatomic, readwrite) NSString *name;

@end

@implementation RMVisionModule

@synthesize vision = _vision;
@synthesize paused = _paused;

- (id)initWithVision:(RMVision *)core
{
    return [self initModule:nil withVision:core];
}

-(id)initModule:(NSString *)name
     withVision:(RMVision *)core;
{
    self = [super init];
    if (self) {
        _vision = core;
        _name = name;
        _isColor = YES;
        
        // Initialize state
        _frameNumber = 0;
        _frameProcessed = NO;
        _scaleFactor = 1.0;
        
        _isSlow = ![[UIDevice currentDevice] supportsAdvancedComputerVision];
    }
    return self;
}

-(void)shutdown
{
    _vision = nil;
}

-(void)setScaleFactor:(float)scaleFactor
{
    _scaleFactor = scaleFactor;
    _width = self.vision.width * _scaleFactor;
    _height = self.vision.height * _scaleFactor;
}

-(void) processFrame:(const cv::Mat)mat
           videoRect:(CGRect)rect
    videoOrientation:(AVCaptureVideoOrientation)videoOrientation
{
    // Increment frame number
    self.frameNumber = self.frameNumber + 1;
    
}

-(cv::Mat)resizeFrame:(const cv::Mat)mat
            videoRect:(CGRect)rect
{
    // Shrink video frame
    cv::Mat resizedMat;
    cv::resize(mat, resizedMat, cv::Size(), self.scaleFactor, self.scaleFactor, CV_INTER_LINEAR);
    rect.size.width *= self.scaleFactor;
    rect.size.height *= self.scaleFactor;
    
    return resizedMat;
}

@end
