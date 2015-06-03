//
//  RMMotionTriggeredColorTrainingModule.h
//  RMVision
//
//  Created on 10/2/13.
//  Copyright (c) 2013 Romotive, Inc. All rights reserved.
//

#import "RMVisionModule.h"
#import "RMVisionModuleProtocol.h"
#import "GPUImage.h"

@protocol RMMotionTriggeredColorTrainingModuleDelegate;

@interface RMMotionTriggeredColorTrainingModule : GPUImageFilterGroup <RMVisionModuleProtocol, GPUImageInput>

@property (nonatomic, weak) id<RMMotionTriggeredColorTrainingModuleDelegate> delegate;

// Brightness and saturation thresholds for the HSV notch filter
// Range 0.0 to 1.0
@property (nonatomic) float brightnessThreshold;
@property (nonatomic) float saturationThreshold;

// Size of the blur box filter in pixels
@property (nonatomic) float blurBoxSize;

// Strength of the low pass filter for motion detection
// Range 0.0 to 1.0 (lower means less sensitive)
@property (nonatomic) float lowPassFilterStrength;

// Number of clusters to find in the result data
@property (nonatomic) int numberOfKMeansClusters;

// Number of kmeans attempts
// 1 is the fastest but higher numbers will be more accurate
@property (nonatomic) int kmeansAttempts;

// Number of sequential frames that must trigger on motion and color before clustering
@property (nonatomic) int triggerCountThreshold;

/**
 Percent of pixels in the image that must trigger to consider that frame valid
 On [0.0, 1.0]
 */
@property (nonatomic) float percentOfPixelsMovingThreshold;

// Limit the number of pixels to accumulate during training
// Too large a value can cause the slower devices to have frame rate problems.
@property (nonatomic) int maximumAccumulatedPixels;

// Set when training is complete. Clear if you want to restart training.
@property (nonatomic, getter = isTrainingComplete) bool trainingComplete;

// Set if additional refinement of kmeans clustering is desired
// Default is NO
@property (nonatomic) BOOL shouldCluster;

@property (nonatomic, getter=isCapturingPositiveTrainingData) BOOL capturingPositiveTrainingData;

- (id)initModule:(NSString *)moduleName withVision:(RMVision *)core;

-(void)captureNegativeTrainingData;
-(void)clearNegativeTrainingData;

@end

@protocol RMMotionTriggeredColorTrainingModuleDelegate <NSObject>

/**
 Delegate method that is triggered when the training routine received an update with data.
 @param progress Float in the range from 0.0 to 1.0 to indicate the progress of training from zero to 100% complete. It can decrease.
 @param color A UIColor with the estimate training outcome. Can be used for visualization
*/
- (void)motionTriggeredTrainingModule:(RMMotionTriggeredColorTrainingModule *)module didUpdateWithProgress:(float)progress withEstimatedColor:(UIColor *)color;

/**
 Delegate method that is triggered when the training routine is complete
 @param color A UIColor with the training outcome. Can be used for visualization
 @param trainingData A training data object that should be passed to a classifier module.
 */
- (void)motionTriggeredTrainingModule:(RMMotionTriggeredColorTrainingModule *)module didFinishWithColor:(UIColor *)color withTrainingData:(RMVisionTrainingData *)trainingData;

@end

void runSynchronouslyOnGPUImageQueue(void (^block)(void));
