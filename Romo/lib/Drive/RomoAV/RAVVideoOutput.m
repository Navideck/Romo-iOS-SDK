//
//  RAVVideoOutput.m
//  RomoAV
//

#import "RAVVideoOutput.h"

#import <VideoToolbox/VideoToolbox.h>

#import "RGLBufferVC.h"

#define MAX_BACKLOGGED_FRAMES 10

@interface RAVVideoOutput ()
{
    RGLBufferVC  *_videoOutputViewController;

    NSData *_videoPacket;

    uint8_t *_sps;
    NSInteger _spsSize;
    uint8_t *_pps;
    NSInteger _ppsSize;

    //    VTDecompressionSessionRef _decoderSession;
    CMVideoFormatDescriptionRef _decoderFormatDescription;
}

@end

@implementation RAVVideoOutput

- (id)init
{
    self = [super init];
    if (self) {

        CGRect frame = [UIScreen mainScreen].bounds;

        self.peerView = [self prepareOutputViewWithFrame:frame];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillResignActive:)
                                                     name:UIApplicationWillResignActiveNotification
                                                   object:nil];


        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidBecomeActive:)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];

    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)applicationWillResignActive:(id)notification
{
    //    _isVideoFrameQueueActive = NO;
    //    dispatch_sync(_frameRenderQueue, ^{
    //        dispatch_suspend(_frameRenderQueue);
    //    });
}

- (void)applicationDidBecomeActive:(id)notification
{
    //    _isVideoFrameQueueActive = YES;
    //    if (_frameRenderQueue) {
    //        dispatch_resume(_frameRenderQueue);
    //    }
}

- (void)stop
{
    //    // The queue needs to be running to call dispatch_sync and dispatch_release.
    //    // So if the render queue is suspended, let's resume it before continuing.
    //    if (!_isVideoFrameQueueActive) {
    //        dispatch_resume(_frameRenderQueue);
    //    }
    //
    //    _isVideoFrameQueueActive = NO;
    //
    //    // Note: This is ghetto as fuck...
    //    // Bascially, we need to make sure the queues are empty before releasing them
    //    // These nested sync calls ensure that the currently executing blocks will
    //    // finish before we try to release the queues
    //    dispatch_sync(_frameRenderQueue, ^{
    //        dispatch_sync(_frameDecodeQueue, ^{
    //
    //        });
    //    });

    _videoOutputViewController = nil;

    //#ifndef SIMULATOR
    //    _codec = nil;
    //
    //    if (_codecCtx) {
    //        av_free(_codecCtx);
    //    }
    //
    //    if (_sourceFrame) {
    //        av_free(_sourceFrame);
    //    }
    //
    //    if (_destinationFrame) {
    //        av_free(_destinationFrame);
    //    }
    //
    //    if (_outputBuffer) {
    //        free(_outputBuffer);
    //    }
    //
    //    if (_convertCtx) {
    //        sws_freeContext(_convertCtx);
    //    }
    //#endif
}

- (UIView *)prepareOutputViewWithFrame:(CGRect)frame
{
    if (!_videoOutputViewController) {
        _videoOutputViewController = [[RGLBufferVC alloc] initWithFrame:frame];
    }

    return _videoOutputViewController.view;
}

const uint8_t KStartCode[4] = {0, 0, 0, 1};

- (NSData*) getPacket:(uint8_t *)buffer length:(NSUInteger)length
{
    if(memcmp(buffer, KStartCode, 4) != 0) {
        return nil;
    }

    if(length >= 5) {
        uint8_t *bufferBegin = buffer + 3;
        uint8_t *bufferEnd = buffer + length;
        while(bufferBegin != bufferEnd) {
            if(*bufferBegin == 0x01) {
                if(memcmp(bufferBegin - 3, KStartCode, 4) == 0) {
                    NSData *videoPacket = [NSData dataWithBytes:buffer length:length];

                    return videoPacket;
                }
            }
            ++bufferBegin;
        }
    }

    return nil;
}

-(BOOL)initH264Decoder {
    const uint8_t* const parameterSetPointers[2] = { _sps, _pps };
    const size_t parameterSetSizes[2] = { _spsSize, _ppsSize };
    CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault,
                                                                          2, //param count
                                                                          parameterSetPointers,
                                                                          parameterSetSizes,
                                                                          4, //nal start code size
                                                                          &_decoderFormatDescription);

    return YES;
}

- (CVPixelBufferRef) decode:(NSData*) videoPacket {
    CVPixelBufferRef outputPixelBuffer = NULL;

    CMBlockBufferRef blockBuffer = NULL;
    OSStatus status  = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault,
                                                          (void*)videoPacket.bytes, videoPacket.length,
                                                          kCFAllocatorNull,
                                                          NULL, 0, videoPacket.length,
                                                          0, &blockBuffer);

    if(status == kCMBlockBufferNoErr) {
        CMSampleBufferRef sampleBuffer = NULL;
        const size_t sampleSizeArray[] = {videoPacket.length};
        status = CMSampleBufferCreateReady(kCFAllocatorDefault,
                                           blockBuffer,
                                           _decoderFormatDescription,
                                           1, 0, NULL, 1, sampleSizeArray,
                                           &sampleBuffer);

        if (status == kCMBlockBufferNoErr && sampleBuffer) {

            [_videoOutputViewController playSampleBuffer:sampleBuffer];

            CFRelease(sampleBuffer);
        }
        CFRelease(blockBuffer);
    }

    return outputPixelBuffer;
}

- (void) playVideoFrame:(void *)frame length:(NSUInteger)length
{
    NSData *videoPacket = [self getPacket:frame length:length];
    if(videoPacket == nil) {
        return;
    }

    uint32_t nalSize = (uint32_t)(videoPacket.length - 4);
    uint8_t *pNalSize = (uint8_t*)(&nalSize);
    ((uint8_t*)videoPacket.bytes)[0] = *(pNalSize + 3);
    ((uint8_t*)videoPacket.bytes)[1] = *(pNalSize + 2);
    ((uint8_t*)videoPacket.bytes)[2] = *(pNalSize + 1);
    ((uint8_t*)videoPacket.bytes)[3] = *(pNalSize);

    CVPixelBufferRef pixelBuffer = NULL;
    int nalType = ((uint8_t*)videoPacket.bytes)[4] & 0x1F;
    switch (nalType) {
        case 0x05:
            if([self initH264Decoder]) {
                pixelBuffer = [self decode:videoPacket];
            }
            break;
        case 0x07:
            _spsSize = videoPacket.length - 4;
            _sps = malloc(_spsSize);
            memcpy(_sps, videoPacket.bytes + 4, _spsSize);
            break;
        case 0x08:
            _ppsSize = videoPacket.length - 4;
            _pps = malloc(_ppsSize);
            memcpy(_pps, videoPacket.bytes + 4, _ppsSize);
            break;

        default:
            pixelBuffer = [self decode:videoPacket];
            break;
    }

    if(pixelBuffer) {
        CVPixelBufferRelease(pixelBuffer);
    }
}

@end
