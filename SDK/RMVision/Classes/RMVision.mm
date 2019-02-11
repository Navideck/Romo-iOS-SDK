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
//  RMVision.mm
//      Objective-C++ implementation of the back-end vision system
//  RMVision
//
//  Created on 10/26/12.
//  Copyright (c) 2012 Romotive. All rights reserved.
//
////////////////////////////////////////////////////////////////////////////////
#import "RMVision_Internal.h"

#import "RMFaceDetectionModule.h"
#import "RMEyeDetectionModule.h"
#import "RMGPUImageExampleModule.h"
#import "RMPictureModule.h"
#import "RMVideoModule.h"
#import <RMShared/RMMath.h>

#import "RMVisionDebugBroker.h"

#import "UIImage+OpenCV.h"

#import <GPUImage/GPUImageRawDataInput.h>
#import "GPUImageRawDataInput+RMAdditions.h"

#import "UIDevice+Romo.h"

#ifdef VISION_DEBUG
#define LOG(...) DDLogWarn(__VA_ARGS__)
#else
#define LOG(...)
#endif //VISION_DEBUG

// Constants
//------------------------------------------------------------------------------
static const int kFpsBuffer = 5;
static const int kVisionFrameRate = 24;
static const int kVisionSlowFrameRate = 5;
static const CGPoint kDefaultExposurePoint = CGPointMake(0.0, 0.0);
static const CGPoint kDefaultFocusPoint = CGPointMake(0.0, 0.0);

NSString *const RMVisionModule_TakePicture      = @"Picture";
NSString *const RMVisionModule_TakeVideo        = @"Video";
NSString *const RMVisionModule_FaceDetection    = @"FaceDetection";
NSString *const RMVisionModule_EyeDetection     = @"EyeDetection";
NSString *const RMVisionModule_GPUImageExample  = @"GPUImageExample";

// Private members
//------------------------------------------------------------------------------
@interface RMVision () <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate>

// AVFoundation components
@property (nonatomic, strong) AVCaptureSession            *session;
@property (nonatomic, strong) AVCaptureDevice             *device;
@property (nonatomic, strong) AVCaptureDevice             *microphone;
@property (nonatomic, strong) AVCaptureDeviceInput        *videoInput;
@property (nonatomic, strong) AVCaptureDeviceInput        *audioInput;
@property (nonatomic, strong) AVCaptureVideoDataOutput    *videoOutput;
@property (nonatomic, strong) AVCaptureAudioDataOutput    *audioOutput;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer  *videoPreviewLayer;

// Capture information
@property (nonatomic) float width;
@property (nonatomic) float height;
@property (nonatomic) BOOL  grayscaleMode;

@property (atomic)    float fps;

// Modules
@property (nonatomic, strong, readwrite) NSSet *activeModules;
@property (nonatomic, strong) RMFaceDetectionModule         *faceDetect;
@property (nonatomic, strong) RMEyeDetectionModule          *eyeDetect;
@property (nonatomic, strong) RMPictureModule               *picture;
@property (nonatomic, strong) RMVideoModule                 *video;
@property (nonatomic, strong) RMGPUImageExampleModule       *gpuImage;

// Fps calculation
@property (nonatomic) CMTimeValue   lastFrameTimestamp;
@property (nonatomic) float         *frameTimes;
@property (nonatomic) int           frameTimesIndex;
@property (nonatomic) int           framesToAverage;
@property (nonatomic) float         captureQueueFps;

@property (nonatomic) int queuedTargetFrameRate;
@property (nonatomic) CGPoint queuedFocusPointOfInterest;
@property (nonatomic) CGPoint queuedExposurePointOfInterest;

@property (atomic) cv::Mat lastFrame;

@property (nonatomic) GPUImageRawDataInput *gpuCameraDataSource;

/**
 To support asynchronous starting and stopping, we need to lock on whether or not we're changing
 capture state, and if that change is toward starting or stopping
 */
@property (atomic, getter=isTransitioning) BOOL transitioning;
@property (atomic, getter=isStarting) BOOL starting;

/** Keep a completion handler so we can queue up a start or stop command */
@property (nonatomic, copy) void (^transitionCompletion)(void);

/**
 If modules are activated while transitioning,
 add them to a queue and actually activate once we're done transitioning
 */
@property (nonatomic, strong) NSMutableArray *pendingModulesQueue;

@end

// Class Implementation
//==============================================================================
@implementation RMVision

@synthesize exposurePointOfInterest = _exposurePointOfInterest;
@synthesize focusPointOfInterest = _focusPointOfInterest;


#pragma mark - Initialization

// Default initializer (all available modules)
//------------------------------------------------------------------------------
- (id)init
{
    return [self initWithCamera:RMCamera_Front
                     andQuality:RMCameraQuality_Low];
}

// Initialize with a specific camera
//------------------------------------------------------------------------------
- (id)initWithCamera:(RMCamera)camera
{
    return [self initWithCamera:camera
                     andQuality:RMCameraQuality_Low];
}

// Initialize with a specific set of modules and a specified camera and quality
//------------------------------------------------------------------------------
- (id)initWithCamera:(RMCamera)camera
          andQuality:(RMCameraQuality)quality
{
    self = [super init];
    
    if (self) {
        LOG(@"Initializing...");
        _camera = camera;
        _quality = quality;
        _isSlow = ![[UIDevice currentDevice] isTelepresenceController];
        _targetFrameRate = _isSlow ? kVisionSlowFrameRate : kVisionFrameRate;
        _grayscaleMode = NO;
        
        _queuedFocusPointOfInterest = kDefaultFocusPoint;
        _queuedExposurePointOfInterest = kDefaultExposurePoint;

        // Only enable audio capture in RMVideoModule for debugging (as of now)
        _audioEnabled = NO;

#ifdef RECORD_AUDIO_ALL_DEVICES
        _audioEnabled = YES;
#endif
        
        // Set video size
        NSString *rawQuality = [self _getDeviceSpecificQuality:quality];
        if ([rawQuality isEqualToString:AVCaptureSessionPreset640x480]) {
            _width = 480;
            _height = 640;
        } else if ([rawQuality isEqualToString:AVCaptureSessionPreset352x288]) {
            _width = 288;
            _height = 352;
        } else {
            NSLog(@"ERROR: RMVision - unsupported quality");
        }
        
        // Update the broker with the info
        [RMVisionDebugBroker shared].width = _width;
        [RMVisionDebugBroker shared].height = _height;
        [RMVisionDebugBroker shared].core = self;
        
        // Create frame time circular buffer for calculating averaged fps
        _frameTimes = (float*)malloc(sizeof(float) * kFpsBuffer);
        
        _gpuCameraDataSource = [[GPUImageRawDataInput alloc] initWithSize:CGSizeMake(_width, _height)];
        LOG(@"Successfully initialized");
    }
    
    return self;
}

//------------------------------------------------------------------------------
- (void)dealloc
{
    if (_frameTimes) {
        free(_frameTimes);
    }
}

#pragma mark - Camera initialization / teardown
//------------------------------------------------------------------------------
- (void)startCapture
{
    [self startCaptureWithCompletion:nil];
}

//------------------------------------------------------------------------------
- (void)startCaptureWithCompletion:(void (^)(BOOL))completion
{
    LOG(@"Starting capture...");
    
    // Don't start if we're either (a) starting or (b) already started
    if (!self.isStarting && !self.session.isRunning) {
        // If we're transitioning to stop, set the completion to start
        if (self.isTransitioning) {
            LOG(@"...but we're transitioning...");
            __weak RMVision *weakSelf = self;
            self.transitionCompletion = ^{
                [weakSelf startCaptureWithCompletion:completion];
            };
        } else {
            LOG(@"...dispatching the start routine...");
            self.transitioning = YES;
            self.starting = YES;
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [self startCamera:self.camera withQuality:self.quality];
                
                if (self.pendingModulesQueue.count) {
                    NSArray *pendingModulesQueue = [NSArray arrayWithArray:self.pendingModulesQueue];
                    self.pendingModulesQueue = nil;
                    for (NSString *module in pendingModulesQueue) {
                        [self _activateModuleWithName:module];
                    }
                }
                self.transitioning = NO;
                self.starting = NO;
                
                if (self.queuedTargetFrameRate) {
                    float queuedTargetFrameRate = self.queuedTargetFrameRate;
                    self.queuedTargetFrameRate = 0;
                    self.targetFrameRate = queuedTargetFrameRate;
                }
                
                if (!CGPointEqualToPoint(self.queuedFocusPointOfInterest, kDefaultFocusPoint)) {
                    CGPoint queuedFocusPointOfInterest = self.queuedFocusPointOfInterest;
                    self.queuedFocusPointOfInterest = kDefaultFocusPoint;
                    self.focusPointOfInterest = queuedFocusPointOfInterest;
                }
                
                if (!CGPointEqualToPoint(self.queuedExposurePointOfInterest, kDefaultExposurePoint)) {
                    CGPoint queuedExposurePointOfInterest = self.queuedExposurePointOfInterest;
                    self.queuedExposurePointOfInterest = kDefaultExposurePoint;
                    self.exposurePointOfInterest = queuedExposurePointOfInterest;
                }
                
                
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(YES);
                    });
                }

                if (self.transitionCompletion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        void (^transitionCompletion)(void) = self.transitionCompletion;
                        self.transitionCompletion = nil;
                        transitionCompletion();
                    });
                }
            });
        }
    } else {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO);
            });
        }
        self.transitionCompletion = nil;
    }
}

// Sets up the video capture session for a given camera, quality and grayscale mode
//
// camera: -1 for default, 0 for back camera, 1 for front camera
// qualityPreset: [AVCaptureSession sessionPreset] value
// grayscale: YES to capture grayscale frames, NO to capture RGBA frames
//------------------------------------------------------------------------------
- (void)startCamera:(RMCamera)camera
        withQuality:(RMCameraQuality)qualityPreset
{
    // Initialize FPS vars
    self.lastFrameTimestamp = 0;
    self.frameTimesIndex = 0;
    self.captureQueueFps = 0.0f;
    self.fps = 0.0f;
    
    NSError *error = nil;
	
    // Set up AV capture
    NSArray* devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    
    if ([devices count] == 0) {
        NSLog(@"No video capture devices found");
        return;
    }
    
    if (camera >= 0 && camera < [devices count]) {
        self.device = [devices objectAtIndex:camera];
    } else {
        self.device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }
    
    // Create the capture session
    self.session = [[AVCaptureSession alloc] init];
    [self.session beginConfiguration];
    
    // Get the best preset for the device
    self.session.sessionPreset = [self _getDeviceSpecificQuality:qualityPreset];
    
    // Create device input
    self.videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:self.device
                                                             error:&error];
    if (error) {
        LOG(@"ERROR: AVCaptureDeviceInput failed (camera)");
        return;
    }
    
    // Connect up input
    if ([self.session canAddInput:self.videoInput]) {
        [self.session addInput:self.videoInput];
    }
    
    // Create and configure device output
    self.videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    
    dispatch_queue_t visionQueue = dispatch_queue_create("com.romotive.vision.processing", NULL);
    [self.videoOutput setSampleBufferDelegate:self queue:visionQueue];
    
    self.videoOutput.alwaysDiscardsLateVideoFrames = YES;
    
    // For grayscale mode, the luminance channel from the YUV fromat is used
    // For color mode, BGRA format is used
    OSType format = kCVPixelFormatType_32BGRA;
    
    // Check YUV format is available before selecting it (iPhone 3 does not support it)
    if ([self isGrayscaleMode] && [self.videoOutput.availableVideoCVPixelFormatTypes containsObject:
                                   [NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]]) {
        format = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
    }
    
    self.videoOutput.videoSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedInt:format]
                                                                 forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    // Connect up output
    if ([self.session canAddOutput:self.videoOutput]) {
        [self.session addOutput:self.videoOutput];
    }
    
    // Setting connection properties must go after adding the output
    for (AVCaptureConnection *connection in self.videoOutput.connections) {
        if (connection.supportsVideoOrientation) {
            connection.videoOrientation = AVCaptureVideoOrientationPortrait;
        }
    }
    
    // Set the frame rate
    [self applyNewFrameRate:self.targetFrameRate];

    // Set the exposure and focus point to default (center of image)
    [self applySetFocusPointOfInterest:kDefaultFocusPoint];
    [self applySetExposurePointOfInterest:kDefaultExposurePoint];
    
    // Add audio capture
    if (self.audioEnabled) {
        self.microphone = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
        self.audioInput = [AVCaptureDeviceInput deviceInputWithDevice:self.microphone error:&error];
        if (error) {
            LOG(@"ERROR: AVCaptureDeviceInput failed (microphone)");
            return;
        }
        
        if ([self.session canAddInput:self.audioInput]) {
            [self.session addInput:self.audioInput];
        }
        self.audioOutput = [[AVCaptureAudioDataOutput alloc] init];
        
        if ([self.session canAddOutput:self.audioOutput]) {
            [self.session addOutput:self.audioOutput];
        } else {
            LOG(@"Couldn't add audio output");
        }
        dispatch_queue_t audioCaptureQueue = dispatch_queue_create("com.romotive.vision.audioCapture", NULL);
        [self.audioOutput setSampleBufferDelegate:self queue:audioCaptureQueue];
    }
    
    // Commit the configuration!
    [self.session commitConfiguration];
    
    [AVCaptureVideoPreviewLayer layerWithSession:self.session];
    
    
    self.videoPreviewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
    
    [self.session startRunning];
    
    dispatch_async(dispatch_get_main_queue(), ^(void){
        [[RMVisionDebugBroker shared] visionStarted];
    });
}

//------------------------------------------------------------------------------
- (void)stopCapture
{
    [self stopCaptureWithCompletion:nil];
}

//------------------------------------------------------------------------------
- (void)stopCaptureWithCompletion:(void (^)(BOOL))completion
{
    LOG(@"Stopping capture...");
    // Don't stop if we're either (a) stopping or (b) already stopped
    BOOL isStopping = self.transitioning && !self.isStarting;
    BOOL stopped = !self.session.isRunning && !self.transitioning;
    if (!isStopping && !stopped) {
        // If we're transitioning to start, set the completion to stop
        if (self.isTransitioning && self.isStarting) {
            LOG(@"...but we're transitioning...");
            __weak RMVision *weakSelf = self;
            self.transitionCompletion = ^{
                [weakSelf stopCaptureWithCompletion:completion];
            };
        } else {
            LOG(@"...dispatching the stop routine...");
            self.transitioning = YES;
            
            [self.session stopRunning];

            [self.videoOutput setSampleBufferDelegate:nil queue:NULL];
            [self.audioOutput setSampleBufferDelegate:nil queue:NULL];
            
            [self.session beginConfiguration];

            [self.session removeInput:self.videoInput];
            [self.session removeOutput:self.videoOutput];
            
            self.videoInput = nil;
            self.videoOutput = nil;
            
            
            if ([self.session.inputs containsObject:self.audioInput]) {
                [self.session removeInput:self.audioInput];
            }
            
            if ([self.session.outputs containsObject:self.audioOutput]) {
                [self.session removeOutput:self.audioOutput];
            }
            
            self.audioInput = nil;
            self.audioOutput = nil;

            [self.session commitConfiguration];

            // Disable all the modules
            [self.activeModules makeObjectsPerformSelector:@selector(shutdown)];
            self.activeModules = nil;
            
            [self.gpuCameraDataSource removeAllTargets];
            self.gpuCameraDataSource = nil;
            
            self.device = nil;
            self.session = nil;
            
            // Notify the broker
            [RMVisionDebugBroker shared].running = NO;
            
            // Remove the video preview
            if (self.videoPreviewLayer) {
                [self.videoPreviewLayer removeFromSuperlayer];
                self.videoPreviewLayer = nil;
            }
            
            free(self.frameTimes);
            self.frameTimes = nil;
            
            self.transitioning = NO;

            if (completion) {
                LOG(@"...and running your completion...");
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(YES);
                });
            }
            
            if (self.transitionCompletion) {
                void (^transitionCompletion)(void) = self.transitionCompletion;
                self.transitionCompletion = nil;
                transitionCompletion();
            }
        }
    }
    else {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO);
            });
        }
    }
}

// Switch camera at runtime
//------------------------------------------------------------------------------
- (void)setCamera:(RMCamera)camera
{
    if (camera != _camera) {
        _camera = camera;
        
        if (self.session) {
            [self.session beginConfiguration];
            
            NSArray* devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
            
            [self.session removeInput:self.videoInput];
            
            if (self.camera >= 0 && self.camera < [devices count]) {
                self.device = [devices objectAtIndex:camera];
            } else {
                self.device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
            }
            
            // Create device input
            NSError *error = nil;
            self.videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:self.device
                                                                     error:&error];
            [self.session addInput:self.videoInput];
            [self.session commitConfiguration];
        }
    }
}

//------------------------------------------------------------------------------
- (void)setQuality:(RMCameraQuality)quality
{
    if (quality != _quality) {
        if (self.session) {
            [self.session beginConfiguration];
            
            NSString *nativeQualityPreset = [self _getDeviceSpecificQuality:quality];
            if ([self.session canSetSessionPreset:nativeQualityPreset]) {
                self.session.sessionPreset = nativeQualityPreset;
            }
            
            [self.session commitConfiguration];
        }
    }
}

//------------------------------------------------------------------------------
- (NSString *)_getDeviceSpecificQuality:(RMCameraQuality)quality
{
    if (self.isSlow) {
        return AVCaptureSessionPreset352x288;
    } else {
        switch (quality) {
            case RMCameraQuality_High:
                return AVCaptureSessionPreset640x480;
                break;
            case RMCameraQuality_Low:
            default:
                return AVCaptureSessionPreset352x288;
                break;
        }
    }
}

//------------------------------------------------------------------------------
-(void)applyNewFrameRate:(int)frameRate
{
    NSError *error;
    
    if ( [self.device lockForConfiguration:&error] ) {
        if (@available(iOS 7.0, *)) {
            [self.device setActiveVideoMinFrameDuration:CMTimeMake(1, frameRate)];
            [self.device setActiveVideoMaxFrameDuration:CMTimeMake(1, frameRate)];
        } else {
            // Fallback on earlier versions
            for (AVCaptureConnection *connection in self.videoOutput.connections) {
                if (connection.supportsVideoMinFrameDuration) {
                    connection.videoMinFrameDuration = CMTimeMake(1, frameRate);
                }

                if (connection.supportsVideoMaxFrameDuration) {
                    connection.videoMaxFrameDuration = CMTimeMake(1, frameRate);
                }
            }
        }
        [self.device unlockForConfiguration];
    } else {
        NSLog(@"Error: %@", error);
    }
}

//------------------------------------------------------------------------------
-(void)applySetFocusPointOfInterest:(CGPoint)point
{
    NSError *error;
    
    if ([self.device isFocusModeSupported:AVCaptureFocusModeAutoFocus] && [self.device isFocusPointOfInterestSupported]) {
        
        if ([self.device lockForConfiguration:&error]) {
            
            // Convert from Romo coordinate system
            /*
             From Apple's documentation:
             https://developer.apple.com/library/ios/documentation/AudioVideo/Conceptual/AVFoundationPG/Articles/04_MediaCapture.html
             You pass a CGPoint where {0,0} represents the top left of the picture area, and {1,1} represents the bottom right in landscape mode with the home button on the right—this applies even if the device is in portrait mode.
             */
            
            // Assuming portrait mode
            CGPoint imagePoint;
            
            // Front camera mirrored
            if (self.camera == RMCamera_Front) {
                imagePoint = CGPointMake(point.y / 2.0 + 0.5, point.x / 2.0 + 0.5);
            } else {
                imagePoint = CGPointMake(point.y / 2.0 + 0.5, 1.0 - (point.x / 2.0 + 0.5));
            }
            
            
            [self.device setFocusPointOfInterest:imagePoint];
            [self.device setFocusMode:AVCaptureFocusModeAutoFocus];
            [self.device unlockForConfiguration];
        } else {
            NSLog(@"Error: %@", error);
        }
    }
}

//------------------------------------------------------------------------------
-(void)applySetExposurePointOfInterest:(CGPoint)point
{
    NSError *error;
    
    if ([self.device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure] && [self.device isExposurePointOfInterestSupported]) {
        
        if ([self.device lockForConfiguration:&error]) {
            
            // Convert from Romo coordinate system
            /*
             From Apple's documentation:
             https://developer.apple.com/library/ios/documentation/AudioVideo/Conceptual/AVFoundationPG/Articles/04_MediaCapture.html
             You pass a CGPoint where {0,0} represents the top left of the picture area, and {1,1} represents the bottom right in landscape mode with the home button on the right—this applies even if the device is in portrait mode.
             */
            
            // Assuming portrait mode
            CGPoint imagePoint;
            
            // Front camera mirrored
            if (self.camera == RMCamera_Front) {
                imagePoint = CGPointMake(point.y / 2.0 + 0.5, point.x / 2.0 + 0.5);
            } else {
                imagePoint = CGPointMake(point.y / 2.0 + 0.5, 1.0 - (point.x / 2.0 + 0.5));
            }
            
            [self.device setExposurePointOfInterest:imagePoint];
            [self.device setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
            [self.device unlockForConfiguration];
        } else {
            NSLog(@"Error: %@", error);
        }
    }
}

//------------------------------------------------------------------------------
- (BOOL)isRunning
{
    return self.session.isRunning;
}

#pragma mark - Modules

//------------------------------------------------------------------------------
- (NSSet *)activeModules
{
    if (!_activeModules) {
        _activeModules = [NSSet set];
    }
    return _activeModules;
}

//------------------------------------------------------------------------------
- (void)activateModule:(id<RMVisionModuleProtocol>)module
{
    LOG(@"Activating module: %@", module.name);
    module.vision = self;
    self.activeModules = [self.activeModules setByAddingObject:module];
    
    if ([module conformsToProtocol:@protocol(GPUImageInput)]) {
        [self.gpuCameraDataSource addTarget:(id<GPUImageInput>)module];
    }
}

//------------------------------------------------------------------------------
- (void)deactivateModule:(id<RMVisionModuleProtocol>)module
{
    if (module) {
        LOG(@"Deactivating module: %@", module.name);
        module.vision = nil;
        NSMutableSet *modules = [NSMutableSet setWithSet:self.activeModules];
        [modules removeObject:module];
        self.activeModules = [modules copy];
        
        if ([module conformsToProtocol:@protocol(GPUImageInput)]) {
            [self.gpuCameraDataSource removeTarget:(id<GPUImageInput>)module];
        }
    }
}

//------------------------------------------------------------------------------
- (void)deactivateAllModules
{
    LOG(@"Deactivating all modules...");
    NSSet *activeModules = self.activeModules;
    for (id<RMVisionModuleProtocol> module in activeModules) {
        [self deactivateModule:module];
    };
}

// Enables a specified module
//------------------------------------------------------------------------------
- (BOOL)activateModuleWithName:(NSString *)moduleName
{
    if (self.isTransitioning) {
        LOG(@"Activating during transition: %@", moduleName);
        if (!self.pendingModulesQueue) {
            self.pendingModulesQueue = [NSMutableArray array];
        }
        if (![self.pendingModulesQueue containsObject:moduleName]) {
            [self.pendingModulesQueue addObject:moduleName];
            return YES;
        } else {
            return NO;
        }
    } else {
        return [self _activateModuleWithName:moduleName];
    }
}

// Internal method which actually enables the module
//------------------------------------------------------------------------------
- (BOOL)_activateModuleWithName:(NSString *)moduleName
{
    // Check if the module has already been activated
    for (id<RMVisionModuleProtocol> module in self.activeModules) {
        if ([[module name] isEqualToString:moduleName]) {
            return NO;
        }
    }
        
    // Module is available and uninitialized. Actiave that shit!
    LOG(@"Activating module: %@", moduleName);
    id activatedModule;
    if ([moduleName isEqualToString:RMVisionModule_TakePicture]) {
        self.picture = [[RMPictureModule alloc] initWithVision:self];
        activatedModule = self.picture;
    } else if ([moduleName isEqualToString:RMVisionModule_TakeVideo]) {
        if (!self.video) {
            self.video = [[RMVideoModule alloc] initWithVision:self];
        }
        activatedModule = self.video;
    } else if ([moduleName isEqualToString:RMVisionModule_FaceDetection]) {
        self.faceDetect = [[RMFaceDetectionModule alloc] initWithVision:self];
        activatedModule = self.faceDetect;
    } else if ([moduleName isEqualToString:RMVisionModule_EyeDetection]) {
        if (!self.faceDetect) {
            self.faceDetect = [[RMFaceDetectionModule alloc] initWithVision:self];
            self.activeModules = [self.activeModules setByAddingObject:self.faceDetect];
        }
        self.eyeDetect = [[RMEyeDetectionModule alloc] initWithVision:self];
        self.eyeDetect.faceDetector = self.faceDetect;
        activatedModule = self.eyeDetect;
    } else if ([moduleName isEqualToString:RMVisionModule_GPUImageExample]) {
        self.gpuImage = [[RMGPUImageExampleModule alloc] initModule:moduleName withVision:self];
        [self.gpuCameraDataSource addTarget:self.gpuImage];
        activatedModule = self.gpuImage;
    } else {
        // Custom module
    }
    
    // Add to list of active modules
    if (activatedModule != nil) {
        self.activeModules = [self.activeModules setByAddingObject:activatedModule];
    }
    return YES;
}

// Disables a specified module
//------------------------------------------------------------------------------
- (BOOL)deactivateModuleWithName:(NSString *)moduleName
{
    // Loop through active modules, looking for module to deactivate
    for (id<RMVisionModuleProtocol> module in self.activeModules) {
        if ([module.name isEqualToString:moduleName]) {
            LOG(@"Deactivating module: %@", moduleName);
            // Shut down the module
            [module shutdown];
            
            // Remove the module
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.name != %@", moduleName];
            self.activeModules = [self.activeModules filteredSetUsingPredicate:predicate];
            
            // Set it to nil
            if ([moduleName isEqualToString:RMVisionModule_TakePicture]) {
                self.picture = nil;
            } else if ([moduleName isEqualToString:RMVisionModule_TakeVideo]) {
//                self.video = nil;
            } else if ([moduleName isEqualToString:RMVisionModule_FaceDetection]) {
                self.faceDetect = nil;
            } else if ([moduleName isEqualToString:RMVisionModule_EyeDetection]) {
                self.eyeDetect = nil;
            } else if ([moduleName isEqualToString:RMVisionModule_GPUImageExample]) {
                [self.gpuCameraDataSource removeTarget:self.gpuImage];
                self.gpuImage = nil;
            } else {
                // Custom module
            }
            return YES;
        }
    }
    
    // Unable to deactivate the desired module
    return NO;
}

//------------------------------------------------------------------------------
- (BOOL)pauseModuleWithName:(NSString *)moduleName
{
    // Loop through active modules, looking for module to deactivate
    for (id<RMVisionModuleProtocol> module in self.activeModules) {
        if ([module.name isEqualToString:moduleName]) {
            LOG(@"Pausing module: %@", moduleName);
            module.paused = YES;
            return YES;
        }
    }
    
    // Unable to deactivate the desired module
    return NO;
}

//------------------------------------------------------------------------------
- (BOOL)unpauseModuleWithName:(NSString *)moduleName
{
    // Loop through active modules, looking for module to deactivate
    for (id<RMVisionModuleProtocol> module in self.activeModules) {
        if ([module.name isEqualToString:moduleName]) {
            LOG(@"Un-pausing module: %@", moduleName);
            module.paused = NO;
            return YES;
        }
    }
    
    // Unable to deactivate the desired module
    return NO;
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
// AVCaptureVideoDataOutputSampleBufferDelegate delegate method called when a
// video frame is available
//
// This method is called on the video capture GCD queue. A cv::Mat is created
// from the frame data and passed on for processing with OpenCV.
//------------------------------------------------------------------------------
- (void) captureOutput:(AVCaptureOutput *)captureOutput
 didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
        fromConnection:(AVCaptureConnection *)connection
{
    NSSet *modules = self.activeModules;
    CMTime presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);

    if (captureOutput == self.videoOutput) {
        dispatch_sync(dispatch_get_main_queue(), ^(void) {
            if (!self.session.isRunning || [UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
                return;
            }
        });

        CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        OSType format = CVPixelBufferGetPixelFormatType(pixelBuffer);
        CGRect videoRect = CGRectMake(0.0f, 0.0f, CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetHeight(pixelBuffer));
        AVCaptureVideoOrientation videoOrientation = [[[self.videoOutput connections] objectAtIndex:0] videoOrientation];
        
        if (format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
            // For grayscale mode, the luminance channel of the YUV data is used
            CVPixelBufferLockBaseAddress(pixelBuffer, 0);
            void *baseaddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
            
            cv::Mat mat = cv::Mat(videoRect.size.height, videoRect.size.width, CV_8UC1, baseaddress, 0).clone();
            
            [self processFrame:mat videoRect:videoRect videoOrientation:videoOrientation modules:modules];
            
            CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        } else if (format == kCVPixelFormatType_32BGRA) {
            // For color mode a 4-channel cv::Mat is created from the BGRA data
            CVPixelBufferLockBaseAddress(pixelBuffer, 0);
            void *baseaddress = CVPixelBufferGetBaseAddress(pixelBuffer);
            
            cv::Mat mat = cv::Mat(videoRect.size.height, videoRect.size.width, CV_8UC4, baseaddress, 0).clone();
            
            [self processFrame:mat videoRect:videoRect videoOrientation:videoOrientation modules:modules];
            
            CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        } else {
            NSLog(@"Unsupported video format");
        }
        
        // Update FPS calculation
        if ([RMVisionDebugBroker shared].showFPS) {
            [self _updateFPS:presentationTime];
        }
        
        for (id <RMVisionModuleProtocol> module in modules) {
            
            // Check if the module wants the raw sample buffers
            if ([module respondsToSelector:@selector(processSampleBuffer:)]) {
                [module processSampleBuffer:sampleBuffer];
            }
            
            // Video module
            if ([module isKindOfClass:[RMVideoModule class]]) {
                RMVideoModule *videoModule = (RMVideoModule *)module;
                if (videoModule.isRecording) {
                    [videoModule addVideoSampleBuffer:sampleBuffer
                                        withTimestamp:presentationTime
                                      withOrientation:videoOrientation];
                }
            }
        }
    } else if (self.audioEnabled && (captureOutput == self.audioOutput)) {
        // Notify video module if active
        for (id <RMVisionModuleProtocol> module in modules) {
            if ([module isKindOfClass:[RMVideoModule class]]) {
                RMVideoModule *videoModule = (RMVideoModule *)module;
                if (videoModule.isRecording) {
                    [videoModule addAudioSampleBuffer:sampleBuffer
                                        withTimestamp:presentationTime];
                }
            }
            
        }
    }
}

#pragma mark - Image Processing

// Note that this method is called on the video capture GCD queue.
//  Use dispatch_sync or dispatch_async to update UI from the main queue.
//
// mat: The frame as an OpenCV::Mat object. The matrix will have 1 channel for
//      grayscale frames and 4 channels for BGRA frames.
// rect: A CGRect describing the video frame dimensions
// orientation: Will generally by AVCaptureVideoOrientationLandscapeRight for the back camera and
//              AVCaptureVideoOrientationLandscapeRight for the front camera
//------------------------------------------------------------------------------
- (void) processFrame:(const cv::Mat)mat
            videoRect:(CGRect)rect
     videoOrientation:(AVCaptureVideoOrientation)orientation
              modules:(NSSet *)modules
{
    
    GLubyte *rawDataBytes = (GLubyte *)mat.data;
    [self.gpuCameraDataSource updateDataFromBytes:rawDataBytes size:rect.size];
    [self.gpuCameraDataSource processData];
    
    // Flip image when using the front camera
    if (self.camera == RMCamera_Front) {
        self.imageFlipped = NO;
    }
    
    // If lastFrame is empty since this is the first frame
    if (!self.lastFrame.data) {
        self.lastFrame = mat;
    }
    
    // Loop through modules
    [modules enumerateObjectsUsingBlock:^(id<RMVisionModuleProtocol> module, BOOL *stop) {
        @autoreleasepool {
            if (!module.paused) {
                [module processFrame:mat videoRect:rect videoOrientation:orientation];
            }
        }
    }];
    
    self.lastFrame = mat;
}

//------------------------------------------------------------------------------
- (UIImage *)currentImage
{
    
    UIImageOrientation imageOrientation;
    
    if (self.camera == RMCamera_Front && !self.isImageFlipped) {
        imageOrientation = UIImageOrientationUpMirrored;
    } else {
        imageOrientation = UIImageOrientationUp;
    }
    
    return [[UIImage alloc] initWithCVMat:self.lastFrame scale:1.0 orientation:imageOrientation];
}

#pragma mark - Training
// Training
//------------------------------------------------------------------------------
- (BOOL)trainModule:(NSString *)moduleName
           withData:(id)trainingData
{
    // Check if it's one of the modules we can train
    return NO;
}

#pragma mark - Debugging
//------------------------------------------------------------------------------
- (void)_updateFPS:(CMTime)presentationTime
{
    if (!self.session) {
        return;
    }
    if (self.lastFrameTimestamp == 0) {
        self.lastFrameTimestamp = presentationTime.value;
        self.framesToAverage = 1;
    } else {
        float frameTime = (float)(presentationTime.value - self.lastFrameTimestamp) / presentationTime.timescale;
        self.lastFrameTimestamp = presentationTime.value;
        
        self.frameTimes[self.frameTimesIndex++] = frameTime;
        
        if (self.frameTimesIndex >= kFpsBuffer) {
            self.frameTimesIndex = 0;
        }
        
        float totalFrameTime = 0.0f;
        for (int i = 0; i < self.framesToAverage; i++) {
            totalFrameTime += self.frameTimes[i];
        }
        
        float averageFrameTime = totalFrameTime / self.framesToAverage;
        float fps = 1.0f / averageFrameTime;
        
        if (fabsf(fps - self.captureQueueFps) > 0.1f) {
            self.captureQueueFps = fps;
            
            dispatch_async(dispatch_get_main_queue(), ^(void){
                [RMVisionDebugBroker shared].fps = fps;
            });
            self.fps = fps;
        }
        
        self.framesToAverage++;
        if (self.framesToAverage > kFpsBuffer) {
            self.framesToAverage = kFpsBuffer;
        }
    }
}

#pragma mark - Accessors

//------------------------------------------------------------------------------
-(void)setTargetFrameRate:(int)targetFrameRate
{
    if (self.isTransitioning) {
        self.queuedTargetFrameRate = targetFrameRate;
    } else {
        if (targetFrameRate != _targetFrameRate && self.session) {
            _targetFrameRate = targetFrameRate;
            
            [self.session beginConfiguration];
            
            [self applyNewFrameRate:_targetFrameRate];
            
            [self.session commitConfiguration];
        }
    }
}

//------------------------------------------------------------------------------
-(CGPoint)exposurePointOfInterest
{
    // Convert to Romo coordinates
    CGPoint exposurePoint;
    
    // Front camera mirrored
    if (self.camera == RMCamera_Front) {
        exposurePoint = CGPointMake((self.device.exposurePointOfInterest.y * 2.0) - 1.0, (self.device.exposurePointOfInterest.x * 2.0) - 1.0);
    } else {
        exposurePoint = CGPointMake(1.0 - (self.device.exposurePointOfInterest.y * 2.0), (self.device.exposurePointOfInterest.x * 2.0) - 1.0);
    }
    
    return exposurePoint;
}

//------------------------------------------------------------------------------
-(void)setExposurePointOfInterest:(CGPoint)exposurePointOfInterest
{
    if (self.isTransitioning) {
        self.queuedExposurePointOfInterest = exposurePointOfInterest;
    } else {
        if (self.session) {
            _exposurePointOfInterest = exposurePointOfInterest;
            
            [self.session beginConfiguration];
            
            [self applySetExposurePointOfInterest:exposurePointOfInterest];
            
            [self.session commitConfiguration];
        }
    }
}

//------------------------------------------------------------------------------
-(CGPoint)focusPointOfInterest
{
    // Convert to Romo coordinates
    CGPoint focusPoint;
    
    // Front camera mirrored
    if (self.camera == RMCamera_Front) {
        focusPoint = CGPointMake((self.device.focusPointOfInterest.y * 2.0) - 1.0, (self.device.focusPointOfInterest.x * 2.0) - 1.0);
    } else {
        focusPoint = CGPointMake(1.0 - (self.device.focusPointOfInterest.y * 2.0), (self.device.focusPointOfInterest.x * 2.0) - 1.0);
    }
    
    return focusPoint;
}

//------------------------------------------------------------------------------
-(void)setFocusPointOfInterest:(CGPoint)focusPointOfInterest
{
    if (self.isTransitioning) {
        self.queuedFocusPointOfInterest = focusPointOfInterest;
    } else {
        if (self.session) {
            _focusPointOfInterest = focusPointOfInterest;
            
            [self.session beginConfiguration];
            
            [self applySetFocusPointOfInterest:_focusPointOfInterest];
            
            [self.session commitConfiguration];
        }
    }
}

@end
