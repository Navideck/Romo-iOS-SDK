//
//  RAVVideoOutput.m
//  RomoAV
//

#import "RAVVideoOutput.h"

#ifndef SIMULATOR
#import <libavcodec/avcodec.h>
#import <libswscale/swscale.h>
#endif

#import "RGLBufferVC.h"
#import <libkern/OSAtomic.h>

#define MAX_BACKLOGGED_FRAMES 10

@interface RAVVideoOutput ()
{
    RGLBufferVC  *_videoOutputViewController;
    
#ifndef SIMULATOR
    AVFrame                 *_sourceFrame;
    AVFrame                 *_destinationFrame;
    
    AVCodec                 *_codec;
    AVCodecContext          *_codecCtx;
    
    struct SwsContext       *_convertCtx;
#endif
    
    dispatch_queue_t        _frameDecodeQueue;
    dispatch_queue_t        _frameRenderQueue;
    
    BOOL                    _isInitialized;
    
    uint8_t                 *_outputBuffer;
    
    BOOL                    _isVideoFrameQueueActive;
    volatile int32_t        _approximateQueueLength;
}

@end

@implementation RAVVideoOutput

- (id)init
{
    self = [super init];
    if (self) {

#ifndef SIMULATOR
        av_log_set_level(AV_LOG_QUIET);
        
        _sourceFrame      = avcodec_alloc_frame();
        _destinationFrame = avcodec_alloc_frame();
        _outputBuffer = NULL;
        
        _frameDecodeQueue = dispatch_queue_create("Frame Decode Queue", DISPATCH_QUEUE_SERIAL);
        _frameRenderQueue = dispatch_queue_create("Frame Render Queue", DISPATCH_QUEUE_SERIAL);
        
        _isInitialized = NO;
        
        avcodec_register_all();
        _codec = avcodec_find_decoder(CODEC_ID_H264);
        
        _codecCtx = avcodec_alloc_context3(_codec);
        
        // Codec settings:
        _codecCtx->width = 0;
        _codecCtx->height = 0;
        _codecCtx->flags2 |= CODEC_FLAG2_FAST;
        _codecCtx->pix_fmt = PIX_FMT_YUV420P;
        
        avcodec_open2(_codecCtx, _codec, NULL);
        
        CGRect frame = [UIScreen mainScreen].bounds;
        
        CGFloat videoAspectRatio = 480.0 / 640.0;
        CGFloat frameAspectRatio = frame.size.width / frame.size.height;
        
        CGFloat k = videoAspectRatio / frameAspectRatio;
        frame.size.width *= k;
        
        self.peerView = [self prepareOutputViewWithFrame:frame];
        self.peerView.transform = CGAffineTransformMakeScale(-1, 1);
        
        _isVideoFrameQueueActive = YES;
#endif
        
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
    _isVideoFrameQueueActive = NO;
    dispatch_sync(_frameRenderQueue, ^{
        dispatch_suspend(_frameRenderQueue);
    });
}

- (void)applicationDidBecomeActive:(id)notification
{
    _isVideoFrameQueueActive = YES;
    if (_frameRenderQueue) {
        dispatch_resume(_frameRenderQueue);
    }
}

- (void)stop
{
    // The queue needs to be running to call dispatch_sync and dispatch_release.
    // So if the render queue is suspended, let's resume it before continuing.
    if (!_isVideoFrameQueueActive) {
        dispatch_resume(_frameRenderQueue);
    }
    
    _isVideoFrameQueueActive = NO;
    
    // Note: This is ghetto as fuck...
    // Bascially, we need to make sure the queues are empty before releasing them
    // These nested sync calls ensure that the currently executing blocks will
    // finish before we try to release the queues
    dispatch_sync(_frameRenderQueue, ^{
        dispatch_sync(_frameDecodeQueue, ^{

        });
    });
    
    _videoOutputViewController = nil;

#ifndef SIMULATOR
    _codec = nil;

    if (_codecCtx) {
        av_free(_codecCtx);
    }
    
    if (_sourceFrame) {
        av_free(_sourceFrame);
    }
    
    if (_destinationFrame) {
        av_free(_destinationFrame);
    }
    
    if (_outputBuffer) {
        free(_outputBuffer);
    }
    
    if (_convertCtx) {
        sws_freeContext(_convertCtx);
    }
#endif
}

- (UIView *)prepareOutputViewWithFrame:(CGRect)frame
{
    if (!_videoOutputViewController) {
        _videoOutputViewController = [[RGLBufferVC alloc] initWithFrame:frame];
    }
    
    return _videoOutputViewController.view;
}

- (void)playVideoFrame:(void *)frame length:(uint32_t)length
{
#ifndef SIMULATOR
    void (^block)() = ^{
        if (_approximateQueueLength < MAX_BACKLOGGED_FRAMES && _isVideoFrameQueueActive) {
            AVPacket avPacket;
            
            av_init_packet(&avPacket);
            memset(&avPacket, 0, sizeof(AVPacket));
            
            avPacket.data = frame;
            avPacket.size = length;
            
            if (avPacket.data) {
                int packetDecoded = 0;
                avcodec_decode_video2(_codecCtx, _sourceFrame, &packetDecoded, &avPacket);
                
                if (!_isInitialized) {
                    if (_codecCtx->width > 0 && _codecCtx->height > 0) {
                        int outputBufferLength = avpicture_get_size(PIX_FMT_NV12,
                                                                 _codecCtx->width,
                                                                 _codecCtx->height);
                        
                        _outputBuffer = av_malloc(outputBufferLength);
                        
                        avpicture_fill((AVPicture *) _destinationFrame, _outputBuffer, PIX_FMT_NV12, _codecCtx->width, _codecCtx->height);
                        
                        _convertCtx = sws_getContext(_codecCtx->width,
                                                     _codecCtx->height,
                                                     _codecCtx->pix_fmt,
                                                     _codecCtx->width,
                                                     _codecCtx->height,
                                                     PIX_FMT_NV12,
                                                     SWS_FAST_BILINEAR,
                                                     NULL, NULL, NULL);
                        
                        _isInitialized = YES;
                    }
                }
                
                if (packetDecoded && _isVideoFrameQueueActive) {
                    
                    dispatch_async(_frameRenderQueue, ^() {
                        if (_isVideoFrameQueueActive) {
                            
                            sws_scale(_convertCtx, (const uint8_t **)_sourceFrame->data, _sourceFrame->linesize, 0,
                                      _codecCtx->height, _destinationFrame->data, _destinationFrame->linesize);
                            
                            void *planes[2] = {
                                _destinationFrame->data[0],
                                _destinationFrame->data[1]
                            };
                            
                            [_videoOutputViewController drawPlanes:planes width:_codecCtx->width height:_codecCtx->height];
                        }
                    });
                }
            }
        }
        OSAtomicDecrement32(&_approximateQueueLength);

        // note: frame was malloc'd in RNTDataPacket (initWithType: data: destination:)
        if (frame) {
            free(frame);
        }
    };

    if (_isVideoFrameQueueActive){
        OSAtomicIncrement32(&_approximateQueueLength);
        dispatch_async(_frameDecodeQueue, block);
    }
#endif
    
}

@end
