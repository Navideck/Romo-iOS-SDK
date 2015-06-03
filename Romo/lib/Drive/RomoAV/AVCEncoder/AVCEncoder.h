//
//  AVCEncoder.h
//  AVCEncoder
//
//  Created by Steve McFarlin on 5/5/11.
//  Copyright 2011 Steve McFarlin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import "AVCParameters.h"

#pragma mark - Block Types --

@class AVCEncoder;

/**
 * This block will be called for each AVC frame in the video. This block will be running on a queue
 * created by the AVCEncoder. You should copy the data immediatly and return. If you are streaming
 * over a UDP based protocol you may be able to get away with writing the packet before returning.
 *
 * @param frame An Annex B encoded NAL unit.
 * @param size The size of the NAL unit in bytes.
 * @param pts The time stamp of the captured image.
 */
typedef void (^AVCEncoderCallback)(const void* frame, uint32_t length, CMTime pts) ;

/** 
 * This block takes a different approach. The encoder will submit this to a serial queue for 
 * processing. You are resposible for releasing the data. Using this method the NAL units
 * will be queued on a GCD queue. It is safe to do any processing in this callback. The 
 * primary purpose for this callback is so you do not have to manage a separate queue.
 * However, you now have the overhead of GCD. 
 * @warning Not implemented.
 * @param data The NAL unit (NOTE: you take ownership of this data).
 * @param The time stamp of the captured image.
 */
typedef void (^AVCEncoderSerialQueueCallback)(NSData* data, CMTime time_stamp) ;

#pragma mark - AVCEncoder --

/** 
 * This class will take a series of images and convert this into a AVC Annex B byte stream. 
 * When the start message is sent the callback will immediatly be sent two NALUs. It will
 * send the SPS and then the PPS in Annex B format.
 * 
 * - Usage:
 *  1. Set the AVCParameters. 
 *  2. Call the prepareEncoder function. (At this point the spspps NAL units are ready.)
 *  3. Start feeding the encode function with CMSampleBufferRefs.
 */
@interface AVCEncoder : NSObject {
    AVCParameters *parameters;
@private
    BOOL isEncoding;
	long maxBitrate;
    AVCEncoderCallback callback;
    AVCEncoderSerialQueueCallback callbackOnSerialQueue; //Not used.
    dispatch_queue_t caller_queue; //not used.
    NSError* error;
    
}
/// Parameters should be set before a call to prepareEncoder.
@property (nonatomic, retain) AVCParameters *parameters; 

/// The block needs to be heap allocated.
@property (nonatomic, copy) AVCEncoderCallback callback;

/// @warning Not implemented.
@property (nonatomic, copy) AVCEncoderSerialQueueCallback callbackOnSerialQueue; 

/// Only valid after encoder is prepared. In Annex B format.
@property (nonatomic, retain, readonly) NSData *spspps; 

/// Only valid after encoder is prepared. In Annex B format.
@property (nonatomic, retain, readonly) NSData *sps, *pps;

/// The encoding status.
@property (nonatomic, readonly) BOOL isEncoding;

/// The most recent encoding error, if one exists.
@property (nonatomic, readonly, retain) NSError *error;

/// The maximum bitrate. Set to 0 to turn off (default).
@property (nonatomic, assign) long maxBitrate;

/**
 * This will change the bitrate of the stream. This method should not be called continiously. Given the hostile 
 * networking enviornment a cell phone usually sees it is wise to create a statistical network average over a period
 * of time before making a decision on how to set the encoding bitrate. I do not recomend setting this at a 
 * frequency below 3Hz.
 * This method blocks the caller until the change has occured.
 */
@property (nonatomic, assign) unsigned averagebps;

/**
 * This sets up the encoder with the currently assigned parameters. If the current parameters are nil, then defaults are used. 
 * After this call the sps and pps properties will be valid.
 * @return If the preparation was successful.
 */
- (BOOL)prepareEncoder;

/**
 * Starts the encoder
 * @return If the start was successful.
 */
- (BOOL)start;

/**
 * Starts the encoder with the provided CallbackQueue.
 * @param queue A CallbackQueue instance.
 */
- (void)startWithCallbackQueue:(dispatch_queue_t)queue; 

/**
 * Stops the encoder
 */
- (void)stop;

/**
 * Encodes the provided sample buffer.
 * @param sample The sample buffer to encode.
 */
- (void)encode:(CMSampleBufferRef)sample;

/**
 * Encodes the provided sample buffer with a specific PTS value.
 * @param buffer The sample buffer to encode.
 * @param pts The PTS value for the buffer.
 */
- (void)encode:(CVPixelBufferRef)buffer withPresentationTime:(CMTime)pts;

@end
