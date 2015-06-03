//
//  AVCParameters.h
//  AVCEncoder
//
//  Created by Steve McFarlin on 5/5/11.
//  Copyright 2011 Steve McFarlin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

/**
 * Parameters for the AVCEncoder.
 */
@interface AVCParameters : NSObject {
@public
    
    unsigned int    outWidth;
    unsigned int    outHeight;
    OSType          pixelFormat;

    //AVC Properties
    unsigned int    keyFrameInterval;
    unsigned int    bps;
    NSString*       videoProfileLevel;
}

@property (nonatomic, assign) unsigned int outWidth;
@property (nonatomic, assign) unsigned int outHeight;
@property (nonatomic, assign) unsigned int keyFrameInterval;
@property (nonatomic, assign) unsigned int bps;
@property (nonatomic, assign) OSType pixelFormat;
@property (nonatomic, copy) NSString* videoProfileLevel;

@end
