//
//  RMFakeVision.m
//  RMVision
//
//  Created on 8/18/13.
//  Copyright (c) 2013 Romotive, Inc. All rights reserved.
//

#import "RMFakeVision.h"
#import "RMVision_Internal.h"
#import "RMVisionModule.h"
#import "RMVisionDebugBroker.h"
#import <AVFoundation/AVFoundation.h>

@interface RMFakeVision ()

@property (nonatomic, strong) AVAssetReaderTrackOutput *output;
@property (nonatomic, strong) AVPlayerItem *playerItem;
@property (nonatomic, strong) AVAssetReader *frameSrc;
@property (nonatomic, readonly) BOOL realtime;
@property (nonatomic) BOOL captureStarted;
@property (nonatomic) AVCaptureVideoOrientation vidOrientation;
@property (nonatomic) UIInterfaceOrientation assetOrientation;
@property (nonatomic) dispatch_time_t frameTimeNSec;
@property (nonatomic) dispatch_source_t frameTimer;
@property (nonatomic) dispatch_queue_t visionQueue;
@property (nonatomic) CFTimeInterval lastFrameTime;

@property (nonatomic) CGAffineTransform preferredTransform;

// Benchmarking
@property (nonatomic) int totalNumberOfSkippedFrames;

@end

@implementation RMFakeVision

// going to need to modify these
@synthesize width=_width, height=_height;

#pragma mark - Initialization

// Initialize with URL for pre-recorded video
//------------------------------------------------------------------------------
- (id)initWithFileURL:(NSURL *)vid
{
    return [self initWithFileURL:vid inRealtime:YES];
}

- (id)initWithFileURL:(NSURL *)vid inRealtime:(BOOL)realtime
{
    _realtime = realtime;
    if (vid == nil) {
        return nil;
    }
    
    // so, ummm, this should work. super will assign a camera and quality, but
    // they will never be used
    self = [super init];
    
    if (self) {
        self.totalNumberOfSkippedFrames = 0;
        
        // create the asset to represent the video file
        AVAsset *vidAsset = [AVAsset assetWithURL:vid];
        NSArray *vidTracks = [vidAsset tracksWithMediaType:AVMediaTypeVideo];
        if (vidTracks.count < 1) {
            return nil;
        }
        NSError *err;
        _frameSrc = [AVAssetReader assetReaderWithAsset:vidAsset error:&err];
        if (err) {
            NSLog(@"AVAssetReader failed: %@", err);
            return nil;
        }
        
        // we will also have an AVPlayer to be able to display the video being
        // processed in "romo vision"
        _playerItem = [AVPlayerItem playerItemWithAsset:vidAsset];
        
        // get the video track
        // TODO: look at choosing pixel format, video size, check for errors
        AVAssetTrack *vidTrack = [vidTracks objectAtIndex:0];
        CGSize vidSize = vidTrack.naturalSize;
        self.preferredTransform = vidTrack.preferredTransform;
        
        // TODO see if this is the most sensible default
        _assetOrientation = [[self class] orientationForTrack:vidAsset];
        
        _vidOrientation = AVCaptureVideoOrientationPortrait;
        
        
        // This calculation of the vidOrientation only works if the input video is in the default LandscapeLeft mode.
        // I'm commenting it out since we might want to refer these transforms in the future - Andrew
        
//        // figure out if the video is rotated (idevices save videos as landscape
//        // with an appropriate rotation)
//        bool(^transformEquals)(int, int, int, int) = ^(int a, int b,
//                                                       int c, int d) {
//            CGAffineTransform t = vidTrack.preferredTransform;
//            return (t.a == a && t.b == b && t.c == c && t.d == d);
//        };
//        if (transformEquals(0, -1, 1, 0)) {
//            _vidOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
//        } else if (transformEquals(-1, 0, 0, -1)) {
//            _vidOrientation = AVCaptureVideoOrientationLandscapeRight;
//        } else if (transformEquals(1, 0, 0, 1)) {
//            _vidOrientation = AVCaptureVideoOrientationLandscapeLeft;
//        }
        // Right/left is the side the home button is on when holding the camera
        // "outwards", ie the video recorded is what you would see looking
        // "through" the device
        
        if (_vidOrientation != AVCaptureVideoOrientationPortrait) {
            // TODO for now, we don't handle anything except for videos shot in
            // protrait mode with an idevice.
            NSLog(@"Video orientation not currently supported");
            return nil;
        }
        
        _captureStarted = NO;
        
        //        // if it's portrait, we need to swap height and width
        //        if (_vidOrientation == AVCaptureVideoOrientationPortrait
        //            || _vidOrientation == AVCaptureVideoOrientationPortraitUpsideDown) {
        //            _width = vidSize.height;
        //            _height = vidSize.width;
        //        } else {
        _width = vidSize.width;
        _height = vidSize.height;
        //        }
        
        // while we've got the track, record the framerate
        _frameTimeNSec = NSEC_PER_SEC / vidTrack.nominalFrameRate;
        
        // TODO figure out how to optionally get YUV here (just passing
        // kCVPixelFormatType_420YpCbCr8BiPlanarFullRange as value causes OpenCV
        // to choke on an assertion in modules/imgproc/src/color.cpp)
        NSDictionary *videoSettings = @{(NSString *)kCVPixelBufferPixelFormatTypeKey :
                                            [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA]};
        _output = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:vidTrack
                                                             outputSettings:videoSettings];
        _output.alwaysCopiesSampleData = NO;
        [_frameSrc addOutput:_output];
        
        // Update the broker with the info
        [RMVisionDebugBroker shared].width = _width;
        [RMVisionDebugBroker shared].height = _height;
        [RMVisionDebugBroker shared].core = self;
        
    }
    return self;
}

- (void)startCapture
{
    [self startCaptureWithCompletion:nil];
}

- (void)startCaptureWithCompletion:(void (^)(BOOL))completion
{
    // create the preview and add the layer to the debug vision
    AVPlayer *player = [AVPlayer playerWithPlayerItem:_playerItem];
    self.videoPreviewLayer = [AVPlayerLayer playerLayerWithPlayer:player];
    
    [_frameSrc startReading];
    
    // XXX check all this dispatch queue stuff
    _visionQueue = dispatch_queue_create("com.romotive.fakevision",
                                         NULL);
    _frameTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,
                                         _visionQueue);
    // we don't want to start the timer until we've got any modules running
    if (self.activeModules.count > 0) {
        [self resumeStreamingAtTime:DISPATCH_TIME_NOW];
    } else {
        [self resumeStreamingAtTime:DISPATCH_TIME_FOREVER];
    }
    
    __weak RMFakeVision *weakSelf = self;
    dispatch_source_set_event_handler(_frameTimer, ^{
        
        BOOL hasNextFrame = [weakSelf nextFrame];
        
        if (!hasNextFrame) {
            [weakSelf stopCapture];
        }
        
    });
    dispatch_resume(_frameTimer);
    // signalling to -nextFrame that it will be processing the first frame
    _lastFrameTime = 0;
    
    _captureStarted = YES;
    
    dispatch_async(dispatch_get_main_queue(), ^(void){
        [[RMVisionDebugBroker shared] visionStarted];
    });
    
    // finally run the completion
    if (completion) {
        completion(YES);
    }
}

- (BOOL)nextFrame
{
    BOOL hasNextFrame = NO;
    
    if (_frameSrc.status == AVAssetReaderStatusReading) {
        int skippedFrames = 0;
        if (_realtime) {
            CFTimeInterval now = CACurrentMediaTime();
            if (_lastFrameTime == 0) {
                // first frame, so there is no need to drop it
                _lastFrameTime = now;
            }
            
            float frameTimeSec = float(_frameTimeNSec) / float(NSEC_PER_SEC);
            skippedFrames = MAX(0,int((now - _lastFrameTime) / frameTimeSec) - 1);
            self.totalNumberOfSkippedFrames += skippedFrames;
            
            _lastFrameTime = now;
        }
        
        CMSampleBufferRef buff = [_output copyNextSampleBuffer];
        // _skippedFrames will always be 0 if !_realtime
        for (int i = 0; i < skippedFrames && buff; i++) {
            // TODO is there a faster way to skip through frames?
            CFRelease(buff);
            buff = [_output copyNextSampleBuffer];
        }
        
        
        if (buff) {
            hasNextFrame = YES;
            
            [self process:buff];
            CFRelease(buff);
        } else {
            hasNextFrame = NO;
        }
        [_playerItem stepByCount:1 + skippedFrames];
    }
    
    return hasNextFrame;
}

// This selector mostly cribbed from RMVision
//------------------------------------------------------------------------------
- (void)process:(CMSampleBufferRef)sampleBuffer
{
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    OSType format = CVPixelBufferGetPixelFormatType(pixelBuffer);
    CGRect videoRect = CGRectMake(0.0f, 0.0f,
                                  CVPixelBufferGetWidth(pixelBuffer),
                                  CVPixelBufferGetHeight(pixelBuffer));
    
    NSSet *modules = self.activeModules;
    
    if (format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
        // For grayscale mode, the luminance channel of the YUV data is used
        CVPixelBufferLockBaseAddress(pixelBuffer, 0);
        void *baseaddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
        
        cv::Mat mat(videoRect.size.height, videoRect.size.width, CV_8UC1,
                    baseaddress, 0);
        
        
        if (self.preferredTransform.c == -1) {
            mat = mat.t();
            CGFloat tmp = videoRect.size.height;
            videoRect.size.height = videoRect.size.width;
            videoRect.size.width = tmp;
        }
        
        if (self.camera == RMCamera_Back) {
            cv::flip(mat, mat, 1);
        }
        
        [self processFrame:mat
                 videoRect:videoRect
          videoOrientation:self.vidOrientation
                   modules:modules];
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    } else if (format == kCVPixelFormatType_32BGRA) {
        // For color mode a 4-channel cv::Mat is created from the BGRA data
        CVPixelBufferLockBaseAddress(pixelBuffer, 0);
        void *baseaddress = CVPixelBufferGetBaseAddress(pixelBuffer);
        
        cv::Mat mat(videoRect.size.height, videoRect.size.width, CV_8UC4,
                    baseaddress, 0);
        
        if (self.preferredTransform.c == -1) {
            mat = mat.t();
            CGFloat tmp = videoRect.size.height;
            videoRect.size.height = videoRect.size.width;
            videoRect.size.width = tmp;
        }
        
        if (self.camera == RMCamera_Back) {
            cv::flip(mat, mat, 1);
        }
        
        [self processFrame:mat
                 videoRect:videoRect
          videoOrientation:self.vidOrientation
                   modules:modules];
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    } else {
        NSLog(@"Unsupported video format");
    }
}

- (void)stopCapture
{
    [self stopCaptureWithCompletion:nil];
}

- (void)stopCaptureWithCompletion:(void (^)(BOOL))completion
{
    _captureStarted = NO;
    
    // clean up all the dispatch queue stuff
    [RMVisionDebugBroker shared].running = NO;
    dispatch_source_cancel(_frameTimer);
    NSLog(@"video done");
    NSLog(@"frames skipped: %d", self.totalNumberOfSkippedFrames);
    
    if (self.videoPreviewLayer) {
        [self.videoPreviewLayer removeFromSuperlayer];
        self.videoPreviewLayer = nil;
    }
    
    [self resumeStreamingAtTime:DISPATCH_TIME_FOREVER];
    
    if (completion) {
        completion(YES);
    }
}

- (BOOL)isRunning
{
    return _captureStarted;
}

- (BOOL)activateModuleWithName:(NSString *)moduleName
{
    int prevCount = self.activeModules.count;
    BOOL retVal = [super activateModuleWithName:moduleName];
    if (_captureStarted && prevCount == 0 && self.activeModules.count > 0) {
        // we'd better start things up
        [self resumeStreamingAtTime:DISPATCH_TIME_NOW];
    }
    return retVal;
}

- (BOOL)deactivateModuleWithName:(NSString *)moduleName
{
    BOOL retVal = [super deactivateModuleWithName:moduleName];
    if (_captureStarted && self.activeModules.count == 0) {
        [self resumeStreamingAtTime:DISPATCH_TIME_NOW];
    }
    return retVal;
}

- (void)resumeStreamingAtTime:(dispatch_time_t)when
{
    // process frames at the "natural" framerate, +/- 1ms per frame
    dispatch_source_set_timer(_frameTimer,
                              dispatch_time(when, 0),
                              (_realtime ? _frameTimeNSec : 0),
                              NSEC_PER_MSEC);
}

- (void)setCamera:(RMCamera)camera
{
    // override and do nothing
}

- (void)setQuality:(RMCameraQuality)quality
{
    // override and do nothing
}

+ (UIInterfaceOrientation)orientationForTrack:(AVAsset *)asset
{
    AVAssetTrack *videoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    CGSize size = [videoTrack naturalSize];
    CGAffineTransform txf = [videoTrack preferredTransform];
    
    if (size.width == txf.tx && size.height == txf.ty)
        return UIInterfaceOrientationLandscapeRight;
    else if (txf.tx == 0 && txf.ty == 0)
        return UIInterfaceOrientationLandscapeLeft;
    else if (txf.tx == 0 && txf.ty == size.width)
        return UIInterfaceOrientationPortraitUpsideDown;
    else
        return UIInterfaceOrientationPortrait;
}
@end
