//
//  RMVision_Internal.h
//  RMVision
//
//  Created on 8/28/13.
//  Copyright (c) 2013 Romotive, Inc. All rights reserved.

// A handful of declarations that are shared internally, but we don't want to
// expose via public headers

#import "RMVision.h"

@interface RMVision (Internal)

@property (nonatomic, strong) AVPlayerLayer *videoPreviewLayer;

#ifdef __cplusplus

- (void)processFrame:(const cv::Mat)mat
           videoRect:(CGRect)rect
    videoOrientation:(AVCaptureVideoOrientation)orientation
             modules:(NSSet *)modules;

#endif

@end
