//
//  RMFakeVision.h
//  RMVision
//
//  Created on 8/18/13.
//  Copyright (c) 2013 Romotive, Inc. All rights reserved.
//

#import "RMVision.h"

#define FAKE_VISION 1

@interface RMFakeVision : RMVision

@property (atomic, readonly, getter=isRunning) BOOL running;


// Initialization takes a URL for a video, optionally can choose to en/disable
// "realtime" playback (when enabled, processes frames at roughly the framerate
// the video was recorded, dropping frames when necessary). By default realtime
// is enabled.
- (id)initWithFileURL:(NSURL *)vid;
- (id)initWithFileURL:(NSURL *)vid
           inRealtime:(BOOL)realtime;

- (void)startCapture;
- (void)startCaptureWithCompletion:(void (^)(BOOL isRunning))completion;
- (void)stopCapture;
- (void)stopCaptureWithCompletion:(void (^)(BOOL isRunning))completion;

- (void)setCamera:(RMCamera)camera;
- (void)setQuality:(RMCameraQuality)quality;
- (BOOL)activateModuleWithName:(NSString *)moduleName;
- (BOOL)deactivateModuleWithName:(NSString *)moduleName;

@end
