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
    BOOL _searchForSPSAndPPS;
    
    NSData *_videoPacket;
    
    uint8_t *_sps;
    NSInteger _spsSize;
    uint8_t *_pps;
    NSInteger _ppsSize;
    
    NSData *_spsData;
    NSData *_ppsData;
    
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
        
        _searchForSPSAndPPS = YES;
        
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

- (NSData*) getPacket:(uint8_t *)buffer length:(uint32_t)length
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
    OSStatus status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault,
                                                                          2, //param count
                                                                          parameterSetPointers,
                                                                          parameterSetSizes,
                                                                          4, //nal start code size
                                                                          &_decoderFormatDescription);
    
    return YES;
}

static const NSString * naluTypesStrings[] = {
    @"Unspecified (non-VCL)",
    @"Coded slice of a non-IDR picture (VCL)",
    @"Coded slice data partition A (VCL)",
    @"Coded slice data partition B (VCL)",
    @"Coded slice data partition C (VCL)",
    @"Coded slice of an IDR picture (VCL)",
    @"Supplemental enhancement information (SEI) (non-VCL)",
    @"Sequence parameter set (non-VCL)",
    @"Picture parameter set (non-VCL)",
    @"Access unit delimiter (non-VCL)",
    @"End of sequence (non-VCL)",
    @"End of stream (non-VCL)",
    @"Filler data (non-VCL)",
    @"Sequence parameter set extension (non-VCL)",
    @"Prefix NAL unit (non-VCL)",
    @"Subset sequence parameter set (non-VCL)",
    @"Reserved (non-VCL)",
    @"Reserved (non-VCL)",
    @"Reserved (non-VCL)",
    @"Coded slice of an auxiliary coded picture without partitioning (non-VCL)",
    @"Coded slice extension (non-VCL)",
    @"Coded slice extension for depth view components (non-VCL)",
    @"Reserved (non-VCL)",
    @"Reserved (non-VCL)",
    @"Unspecified (non-VCL)",
    @"Unspecified (non-VCL)",
    @"Unspecified (non-VCL)",
    @"Unspecified (non-VCL)",
    @"Unspecified (non-VCL)",
    @"Unspecified (non-VCL)",
    @"Unspecified (non-VCL)",
    @"Unspecified (non-VCL)",
};

- (void) playVideoFrame:(uint8_t *)frame length:(uint32_t)frameSize {
    //
    // Credit for a lot of this code goes to Zappel on Stack Overflow:
    //  (http://stackoverflow.com/questions/25980070/how-to-use-avsamplebufferdisplaylayer-in-ios-8-for-rtp-h264-streams-with-gstream)
    //

    int startCodeIndex = 0;
    for (int i = 0; i < 4; i++)
    {
        startCodeIndex = i + 1;
        if (frame[i] == 0x01)
        {
            break;
        }
    }
    int nalu_type = ((uint8_t)frame[startCodeIndex] & 0x1F);
    NSLog(@"NALU with Type \"%@\" received.", naluTypesStrings[nalu_type]);

    while (nalu_type == 7 || nalu_type == 8)
    {
        int endCodeIndex;
        int numConsecutiveZeros = 0;
        for (endCodeIndex = startCodeIndex; endCodeIndex < frameSize; endCodeIndex++)
        {
            if (frame[endCodeIndex] == 0x01 && numConsecutiveZeros == 3)
            {
                endCodeIndex -= 3;
                break;
            }

            if (frame[endCodeIndex] == 0x00)
            {
                numConsecutiveZeros++;
            }
            else
            {
                numConsecutiveZeros = 0;
            }
        }

        if(_searchForSPSAndPPS)
        {
            if (nalu_type == 7)
            {
                _spsData = [NSData dataWithBytes:&(frame[startCodeIndex]) length: endCodeIndex - startCodeIndex];
            }
            else // if (nalu_type == 8)
            {
                _ppsData = [NSData dataWithBytes:&(frame[startCodeIndex]) length: endCodeIndex - startCodeIndex];
            }

            if (_spsData != nil && _ppsData != nil)
            {
                const uint8_t* const parameterSetPointers[2] = { (const uint8_t*)[_spsData bytes], (const uint8_t*)[_ppsData bytes] };
                const size_t parameterSetSizes[2] = { [_spsData length], [_ppsData length] };

                OSStatus status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault, 2, parameterSetPointers, parameterSetSizes, 4, &_decoderFormatDescription);
                _searchForSPSAndPPS = false;
                NSLog(@"Found all data for CMVideoFormatDescription. Creation: %@.", (status == noErr) ? @"successfully." : @"failed.");
            }
        }

        startCodeIndex = endCodeIndex + 4;
        nalu_type = ((uint8_t)frame[startCodeIndex] & 0x1F);
        NSLog(@"NALU with Type \"%@\" received.", naluTypesStrings[nalu_type]);
    }

    frame = &frame[startCodeIndex];
    frameSize -= startCodeIndex;

    if (nalu_type == 1 || nalu_type == 5)
    {
        CMBlockBufferRef videoBlock = NULL;
        OSStatus status = CMBlockBufferCreateWithMemoryBlock(NULL, &frame[-4], frameSize+4, kCFAllocatorNull, NULL, 0, frameSize+4, 0, &videoBlock);
        NSLog(@"BlockBufferCreation: %@", (status == kCMBlockBufferNoErr) ? @"successfully." : @"failed.");

        const uint8_t sourceBytes[] = {(uint8_t)(frameSize >> 24), (uint8_t)(frameSize >> 16), (uint8_t)(frameSize >> 8), (uint8_t)frameSize};
        status = CMBlockBufferReplaceDataBytes(sourceBytes, videoBlock, 0, 4);
        NSLog(@"BlockBufferReplace: %@", (status == kCMBlockBufferNoErr) ? @"successfully." : @"failed.");

        CMSampleBufferRef sampleBuffer = NULL;
        const size_t sampleSizeArray[] = {frameSize};

        status = CMSampleBufferCreateReady(kCFAllocatorDefault,
                                           videoBlock,
                                           _decoderFormatDescription,
                                           1, 0, NULL, 1, sampleSizeArray,
                                           &sampleBuffer);
        NSLog(@"SampleBufferCreate: %@", (status == noErr) ? @"successfully." : @"failed.");

        [_videoOutputViewController playSampleBuffer:sampleBuffer];

    }
}

@end
