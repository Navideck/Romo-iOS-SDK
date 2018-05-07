#import "RGLBufferVC.h"

@implementation RGLBufferVC

#pragma mark - Initialization --

- (id)initWithFrame:(CGRect)frame
{
    if (self = [super init])
    {
        _displayLayer = [[AVSampleBufferDisplayLayer alloc] init];
        
        _displayLayer.bounds = frame;
        _displayLayer.frame = frame;
        _displayLayer.backgroundColor = [UIColor blackColor].CGColor;
        _displayLayer.position = CGPointMake(CGRectGetMidX(frame), CGRectGetMidY(frame));
        
        [self.view.layer addSublayer:_displayLayer];
    }
    
    return self;
}

- (void) playSampleBuffer:(CMSampleBufferRef) sampleBuffer
{
    CFRetain(sampleBuffer);
    
    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, YES);
    CFMutableDictionaryRef dict = (CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
    CFDictionarySetValue(dict, kCMSampleAttachmentKey_DisplayImmediately, kCFBooleanTrue);
    
    dispatch_async(dispatch_get_main_queue(),^{
        if ([_displayLayer isReadyForMoreMediaData])
        {
            [_displayLayer enqueueSampleBuffer:sampleBuffer];
//            [_displayLayer setNeedsDisplay];
        }
        else
        {
            NSLog(@"Not Ready...");
        }
    });
    
    CFRelease(sampleBuffer);
}

@end
