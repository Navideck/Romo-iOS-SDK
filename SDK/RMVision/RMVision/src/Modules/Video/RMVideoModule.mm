//
//  RMVideoModule.m
//  RMVision
//
//  Created on 6/24/13.
//  Copyright (c) 2013 Romotive, Inc. All rights reserved.
//

#import "RMVideoModule.h"

#ifdef DEBUG_VIDEO_MODULE
#define LOG(...) DDLogWarn(__VA_ARGS__)
#else
#define LOG(...)
#endif //DEBUG_VIDEO_MODULE

// Constants
//==============================================================================
static const int kAVNumberOfChannels = 1;
static const float kAVSampleRate = 44100.0;
static const int kAVEncoderBitRate = 64000;


//==============================================================================
@interface RMVideoModule ()

@property (nonatomic, strong) NSString *videoPath;

@property (nonatomic, strong) AVAssetWriter *assetWriter;
@property (nonatomic, strong) AVAssetWriterInput *videoWriterInput;
@property (nonatomic, strong) AVAssetWriterInput *audioWriterInput;
@property (nonatomic, readwrite) AVCaptureVideoOrientation videoOrientation;

@property (nonatomic) CMTime lastTimestamp;

@property (nonatomic, strong) NSArray *poppedModules;

/** Once we're finished recording, we start writing and block out new start-record calls */
@property (atomic, getter=isWritingVideo) BOOL writingVideo;

/** If a start call is queued while we're writing, start it now */
@property (atomic, getter=isPendingStart) BOOL pendingStart;

@property (nonatomic, copy) void (^shutdownCompletionBlock)(void);

@end

//==============================================================================
@implementation RMVideoModule

#pragma mark - Initialization / Teardown
//------------------------------------------------------------------------------
- (id)initWithVision:(RMVision *)core
{
    // Get a file path and make sure there's nothing there
    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *path = [[documentsDirectory stringByAppendingPathComponent:@"RomoVideo"] stringByAppendingString:@".mp4"];
    
    self = [self initWithVision:core recordToPath:path];
    
    if (self) {
        // Default to saving to the photo album
        _shouldSaveToPhotoAlbum = YES;
    }
    return self;
}

//------------------------------------------------------------------------------
- (id)initWithVision:(RMVision *)core recordToPath:(NSString *)path
{
    self = [super initModule:RMVisionModule_TakeVideo
                  withVision:core];
    
    if (self) {
        _recording = NO;
        NSError* error = nil;

        // Initialize the video writer input
        NSDictionary *outputSettings = @{AVVideoWidthKey    : [NSNumber numberWithInt:core.width],
                                         AVVideoHeightKey   : [NSNumber numberWithInt:core.height],
                                         AVVideoCodecKey    : AVVideoCodecH264};
        
        _videoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                               outputSettings:outputSettings];
        _videoWriterInput.transform = [self transformFromCurrentVideoOrientationToOrientation:AVCaptureVideoOrientationPortrait];
        _videoWriterInput.expectsMediaDataInRealTime = YES;
        _videoWriterInput.mediaTimeScale = self.vision.targetFrameRate;
        
        // If we want to record audio, initialize the audio writer input (AAC Mono)
        if (self.vision.isAudioEnabled) {
            AudioChannelLayout acl;
            bzero(&acl, sizeof(acl));
            acl.mChannelLayoutTag = kAudioChannelLayoutTag_Mono;
            
            NSDictionary *audioOutputSettings = @{AVFormatIDKey         : [NSNumber numberWithInt:kAudioFormatMPEG4AAC],
                                                  AVNumberOfChannelsKey : [NSNumber numberWithInt:kAVNumberOfChannels],
                                                  AVSampleRateKey       : [NSNumber numberWithFloat:kAVSampleRate],
                                                  AVChannelLayoutKey    : [NSData dataWithBytes:&acl length:sizeof(AudioChannelLayout)],
                                                  AVEncoderBitRateKey   : [NSNumber numberWithInt:kAVEncoderBitRate]};
            
            self.audioWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio
                                                                       outputSettings:audioOutputSettings];
            self.audioWriterInput.expectsMediaDataInRealTime = YES;
        }
        
        _videoPath = path;
        if ([[NSFileManager defaultManager] fileExistsAtPath:_videoPath]) {
            [[NSFileManager defaultManager] removeItemAtPath:_videoPath error:&error];
        }
        if (error) {
            LOG(@"RMVision: ERROR initializing file - could not delete %@", _videoPath);
        }
        
        // Create the asset writer
        [self _createAssetWriter];
        
        // Notify self of backgrounding so we can clean up any recording videos
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidEnterBackground)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
    }
    return self;
}

//------------------------------------------------------------------------------
- (void)shutdown
{
    if (self.recording) {
        self.pendingStart = NO;
        [self _endRecording];
    }
    
    // Don't call this because we want to keep a reference to core
//    [super shutdown];
}

- (void)shutdownWithCompletion:(void(^)(void))callback
{
    self.shutdownCompletionBlock = callback;
    [self shutdown];
}

//------------------------------------------------------------------------------
- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

//------------------------------------------------------------------------------
- (void)applicationDidEnterBackground
{
    if (self.recording) {
        self.pendingStart = NO;
        [self _endRecording];
    }
}

#pragma mark - Processing / Buffering
//------------------------------------------------------------------------------
- (void)processFrame:(const cv::Mat)mat
          videoRect:(CGRect)rect
   videoOrientation:(AVCaptureVideoOrientation)videoOrientation
{
    self.videoOrientation = videoOrientation;

    // If we haven't started, fire it up
    if (!self.recording) {
        if (!self.isWritingVideo) {
            // If we're not in the middle of shutting down, start now...
            [self _startRecording];
        } else {
            // ...Otherwise, flag ourselves as queued and we'll start once we're done shutting down
            self.pendingStart = YES;
        }
    }
}

//------------------------------------------------------------------------------
- (void)addVideoSampleBuffer:(CMSampleBufferRef)imageBuffer
               withTimestamp:(CMTime)timestamp
             withOrientation:(AVCaptureVideoOrientation)videoOrientation
{
    self.lastTimestamp = timestamp;
    
    if (self.assetWriter.status != AVAssetWriterStatusWriting) {
        [self.assetWriter startWriting];
        [self.assetWriter startSessionAtSourceTime:timestamp];
        if (self.assetWriter.status != AVAssetWriterStatusWriting) {
            LOG(@"RMVision: Recording Error - asset writer status is not writing: %@", self.assetWriter.error);
            return;
        } else {
            LOG(@"RMVision: Video recording started");
        }
    }
    
    if ([self.videoWriterInput isReadyForMoreMediaData]) {
        [self.videoWriterInput appendSampleBuffer:imageBuffer];
    }
}

//------------------------------------------------------------------------------
- (void)addAudioSampleBuffer:(CMSampleBufferRef)buffer
               withTimestamp:(CMTime)timestamp
{
    if ([self.audioWriterInput isReadyForMoreMediaData]) {
        [self.audioWriterInput appendSampleBuffer:buffer];
    }
}

#pragma mark - Start / stop helpers
//------------------------------------------------------------------------------
- (void)_startRecording
{
    if (!self.writingVideo) {
        if (!self.assetWriter) {
            [self _createAssetWriter];
        }
        self.recording = YES;
    }
}

//------------------------------------------------------------------------------
- (void)_createAssetWriter
{
    // Create the asset writer to write to self.videoPath
    NSURL *outputURL = [NSURL fileURLWithPath:_videoPath];
    
    _assetWriter = [[AVAssetWriter alloc] initWithURL:outputURL
                                             fileType:AVFileTypeMPEG4
                                                error:nil];
    [_assetWriter addInput:_videoWriterInput];
    
    if (self.vision.isAudioEnabled) {
        [_assetWriter addInput:_audioWriterInput];
    }
}

//------------------------------------------------------------------------------
- (void)_endRecording
{
    self.recording = NO;

    // Save to file
    if (self.assetWriter.status == AVAssetWriterStatusWriting) {
        self.writingVideo = YES;
        [self.assetWriter endSessionAtSourceTime:self.lastTimestamp];
        [self.assetWriter finishWritingWithCompletionHandler:^{
            [self _cleanupAssetWriter];
            
            if (self.shutdownCompletionBlock ) {
                self.shutdownCompletionBlock();
                self.shutdownCompletionBlock = nil;
            }
            
        }];
    }
}

//------------------------------------------------------------------------------
- (void)_cleanupAssetWriter
{
    self.assetWriter = nil;
    if (self.shouldSaveToPhotoAlbum) {
        UISaveVideoAtPathToSavedPhotosAlbum(self.videoPath, self, @selector(video:didFinishSavingWithError:contextInfo:), nil);
    }
}

//------------------------------------------------------------------------------
- (void)           video:(NSString *)videoPath
didFinishSavingWithError:(NSError *)error
             contextInfo:(void *)contextInfo
{
    if (error) {
        LOG(@"RMVision: Video writing failed with error:%@",error);
    } else {
        LOG(@"RMVision: Video recording finished");
    }
    
    [[NSFileManager defaultManager] removeItemAtPath:videoPath error:nil];
    
    self.writingVideo = NO;

    // If we should start once finished, trigger that now
    if (self.isPendingStart) {
        self.pendingStart = NO;
        [self _startRecording];
    }
}

#pragma mark - Transformation Helpers
//------------------------------------------------------------------------------
- (CGFloat)angleOffsetFromPortraitOrientationToOrientation:(AVCaptureVideoOrientation)orientation

{
    CGFloat angle = 0.0;
    
    switch (orientation) {
        case AVCaptureVideoOrientationPortrait:
            angle = 0.0;
            break;
            
        case AVCaptureVideoOrientationPortraitUpsideDown:
            angle = M_PI;
            break;
            
        case AVCaptureVideoOrientationLandscapeRight:
            angle = -M_PI_2;
            break;
            
        case AVCaptureVideoOrientationLandscapeLeft:
            angle = M_PI_2;
            break;
            
        default:
            break;
    }
    
    return angle;
}

//------------------------------------------------------------------------------
- (CGAffineTransform)transformFromCurrentVideoOrientationToOrientation:(AVCaptureVideoOrientation)orientation
{
    CGAffineTransform transform = CGAffineTransformIdentity;
    
    // Calculate offsets from an arbitrary reference orientation (portrait)
    CGFloat orientationAngleOffset = [self angleOffsetFromPortraitOrientationToOrientation:orientation];
    CGFloat videoOrientationAngleOffset = [self angleOffsetFromPortraitOrientationToOrientation:self.videoOrientation];
    
    // Find the difference in angle between the passed in orientation and the current video orientation
    CGFloat angleOffset = orientationAngleOffset - videoOrientationAngleOffset;
    transform = CGAffineTransformMakeRotation(angleOffset);
    
    return transform;
}

@end
