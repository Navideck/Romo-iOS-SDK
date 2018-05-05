//
//  RAVVideoOutput.m
//  RomoAV
//

#import "RAVVideoOutput.h"

#import <VideoToolbox/VideoToolbox.h>

#import "RGLBufferVC.h"

#define MAX_BACKLOGGED_FRAMES 10

@implementation VideoPacket
- (instancetype)initWithSize:(NSInteger)size
{
    self = [super init];
    self.buffer = malloc(size);
    self.size = size;
    
    return self;
}

-(void)dealloc
{
    free(self.buffer);
}
@end

@interface RAVVideoOutput ()
{
    RGLBufferVC  *_videoOutputViewController;
    
    VideoPacket *_vp;
    
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
        
//        [[NSNotificationCenter defaultCenter] addObserver:self
//                                                 selector:@selector(applicationWillResignActive:)
//                                                     name:UIApplicationWillResignActiveNotification
//                                                   object:nil];

        
//        [[NSNotificationCenter defaultCenter] addObserver:self
//                                                 selector:@selector(applicationDidBecomeActive:)
//                                                     name:UIApplicationDidBecomeActiveNotification
//                                                   object:nil];

    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)stop
{
    _videoOutputViewController = nil;
}

- (UIView *)prepareOutputViewWithFrame:(CGRect)frame
{
    if (!_videoOutputViewController) {
        _videoOutputViewController = [[RGLBufferVC alloc] initWithFrame:frame];
    }
    
    return _videoOutputViewController.view;
}

const uint8_t KStartCode[4] = {0, 0, 0, 1};

- (VideoPacket*) getPacket:(uint8_t *)buffer length:(uint32_t)length
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
                    VideoPacket *vp = [[VideoPacket alloc] initWithSize:length];
                    memcpy(vp.buffer, buffer, length);
                    
                    return vp;
                }
            }
            ++bufferBegin;
        }
    }
    
    return nil;
}

//static void didDecompress( void *decompressionOutputRefCon, void *sourceFrameRefCon, OSStatus status, VTDecodeInfoFlags infoFlags, CVImageBufferRef pixelBuffer, CMTime presentationTimeStamp, CMTime presentationDuration ){
//    
//    CVPixelBufferRef *outputPixelBuffer = (CVPixelBufferRef *)sourceFrameRefCon;
//    *outputPixelBuffer = CVPixelBufferRetain(pixelBuffer);
//}

-(BOOL)initH264Decoder {
    const uint8_t* const parameterSetPointers[2] = { _sps, _pps };
    const size_t parameterSetSizes[2] = { _spsSize, _ppsSize };
    OSStatus status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault,
                                                                          2, //param count
                                                                          parameterSetPointers,
                                                                          parameterSetSizes,
                                                                          4, //nal start code size
                                                                          &_decoderFormatDescription);
    
//    if(status == noErr) {
//        CFDictionaryRef attrs = NULL;
//        const void *keys[] = { kCVPixelBufferPixelFormatTypeKey };
//        //      kCVPixelFormatType_420YpCbCr8Planar is YUV420
//        //      kCVPixelFormatType_420YpCbCr8BiPlanarFullRange is NV12
//        uint32_t v = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
//        const void *values[] = { CFNumberCreate(NULL, kCFNumberSInt32Type, &v) };
//        attrs = CFDictionaryCreate(NULL, keys, values, 1, NULL, NULL);
//
//        VTDecompressionOutputCallbackRecord callBackRecord;
//        callBackRecord.decompressionOutputCallback = didDecompress;
//        callBackRecord.decompressionOutputRefCon = NULL;
//
//        status = VTDecompressionSessionCreate(kCFAllocatorDefault,
//                                              _decoderFormatDescription,
//                                              NULL, attrs,
//                                              &callBackRecord,
//                                              &_decoderSession);
//        CFRelease(attrs);
//    } else {
//        NSLog(@"IOS8VT: reset decoder session failed status=%d", (int)status);
//    }
    
    return YES;
}

- (CVPixelBufferRef) decode:(VideoPacket*) vp {
    CVPixelBufferRef outputPixelBuffer = NULL;
    
    CMBlockBufferRef blockBuffer = NULL;
    OSStatus status  = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault,
                                                          (void*)vp.buffer, vp.size,
                                                          kCFAllocatorNull,
                                                          NULL, 0, vp.size,
                                                          0, &blockBuffer);
    
    if(status == kCMBlockBufferNoErr) {
        CMSampleBufferRef sampleBuffer = NULL;
        const size_t sampleSizeArray[] = {vp.size};
        status = CMSampleBufferCreateReady(kCFAllocatorDefault,
                                           blockBuffer,
                                           _decoderFormatDescription,
                                           1, 0, NULL, 1, sampleSizeArray,
                                           &sampleBuffer);
        
        if (status == kCMBlockBufferNoErr && sampleBuffer) {
            
            [_videoOutputViewController playSampleBuffer:sampleBuffer];
            
//            VTDecodeFrameFlags flags = 0;
//            VTDecodeInfoFlags flagOut = 0;
//            OSStatus decodeStatus = VTDecompressionSessionDecodeFrame(_decoderSession,
//                                                                      sampleBuffer,
//                                                                      flags,
//                                                                      &outputPixelBuffer,
//                                                                      &flagOut);
//            
//            if(decodeStatus == kVTInvalidSessionErr) {
//                NSLog(@"IOS8VT: Invalid session, reset decoder session");
//            } else if(decodeStatus == kVTVideoDecoderBadDataErr) {
//                NSLog(@"IOS8VT: decode failed status=%d(Bad data)", (int)decodeStatus);
//            } else if(decodeStatus != noErr) {
//                NSLog(@"IOS8VT: decode failed status=%d", (int)decodeStatus);
//            }
            
            CFRelease(sampleBuffer);
        }
        CFRelease(blockBuffer);
    }
    
    return outputPixelBuffer;
}

- (void) playVideoFrame:(void *)frame length:(uint32_t)length
{
    VideoPacket *vp = [self getPacket:frame length:length];
    if(vp == nil) {
        return;
    }
    
    uint32_t nalSize = (uint32_t)(vp.size - 4);
    uint8_t *pNalSize = (uint8_t*)(&nalSize);
    vp.buffer[0] = *(pNalSize + 3);
    vp.buffer[1] = *(pNalSize + 2);
    vp.buffer[2] = *(pNalSize + 1);
    vp.buffer[3] = *(pNalSize);
    
    CVPixelBufferRef pixelBuffer = NULL;
    int nalType = vp.buffer[4] & 0x1F;
    switch (nalType) {
        case 0x05:
//            NSLog(@"Nal type is IDR frame");
            if([self initH264Decoder]) {
                pixelBuffer = [self decode:vp];
            }
            break;
        case 0x07:
//            NSLog(@"Nal type is SPS");
            _spsSize = vp.size - 4;
            _sps = malloc(_spsSize);
            memcpy(_sps, vp.buffer + 4, _spsSize);
            break;
        case 0x08:
//            NSLog(@"Nal type is PPS");
            _ppsSize = vp.size - 4;
            _pps = malloc(_ppsSize);
            memcpy(_pps, vp.buffer + 4, _ppsSize);
            break;
            
        default:
//            NSLog(@"Nal type is B/P frame");
            pixelBuffer = [self decode:vp];
            break;
    }
    
    if(pixelBuffer) {
        CVPixelBufferRelease(pixelBuffer);
    }
}

@end
