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
//  RMVision.h
//  RMVision
//
//  Created by Romotive on 10/26/12.
//  Copyright (c) 2012 Romotive. All rights reserved.
//
////////////////////////////////////////////////////////////////////////////////
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

#import "RMVisionObjects.h"
#import "RMVisionModuleProtocol.h"

@class RMVisionModule;
@class RMVisionTrainingData;

/**
 Simple data type to indicate camera types
 */
typedef enum {
    /// Indicates the back camera
    RMCamera_Back    = 0,
    /// Indicates the front-facing camera
    RMCamera_Front   = 1
} RMCamera;

/**
 Simple data type to indicate quality of camera capture 
 */
typedef enum {
    /// High
    RMCameraQuality_High,
    /// Low
    RMCameraQuality_Low
} RMCameraQuality;

/**
 A state of normalized brightness for the current vision feed
 */
typedef enum {
    RMVisionBrightnessStateUnknown   = 0,
    RMVisionBrightnessStateTooDark   = 1,
    RMVisionBrightnessStateDark      = 2,
    RMVisionBrightnessStateBright    = 3,
    RMVisionBrightnessStateTooBright = 4,
} RMVisionBrightnessState;

/**
 The pre-built modules
 */
extern NSString *const RMVisionModule_TakePicture;
extern NSString *const RMVisionModule_TakeVideo;
extern NSString *const RMVisionModule_FaceDetection;
extern NSString *const RMVisionModule_EyeDetection;
extern NSString *const RMVisionModule_GPUImageExample;

// Forward definition
@protocol RMVisionDelegate;

/**
 Captures video from an iOS camera and delegates the frame to an arbitrary
 number of vision modules
 */
@interface RMVision : NSObject

// Capture properties
@property (nonatomic) RMCamera camera;

@property (nonatomic) RMCameraQuality quality;
@property (nonatomic, readonly) float width;
@property (nonatomic, readonly) float height;
@property (nonatomic, readonly, getter=isGrayscaleMode) BOOL grayscaleMode;
@property (nonatomic, readonly) BOOL isSlow;
@property (atomic, readonly, getter=isRunning) BOOL running;
@property (nonatomic, getter=isImageFlipped) BOOL imageFlipped;
@property (nonatomic, getter=isAudioEnabled) BOOL audioEnabled;

@property (nonatomic) int targetFrameRate;

// Focus and exposure point of interest are in Romo coordinate system
// (0,0) center of image
// (-1, -1) top-left of image
// (1, 1) bottom-right of image
@property (nonatomic) CGPoint focusPointOfInterest;
@property (nonatomic) CGPoint exposurePointOfInterest;

// Performance
@property (atomic, readonly) float fps;

// Delegate
@property (nonatomic, weak) id <RMVisionDelegate> delegate;

// AVFoundation components
@property (nonatomic, readonly) AVCaptureSession            *session;
@property (nonatomic, readonly) AVCaptureDevice             *device;
@property (nonatomic, readonly) AVCaptureVideoDataOutput    *videoOutput;
@property (nonatomic, readonly) AVPlayerLayer  *videoPreviewLayer;

// Initialization
//------------------------------------------------------------------------------
- (id)init;

- (id)initWithCamera:(RMCamera)camera;

- (id)initWithCamera:(RMCamera)camera
          andQuality:(RMCameraQuality)quality;

// Capturing
//------------------------------------------------------------------------------
- (void)startCapture;
- (void)startCaptureWithCompletion:(void (^)(BOOL didSuccessfullyStart))completion;
- (void)stopCapture;
- (void)stopCaptureWithCompletion:(void (^)(BOOL didSuccessfullyStop))completion;

- (UIImage *)currentImage;

// Modules

/**
 A set of active modules that conform to the RMVisionModuleProtocol
 */
@property (nonatomic, strong, readonly) NSSet *activeModules;

/**
 Given an object that conforms to the RMVisionModuleProtocol
 Registers it with this RMVision instance and provides frames when not paused
 */
- (void)activateModule:(id<RMVisionModuleProtocol>)module;

/** 
 Unregisters the given module and stops providing frames
 */
- (void)deactivateModule:(id<RMVisionModuleProtocol>)module;

- (void)deactivateAllModules;

- (BOOL)activateModuleWithName:(NSString *)moduleName;
- (BOOL)deactivateModuleWithName:(NSString *)moduleName;

- (BOOL)pauseModuleWithName:(NSString *)moduleName;
- (BOOL)unpauseModuleWithName:(NSString *)moduleName;

// Training
//------------------------------------------------------------------------------
- (BOOL)trainModule:(NSString *)moduleName
           withData:(id)trainingData;

@end

@protocol RMVisionDelegate <NSObject>

@optional

// Face detection
//------------------------------------------------------------------------------
/**
 Delegate method that is triggered when a face is detected
 */
- (void)didDetectFace:(RMFace *)face;

/**
 Triggered when a face is lost
 */
- (void)didLoseFace;

// Motion detection
//------------------------------------------------------------------------------
/**
 Delegate method that is triggered when motion is detected
 */
- (void)didDetectMotion:(RMMotion *)motion;

/**
 Triggered when motion is lost
 */
- (void)didLoseMotion;

// Blob Detection
//------------------------------------------------------------------------------
/**
 Delegate method that is triggered when a brightly colored blob is detected
 */
- (void)didDetectBlob:(RMBlob *)blob;

/**
 Triggered when a blob is lost
 */
- (void)didLoseBlob;

// Line Detection
//------------------------------------------------------------------------------
/**
 Delegate method that is triggered when a line is detected
 */
- (void)didDetectLine:(RMLine *)line;

/**
 Triggered when the line is lost
 */
- (void)didLoseLine:(RMLine *)line;

// Color Detection
//------------------------------------------------------------------------------
/**
 Delegate method that is triggered when one or more bright colors are detected
 */
- (void)didDetectColors:(RMColors *)colors;

/**
 Triggered when no bright colors are detected
 */
- (void)didLoseColors;


// Debug
//------------------------------------------------------------------------------
/**
 Triggered when a debug image is available
 */
- (void)showDebugImage:(UIImage *)debugImage;

@end
