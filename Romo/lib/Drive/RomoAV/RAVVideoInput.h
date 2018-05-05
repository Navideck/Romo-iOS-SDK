//
//  RMVideoInput.h
//  RomoAV
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

#ifndef SIMULATOR
#import "H264HwEncoderImpl.h"
#endif

typedef enum {
    RMVideoQualityLow,
    RMVideoQualityDefault,
    RMVideoQualityHigh,
} RMVideoQuality;

typedef void (^VideoInputBlock)(const void *frame, uint32_t length, CMTime pts);

@protocol RMVideoInputDelegate;
@protocol RMVideoImageCapturingDelegate;

@interface RAVVideoInput : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate, H264HwEncoderImplDelegate>

@property (nonatomic, weak) id <RMVideoInputDelegate> inputDelegate;
@property (nonatomic, weak) id <RMVideoImageCapturingDelegate> imageCapturingDelegate;
@property (nonatomic, copy) VideoInputBlock inputBlock;
@property (nonatomic) BOOL running;
@property (nonatomic) RMVideoQuality videoQuality;

#pragma mark - Creation --

+ (RAVVideoInput *)input;

#pragma mark - Methods --

/**
 * Starts the capture session.
 */
- (void)start;

/**
 * Stops the capture session.
 */
- (void)stop;

- (void)captureStillImage;

@end

// Input of video frames
@protocol RMVideoInputDelegate <NSObject>

- (void)capturedFrame:(const void *)frame length:(uint32_t)length;

@end

// Capturing photos from video
@protocol RMVideoImageCapturingDelegate <NSObject>

- (void)didFinishCapturingStillImage:(UIImage *)image;

@end
