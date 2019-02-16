//
//  RMEyeDetectionModule.h
//  RMVision
//
//  Created on 7/8/13.
//  Copyright (c) 2013 Romotive, Inc. All rights reserved.
//

#import "RMVisionModule.h"
#import "RMVisionModuleProtocol.h"
#import "RMFaceDetectionModule.h"

@interface RMEyeDetectionModule : RMVisionModule <RMVisionModuleProtocol>

@property (nonatomic, weak) RMFaceDetectionModule *faceDetector;

@end
