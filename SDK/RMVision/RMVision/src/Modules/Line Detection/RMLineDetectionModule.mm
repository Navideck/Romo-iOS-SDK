////////////////////////////////////////////////////////////////////////////////
//                             _
//                            | | (_)
//   _ __ ___  _ __ ___   ___ | |_ ___   _____
//  | '__/ _ \| '_ ` _ \ / _ \| __| \ \ / / _ \
//  | | | (_) | | | | | | (_) | |_| |\ V /  __/
//  |_|  \___/|_| |_| |_|\___/ \__|_| \_/ \___|
//
////////////////////////////////////////////////////////////////////////////////
//
//  RMLineDetectionModule.mm
//  RMVision
//
//  Created on 11/11/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
////////////////////////////////////////////////////////////////////////////////
#import "RMLineDetectionModule.h"
#import "UIImage+OpenCV.h"
#import "RMImageUtils.h"
#import "RMVisionDebugBroker.h"
#import "RMVisionObjects.h"
#import <RMShared/RMShared.h>
#import <RMShared/DDLog.h>


#ifdef DEBUG_LINE_DETECT
#define LOG(...) DDLogWarn(__VA_ARGS__)
#else
#define LOG(...)
#endif //DEBUG_LINE_DETECT

// Private properties
@interface RMLineDetectionModule ()


@end


// RMLineDetectionModule
@implementation RMLineDetectionModule


- (id)initWithVision:(RMVision *)core
{
    LOG(@"");
    self = [super initModule:@"lineDetection"
                  withVision:core];
    
    if (self) {
        
        
    }
    
    return self;
}

- (void) shutdown
{
    [super shutdown];
    
}

- (void) dealloc
{
    
}

- (void)processFrame:(const cv::Mat)mat
           videoRect:(CGRect)rect
    videoOrientation:(AVCaptureVideoOrientation)videOrientation
{

    [super processFrame:mat videoRect:rect videoOrientation:videOrientation];
    
    
    
}

// convert to grayscale first

// rolling average each row, between 4-20 pixel window
// 


@end
