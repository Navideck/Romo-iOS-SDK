//
//  RMVideoInput.m
//  RomoAV
//

#import <CoreMedia/CoreMedia.h>
#import "RAVVideoInput.h"

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
    H264HwEncoderImpl           *_encoder;
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
- (void)setCameraFPS:(int32_t)fps;

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
    [_captureSession setSessionPreset:AVCaptureSessionPreset640x480];
    
    
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
    _encoder = [H264HwEncoderImpl alloc];
    [_encoder initWithConfiguration];
    
    [_encoder initEncodeWidth:480 height:640];
    [_encoder setDelegate:self];
    return YES;
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
        [self->_captureSession stopRunning];
#ifndef SIMULATOR
        [self->_encoder performSelectorInBackground:@selector(stop) withObject:nil];
#endif
        self->_running = NO;
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
            [self->_imageCapturingDelegate didFinishCapturingStillImage:[UIImage imageWithData:jpegData]];
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
    [connection setVideoOrientation:AVCaptureVideoOrientationPortrait];
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
//            [_encoder setAveragebps:BPS_LOW];
            [self setCameraFPS:FPS_LOW];
            break;
            
        case RMVideoQualityDefault:
//            [_encoder setAveragebps:BPS_DEFAULT];
            [self setCameraFPS:FPS_DEFAULT];
            break;
            
        case RMVideoQualityHigh:
//            [_encoder setAveragebps:BPS_HIGH];
            [self setCameraFPS:FPS_HIGH];
            break;
    }
#endif
}

- (void)setCameraFPS:(int32_t)fps
{
    CMTime duration = CMTimeMake(1, fps);
    
    for (AVCaptureConnection *connection in _captureOutput.connections) {
        if (connection.supportsVideoMinFrameDuration) {
            connection.videoMinFrameDuration = duration;
        }
        if (connection.supportsVideoMaxFrameDuration) {
            connection.videoMaxFrameDuration = duration;
        }
    }

    if (@available(iOS 7.0, *)) {
        [_captureDevice lockForConfiguration:nil];
        _captureDevice.activeVideoMinFrameDuration = CMTimeMake(1, fps);
        _captureDevice.activeVideoMaxFrameDuration = CMTimeMake(1, fps);
        [_captureDevice unlockForConfiguration];
    }
}

#pragma mark - H264HwEncoderImpl Delegate Methods --

- (void)gotSpsPps:(NSData*)sps pps:(NSData*)pps {
    [self sendData:sps];
    [self sendData:pps];
}

- (void)gotEncodedData:(NSData*)data isKeyFrame:(BOOL)isKeyFrame {
    if (isKeyFrame) {
        NSLog(@"KeyFrame %d", (int)[data length]);
    }
    
    [self sendData:data];
}

- (void)sendData:(NSData*)data {
    const char bytes[] = "\x00\x00\x00\x01";
    NSMutableData* dataWithHeader = [[NSData dataWithBytes:bytes length:(sizeof bytes) - 1] mutableCopy];
    [dataWithHeader appendData:data];
    [_inputDelegate capturedFrame:dataWithHeader.bytes length: (int)dataWithHeader.length];
}

@end

