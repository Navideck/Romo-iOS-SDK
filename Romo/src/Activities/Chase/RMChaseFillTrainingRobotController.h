//
//  RMChaseDemoCameraRobotController.h
//  Romo
//
//  Created on 10/23/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "RMRobotController.h"
#import <RMVision/RMVisionObjectTrackingModule.h>

@class RMVisionTrainingData;

typedef void(^RMChaseDemoCameraRobotControllerCompletion)(RMVisionTrainingData *trainingData);

@interface RMChaseFillTrainingRobotController : RMRobotController <RMVisionObjectTrackingModuleDelegate>

@property (nonatomic, copy) RMChaseDemoCameraRobotControllerCompletion completion;

- (instancetype)initWithCovarianceScaling:(float)scale completion:(RMChaseDemoCameraRobotControllerCompletion)completion;

@end
