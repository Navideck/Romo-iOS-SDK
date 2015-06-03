//
//  RMVisionObjectTrackingModule.h
//  RMVision
//
//  Created on 8/28/13.
//  Copyright (c) 2013 Romotive, Inc. All rights reserved.
//

#import "RMVisionModule.h"
#import "GPUImage.h"

@protocol RMVisionObjectTrackingModuleDelegate;

@interface RMVisionObjectTrackingModule : GPUImageFilterGroup <RMVisionModuleProtocol, GPUImageInput>

@property (nonatomic, weak) id<RMVisionObjectTrackingModuleDelegate> delegate;

@property (nonatomic) BOOL useContours;
@property (nonatomic) BOOL generateVisualization;
@property (nonatomic) BOOL allowAdaptiveForegroundUpdates;
@property (nonatomic) BOOL allowAdaptiveBackgroundUpdates;

@property (nonatomic, readonly) NSString *name;

// Defined from (-1.0,-1.0) to (1.0,1.0) with origin the middle of the image
// and (1.0, 1.0) in the bottom-right corner
@property (nonatomic) CGRect roi;

// Resolution to perform image processing
@property (nonatomic) CGSize processingResolution;


-(id)initModule:(NSString *)moduleName withVision:(RMVision *)core;

/**
 Grow or shrink the covariance for the positive class label
 Scaler == 1.0 will have no effect
 Scaler < 1.0 will result in fewer pixels being labeled with the positive label
*/
-(void)scalePositiveCovarianceByScaler:(float)scaler;

-(RMVisionTrainingData *)copyOfTrainingData;

@end

@protocol RMVisionObjectTrackingModuleDelegate <NSObject>

@optional

/** Called when we've finished training */
- (void)objectTrackingModuleFinishedTraining:(RMVisionObjectTrackingModule *)module;

- (void)objectTrackingModule:(RMVisionObjectTrackingModule *)module didDetectObject:(RMBlob *)object;
- (void)objectTrackingModuleDidLoseObject:(RMVisionObjectTrackingModule *)module;


- (void)showDebugImage:(UIImage *)debugImage;


@end
