//
//  RMEyeDetectionModule.m
//  RMVision
//
//  Created on 7/8/13.
//  Copyright (c) 2013 Romotive, Inc. All rights reserved.
//

#import "RMEyeDetectionModule.h"
#import "RMVision.h"

@implementation RMEyeDetectionModule

- (id)initWithVision:(RMVision *)core
{
    self = [super initModule:RMVisionModule_EyeDetection
                  withVision:core];
    
    if (self) {
        self.faceDetector = nil;
    }
    
    return self;
}

- (void)shutdown
{
    if (self.faceDetector) {
        self.faceDetector.eyeDetectionEnabled = NO;
        self.faceDetector = nil;
    }
}

- (void)processFrame:(const cv::Mat)mat
           videoRect:(CGRect)rect
    videoOrientation:(AVCaptureVideoOrientation)videoOrientation
{
    if (self.faceDetector && !self.faceDetector.eyeDetectionEnabled) {
        self.faceDetector.eyeDetectionEnabled = YES;
    }
    return;
}

-(void)setFaceDetector:(RMFaceDetectionModule *)faceDetector
{
    _faceDetector = faceDetector;
}

@end
