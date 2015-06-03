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
//  RMVisionModuleProtocol.h
//  RMVision
//
//  Created by Romotive on 10/28/12.
//  Copyright (c) 2012 Romotive. All rights reserved.
// 
////////////////////////////////////////////////////////////////////////////////
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>


@class RMVision;

/**
 @brief The Protocol that all vision modules adhere to
 
 This protocol defines the methods that every vision module should implement.
 */
@protocol RMVisionModuleProtocol <NSObject>

@property (nonatomic, weak) RMVision *vision;
@property (nonatomic) BOOL paused;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic) unsigned int frameNumber;

- (id)initWithVision:(RMVision *)core;
- (void)shutdown;

#ifdef __cplusplus
- (void)processFrame:(const cv::Mat)mat
           videoRect:(CGRect)rect
    videoOrientation:(AVCaptureVideoOrientation)videOrientation;
#endif

@optional

// Allows access to the CMSampleBufferRef. Used by brightness metering module.
- (void)processSampleBuffer:(CMSampleBufferRef)samplebuffer;

// NSArray contains: @[UIImage, UIImage, NSArray]
//      First item is sampled image, second item contains annotations, 3rd item contains an array of UIColors
- (void)trainWithData:(id)data;

@end
