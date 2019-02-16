////////////////////////////////////////////////////////////////////////////////
//                             _
//                            | | (_)
//   _ __ ___  _ __ ___   ___ | |_ ___   _____
//  | '__/ _ \| '_ ` _ \ / _ \| __| \ \ / / _ \
//  | | | (_) | | | | | | (_) | |_| |\ V /  __/
//  |_|  \___/|_| |_| |_|\___/ \__|_| \_/ \___|
//
////////////////////////////////////////////////////////////////////////////////
//
//  RMVisionModule.h
//  RMVision
//
//  Created by Romotive on 4/9/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
////////////////////////////////////////////////////////////////////////////////
#import <Foundation/Foundation.h>
#import "RMVision.h"
#import "RMVisionModuleProtocol.h"

@class RMVision;

@interface RMVisionModule : NSObject <RMVisionModuleProtocol>

@property (nonatomic) BOOL isColor;

@property (nonatomic) uint32_t frameNumber;
@property (nonatomic, readonly) BOOL isSlow;
@property (nonatomic) float scaleFactor;

@property (nonatomic, readonly) int width;
@property (nonatomic, readonly) int height;

#ifdef __cplusplus
@property (atomic) cv::Mat output;
#endif

@property (atomic) BOOL frameProcessed;

-(id)initModule:(NSString *)name
     withVision:(RMVision *)core;

#ifdef __cplusplus
-(cv::Mat)resizeFrame:(const cv::Mat)mat
            videoRect:(CGRect)rect;
#endif

@end
