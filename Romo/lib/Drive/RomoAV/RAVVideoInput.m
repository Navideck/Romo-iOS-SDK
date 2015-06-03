//
//  RMVideoInput.m
//  RomoAV
//

#import <CoreMedia/CoreMedia.h>
#import "RAVVideoInput.h"

#ifndef SIMULATOR
#import "AVCEncoder.h"
#endif

#define PROFILE     AVVideoProfileLevelH264Main41

#define FPS_LOW         10
#define BPS_LOW         300000

#define FPS_DEFAULT     16
#define BPS_DEFAULT     450000

#define FPS_HIGH        24
#define BPS_HIGH        600000

#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN(v)                 ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)

@interface RAVVideoInput () {
    AVCaptureSession            *_captureSession;
    AVCaptureDevice             *_captureDevice;
    AVCaptureDeviceInput        *_captureDeviceInput;
    AVCaptureVideoDataOutput    *_captureOutput;
    AVCaptureStillImageOutput   *_captureImageOutput;
    
#ifndef SIMULATOR
    AVCEncoder                  *_encoder;
#endif
}

@property (nonatomic, getter=isStarting) BOOL starting;
@property (nonatomic, copy) void (^startCompletion)(BOOL started);

// Initialization:
- (BOOL)initCapture;
- (BOOL)initEncoder;

// Camera Settings:
- (NSUInteger)cameraCount;
- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position;
- (void)setCameraFPS:(NSInteger)fps;

@end

@implementation RAVVideoInput

+ (RAVVideoInput *)input
{
    __strong static RAVVideoInput *shared = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[RAVVideoInput alloc] init];
    });
    
    return shared;
}

- (id)init
{
    if (self = [super init]) {
        if (![self initCapture]) {
            return nil;
        }
    }
    
    return self;
}

- (void)dealloc
{
    if (_running) {
        [self stop];
    }
    
    [_captureOutput setSampleBufferDelegate:nil queue:NULL];
    
    _captureSession = nil;
    _captureDevice = nil;
    _captureDeviceInput = nil;
    
#ifndef SIMULATOR
    _encoder = nil;
#endif
    
    _inputBlock = nil;
}

- (BOOL)initCapture
{
    self.starting = YES;
    _captureSession = [[AVCaptureSession alloc] init];
    [_captureSession beginConfiguration];
    [_captureSession setSessionPreset:AVCaptureSessionPresetMedium];
    
    
    AVCaptureDevice *videoDevice = nil;
    if ([self cameraCount] > 1) {
        videoDevice = [self cameraWithPosition:AVCaptureDevicePositionFront];
    } else {
        videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }
    
    if (!videoDevice) {
        return NO;
    }
    
    _captureDevice = videoDevice;
    
    // Add the device to the session.
    NSError *error;
    _captureDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
    if (error) {
        return NO;
    }
    
    [_captureSession addInput:_captureDeviceInput];
    
    // Create the output for the capture session.
    _captureOutput = [[AVCaptureVideoDataOutput alloc] init];
    _captureOutput.alwaysDiscardsLateVideoFrames = YES;
    _captureOutput.videoSettings = @{ (id) kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) };
    [_captureOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    
    _captureImageOutput = [[AVCaptureStillImageOutput alloc] init];
    
    [_captureSession addOutput:_captureOutput];
    [_captureSession addOutput:_captureImageOutput];
    
    [self setCameraFPS:FPS_DEFAULT];
    
    [_captureSession commitConfiguration];
    
    _running = NO;
    self.starting = NO;
    
    if (self.startCompletion) {
        self.startCompletion(YES);
        self.startCompletion = nil;
    }
    
    return YES;
}

- (BOOL)initEncoder
{
    
#ifndef SIMULATOR
    _encoder = [[AVCEncoder alloc] init];
    
    __weak VideoInputBlock inputBlock = self.inputBlock;
    AVCEncoderCallback callback = ^(const void *frame, uint32_t length, CMTime pts) {
        @autoreleasepool {
            if (inputBlock) {
                inputBlock(frame, length, pts);
            }
        }
    };
    
    [_encoder setCallback:[callback copy]];
    
    AVCParameters *parameters = [[AVCParameters alloc] init];
    [parameters setVideoProfileLevel:PROFILE];
    [parameters setBps:BPS_LOW];
    
    [_encoder setParameters:parameters];
    BOOL prepareSucceeded = [_encoder prepareEncoder];
    
    if (prepareSucceeded) {
        return [_encoder start];
    } else {
        DDLogError(@"prepareEncoder failed: %@", _encoder.error);
        return NO;
    }
#endif
    
    return NO;
}

#pragma mark - Methods

- (void)start
{
    [self performSelectorInBackground:@selector(_start) withObject:nil];
}

- (void)_start
{
    __weak id<RMVideoInputDelegate> delegate = _inputDelegate;
    self.inputBlock = ^(const void *frame, uint32_t length, CMTime pts) {
        [delegate capturedFrame:frame length:length pts:pts];
    };
    
    if (![self initEncoder]) {
#ifndef SIMULATOR
        DDLogError(@"Start encoder failed: %@", _encoder.error);
#endif
        return;
    }
    
    [_captureSession startRunning];
    _running = YES;
}

- (void)stop
{
    void (^stop)(BOOL started) = ^(BOOL started){
        [_captureSession stopRunning];
#ifndef SIMULATOR
        [_encoder performSelectorInBackground:@selector(stop) withObject:nil];
#endif
        _running = NO;
    };
    
    if (self.isStarting) {
        self.startCompletion = stop;
    } else {
        stop(YES);
    }
}

- (void)captureStillImage
{
    if (![_captureSession isRunning]) {
        [_captureSession startRunning];
    }
    
    AVCaptureConnection *videoConnection = nil;
    for (AVCaptureConnection *connection in _captureImageOutput.connections) {
        for (AVCaptureInputPort *port in [connection inputPorts]) {
            if ([[port mediaType] isEqual:AVMediaTypeVideo]) {
                videoConnection = connection;
                break;
            }
        }
        if (videoConnection) {
            break;
        }
    }
    
    UIDeviceOrientation curDeviceOrientation = [[UIDevice currentDevice] orientation];
    [videoConnection setVideoOrientation:(AVCaptureVideoOrientation)curDeviceOrientation];
	[videoConnection setVideoScaleAndCropFactor:1.0];
    
    [_captureImageOutput setOutputSettings:[NSDictionary dictionaryWithObject:AVVideoCodecJPEG
                                                                       forKey:AVVideoCodecKey]];
    [_captureImageOutput captureStillImageAsynchronouslyFromConnection:videoConnection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        if (!error) {
            NSData *jpegData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
            [_imageCapturingDelegate didFinishCapturingStillImage:[UIImage imageWithData:jpegData]];
        }
    }];
}

#pragma mark - Private

- (NSUInteger)cameraCount
{
    return [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo].count;
}

- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    
    for (AVCaptureDevice *device in devices) {
        if ([device position] == position) {
            return device;
        }
    }
    
    return nil;
}

#pragma mark - AVCaptureSession Delegate Methods --

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
	   fromConnection:(AVCaptureConnection *)connection
{
#ifndef SIMULATOR
    [_encoder encode:sampleBuffer];
#endif
}

- (void)setVideoQuality:(RMVideoQuality)videoQuality
{
    _videoQuality = videoQuality;
    
#ifndef SIMULATOR
    switch (videoQuality) {
        case RMVideoQualityLow:
            [_encoder setAveragebps:BPS_LOW];
            [self setCameraFPS:FPS_LOW];
            break;
            
        case RMVideoQualityDefault:
            [_encoder setAveragebps:BPS_DEFAULT];
            [self setCameraFPS:FPS_DEFAULT];
            break;
            
        case RMVideoQualityHigh:
            [_encoder setAveragebps:BPS_HIGH];
            [self setCameraFPS:FPS_HIGH];
            break;
    }
#endif
}

- (void)setCameraFPS:(NSInteger)fps
{
    CMTime duration = CMTimeMake(1, fps);
    
    // iOS 6.0 supports video min/max frame duration for capture connections
    if (SYSTEM_VERSION_LESS_THAN(@"7.0")) {
        for (AVCaptureConnection *connection in _captureOutput.connections) {
            if (connection.supportsVideoMinFrameDuration) {
                connection.videoMinFrameDuration = duration;
            }
            if (connection.supportsVideoMaxFrameDuration) {
                connection.videoMaxFrameDuration = duration;
            }
        }
    }
    
    // iOS 7.0 uses activeVideoMin/MaxFrameDuration on the capture device
    if ([_captureDevice respondsToSelector:@selector(setActiveVideoMinFrameDuration:)] && [_captureDevice respondsToSelector:@selector(setActiveVideoMaxFrameDuration:)]) {
        [_captureDevice lockForConfiguration:nil];
        _captureDevice.activeVideoMinFrameDuration = CMTimeMake(1, fps);
        _captureDevice.activeVideoMaxFrameDuration = CMTimeMake(1, fps);
        [_captureDevice unlockForConfiguration];
    }
}

@end

