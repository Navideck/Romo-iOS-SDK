//
//  RMVideoModule.h
//  RMVision
//
//  Created on 6/24/13.
//  Copyright (c) 2013 Romotive, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RMVisionModuleProtocol.h"
#import "RMVisionModule.h"

@interface RMVideoModule : RMVisionModule <RMVisionModuleProtocol>

@property (nonatomic, getter=isRecording) BOOL recording;
@property (nonatomic) BOOL shouldSaveToPhotoAlbum;

- (id)initWithVision:(RMVision *)core recordToPath:(NSString *)path;

- (void)addVideoSampleBuffer:(CMSampleBufferRef)imageBuffer
               withTimestamp:(CMTime)timestamp
             withOrientation:(AVCaptureVideoOrientation)videoOrientation;

- (void)addAudioSampleBuffer:(CMSampleBufferRef)buffer
               withTimestamp:(CMTime)timestamp;

- (void)shutdownWithCompletion:(void(^)(void))callback;

@end
