//
//  RMVisionNaiveLineTrainingModule.h
//  RMVision
//
//  Created on 11/22/13.
//  Copyright (c) 2013 Romotive, Inc. All rights reserved.
//

#import "RMVisionModule.h"

@protocol RMVisionNaiveLineTrainingModuleDelegate;

@interface RMVisionNaiveLineTrainingModule : RMVisionModule

@property (nonatomic, weak) id<RMVisionNaiveLineTrainingModuleDelegate> delegate;

// Romo normalized seed point in the range from (-1.0, -1.0) to (1.0, 1.0).
// With the origin in the image center and coordinates increase moving up-right
@property (nonatomic) CGPoint seedPoint;
@property (nonatomic, strong) UIImage *inputImage;
@property (nonatomic, strong) RMVisionTrainingData *trainingData;

/**
 The tolerance of the flood fill centered at the color value of the seedPoint
 Must be on [0.0, 1.0]
 0.0 will only flood fill to the exact same color
 1.0 will flood fill to all colors
 */
@property (nonatomic) float floodFillTolerance;

/**
 When the inputImage is bad, the trainedColor property will remain nil to flag the error
 */
- (void)getTrainedColor:(UIColor **)trainedColor withOutputImage:(UIImage **)outputImage;

@end

@protocol RMVisionNaiveLineTrainingModuleDelegate <NSObject>

@optional
// A UIImage with the line labeled as 255 and everywhere else as 0.
- (void)module:(RMVisionNaiveLineTrainingModule *)module didFinishWithLabeledImage:(UIImage *)labeledImage;


@end