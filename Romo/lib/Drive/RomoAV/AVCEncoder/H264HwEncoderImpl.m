//
//  H264HwEncoderImpl.m
//  h264v1
//
//  Created by Ganvir, Manish on 3/31/15.
//  Copyright (c) 2015 Ganvir, Manish. All rights reserved.
//

#import "H264HwEncoderImpl.h"

#import <VideoToolbox/VideoToolbox.h>
#import <AVFoundation/AVFoundation.h>

@implementation H264HwEncoderImpl
{
    VTCompressionSessionRef EncodingSession;
    dispatch_queue_t aQueue;
    CMFormatDescriptionRef  format;
    CMSampleTimingInfo * timingInfo;
    BOOL initialized;
    NSData *sps;
    NSData *pps;
}
@synthesize error;

- (void) initWithConfiguration
{
    EncodingSession = nil;
    initialized = true;
    aQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    sps = NULL;
    pps = NULL;
    
}

void didCompressH264(void *outputCallbackRefCon, void *sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags,
                     CMSampleBufferRef sampleBuffer )
{
    //    NSLog(@"didCompressH264 called with status %d infoFlags %d", (int)status, (int)infoFlags);
    if (status != 0) return;
    
    if (!CMSampleBufferDataIsReady(sampleBuffer))
    {
        NSLog(@"didCompressH264 data is not ready ");
        return;
    }
    H264HwEncoderImpl* encoder = (__bridge H264HwEncoderImpl*)outputCallbackRefCon;
    
    // Check if we have got a key frame first
    bool keyframe = !CFDictionaryContainsKey( (CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0)), kCMSampleAttachmentKey_NotSync);
    
    if (keyframe)
    {
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        // CFDictionaryRef extensionDict = CMFormatDescriptionGetExtensions(format);
        // Get the extensions
        // From the extensions get the dictionary with key "SampleDescriptionExtensionAtoms"
        // From the dict, get the value for the key "avcC"
        
        size_t sparameterSetSize, sparameterSetCount;
        const uint8_t *sparameterSet;
        OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sparameterSet, &sparameterSetSize, &sparameterSetCount, 0 );
        if (statusCode == noErr)
        {
            // Found sps and now check for pps
            size_t pparameterSetSize, pparameterSetCount;
            const uint8_t *pparameterSet;
            OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pparameterSet, &pparameterSetSize, &pparameterSetCount, 0 );
            if (statusCode == noErr)
            {
                // Found pps
                encoder->sps = [NSData dataWithBytes:sparameterSet length:sparameterSetSize];
                encoder->pps = [NSData dataWithBytes:pparameterSet length:pparameterSetSize];
                if (encoder->_delegate)
                {
                    [encoder->_delegate gotSpsPps:encoder->sps pps:encoder->pps];
                }
            }
        }
    }
    
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t length, totalLength;
    char *dataPointer;
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
    if (statusCodeRet == noErr) {
        
        size_t bufferOffset = 0;
        static const int AVCCHeaderLength = 4;
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            
            // Read the NAL unit length
            uint32_t NALUnitLength = 0;
            memcpy(&NALUnitLength, dataPointer + bufferOffset, AVCCHeaderLength);
            
            // Convert the length value from Big-endian to Little-endian
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
            
            NSData* data = [[NSData alloc] initWithBytes:(dataPointer + bufferOffset + AVCCHeaderLength) length:NALUnitLength];
            [encoder->_delegate gotEncodedData:data isKeyFrame:keyframe];
            
            // Move to the next NAL unit in the block buffer
            bufferOffset += AVCCHeaderLength + NALUnitLength;
        }
        
    }
    
}

- (void) encode:(CMSampleBufferRef )sampleBuffer
{
    dispatch_sync(aQueue, ^{
        
        // Get the CV Image buffer
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        
        // Create properties
        CMTime presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        CMTime duration = CMSampleBufferGetDuration(sampleBuffer);
        VTEncodeInfoFlags flags;
        
        // Pass it to the encoder
        OSStatus statusCode = VTCompressionSessionEncodeFrame(self->EncodingSession,
                                                              imageBuffer,
                                                              presentationTimeStamp,
                                                              duration,
                                                              NULL, NULL, &flags);
        // Check for error
        if (statusCode != noErr) {
            NSLog(@"H264: VTCompressionSessionEncodeFrame failed with %d", (int)statusCode);
            self->error = @"H264: VTCompressionSessionEncodeFrame failed ";
            
            // End the session
            VTCompressionSessionInvalidate(self->EncodingSession);
//            CFRelease(EncodingSession);
            self->EncodingSession = NULL;
            self->error = NULL;
            return;
        }
    });
    
    
}

- (void) initEncodeWidth:(int)width height:(int)height
{
    dispatch_sync(aQueue, ^{
        
        // For testing out the logic, lets read from a file and then send it to encoder to create h264 stream
        
        // Create the compression session
        OSStatus status = VTCompressionSessionCreate(NULL, width, height, kCMVideoCodecType_H264, NULL, NULL, NULL, didCompressH264, (__bridge void *)(self),  &self->EncodingSession);
        NSLog(@"H264: VTCompressionSessionCreate %d", (int)status);
        
        if (status != 0)
        {
            NSLog(@"H264: Unable to create a H264 session");
            self->error = @"H264: Unable to create a H264 session";
            
            return ;
            
        }
        
        // Set the properties
        VTSessionSetProperty(self->EncodingSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
        VTSessionSetProperty(self->EncodingSession, kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse);
        VTSessionSetProperty(self->EncodingSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Main_3_1);
        
        
        // Tell the encoder to start encoding
        VTCompressionSessionPrepareToEncodeFrames(self->EncodingSession);
    });
}

- (void) stop
{
    // Mark the completion
    VTCompressionSessionCompleteFrames(EncodingSession, kCMTimeInvalid);
    
    // End the session
    VTCompressionSessionInvalidate(EncodingSession);
//    CFRelease(EncodingSession);
    EncodingSession = NULL;
    error = NULL;
    
}

@end

