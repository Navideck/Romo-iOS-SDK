//
//  RMVisionNaiveLineTrainingModule.m
//  RMVision
//
//  Created on 11/22/13.
//  Copyright (c) 2013 Romotive, Inc. All rights reserved.
//

#import "RMVisionNaiveLineTrainingModule.h"
#import "UIImage+OpenCV.h"
#import "RMOpenCVUtils.h"
#import <RMShared.h>

static const float kDefaultFloodFillTolerance = 1.0/UCHAR_MAX;
static const float kMinFloodFillFraction = 0.02;
static const float kMaxFloodFillFraction = 0.86;

@interface RMVisionNaiveLineTrainingModule ()

@end

@implementation RMVisionNaiveLineTrainingModule

#pragma mark - Initialization

- (id)initWithVision:(RMVision *)core
{
    return [self initModule:NSStringFromClass([self class]) withVision:core];
}

- (id)initModule:(NSString *)name withVision:(RMVision *)core
{
    self = [super initModule:NSStringFromClass([self class]) withVision:core];
    if (self) {
        self.scaleFactor = core.isSlow ? 1.0/4.0 : 1.0;
        
        // Default to bottom-middle of the image
        _seedPoint = CGPointMake(0.0, 1.0);
        
        _floodFillTolerance = kDefaultFloodFillTolerance;
    }
    
    return self;
}

#pragma mark - Public Properties

- (void)setFloodFillTolerance:(float)floodFillTolerance
{
    _floodFillTolerance = CLAMP(0.0, floodFillTolerance, 1.0);
}

#pragma mark - Image processing

- (void)getTrainedColor:(UIColor *__autoreleasing *)trainedColor withOutputImage:(UIImage *__autoreleasing *)outputImage
{
    cv::Mat mat = [UIImage cvMatWithImage:self.inputImage];

    cv::resize(mat, mat, cv::Size(), self.scaleFactor, self.scaleFactor, CV_INTER_LINEAR);

    // Floodfill requires 3 channel images
    cv::cvtColor(mat, mat, CV_BGRA2BGR);
    
    // Convert normalized Romo coordinates to image coordinates
    // Minus 1 on the rows and cols since we are addressing starting from 0 and not 1
    
    cv::Point seed;
    if (self.vision.camera == RMCamera_Front && !self.vision.isImageFlipped) {
        seed = cv::Point((mat.cols - 1) * (1.0 - self.seedPoint.x)/2.0,
                         (mat.rows - 1) * (self.seedPoint.y + 1.0)/2.0);
    } else {
        seed = cv::Point((mat.cols - 1) * (self.seedPoint.x + 1.0)/2.0,
                         (mat.rows - 1) * (self.seedPoint.y + 1.0)/2.0);
    }

    
    // Set floodfill parameters
    int tolerance = self.floodFillTolerance * UCHAR_MAX;
    int connectivity = 8; // Can either be 8 or 4
    
    // Floodfill with a mask
    cv::Mat mask;
    cv::Mat subMask;
    float fillFraction;
    BOOL badInput = NO;
    
    do {
        cv::Scalar loDiff = cv::Scalar::all(tolerance);
        cv::Scalar upDiff = cv::Scalar::all(tolerance);
        
        mask = cv::Mat(mat.rows+2, mat.cols+2, CV_8UC1, cv::Scalar::all(0));
        cv::floodFill(mat, mask, seed, cv::Scalar::all(UCHAR_MAX), 0, loDiff, upDiff, connectivity | cv::FLOODFILL_MASK_ONLY );
        
        // Extract the correctly-sized mask (i.e. remove border pixels)
        subMask = cv::Mat(mask, cv::Rect(1, 1, mask.cols-2, mask.rows-2));
        
        int dilationSize = 3;
        cv::Mat dilationKernel = getStructuringElement(cv::MORPH_RECT,
                                                       cv::Size( 2*dilationSize + 1, 2*dilationSize+1 ),
                                                       cv::Point( dilationSize, dilationSize ) );
        cv::dilate(mask, mask, dilationKernel);
        cv::erode(mask, mask, dilationKernel);

        int nonzeroPixels = cv::countNonZero(subMask);
        fillFraction = (float)nonzeroPixels / (float)subMask.total();
        
        // If we're not sensitive enough, grow the tolerance
        tolerance++;
        
        if (tolerance >= UCHAR_MAX || fillFraction > kMaxFloodFillFraction) {
            // If the tolerance has hit either limit, our input image must be unusable
            badInput = YES;
        }
    } while (fillFraction < kMinFloodFillFraction && !badInput);
    
    if (badInput) {
        // If we couldn't accurately flood-fill, pass an error back
        *trainedColor = nil;
        *outputImage = nil;
        return;
    }
    
    cv::threshold(subMask, subMask, 0.1, UCHAR_MAX, CV_THRESH_BINARY);
    
    // Extract training data
    cv::Mat positivePixelVector;
    [RMOpenCVUtils convertImage:mat toImageVector:positivePixelVector withMask:subMask];
    
    if (positivePixelVector.rows > 0) {
        // Convert from uchar to float since the classification training needs float values
        positivePixelVector.convertTo(positivePixelVector, CV_32FC1);
        
        // Update our delegate regarding the training process
        // cv::mean returns a 4 element cv::Scalar. We want to 0th element in that scalar.
        float meanRed   = ((cv::mean(positivePixelVector.col(2)))[0])/UCHAR_MAX;
        float meanGreen = ((cv::mean(positivePixelVector.col(1)))[0])/UCHAR_MAX;
        float meanBlue  = ((cv::mean(positivePixelVector.col(0)))[0])/UCHAR_MAX;
        
        // Set trainedColor
        *trainedColor = [UIColor colorWithRed:meanRed green:meanGreen blue:meanBlue alpha:1.0];
        
        // Build the negative image vector
        cv::Mat inverseSubMask;
        cv::threshold(subMask, inverseSubMask, 0.1, UCHAR_MAX, CV_THRESH_BINARY_INV);
        
        
        int erosion_size = 5;
        cv::Mat erodeKernel = getStructuringElement( cv::MORPH_RECT,
                                            cv::Size( 2*erosion_size + 1, 2*erosion_size+1 ),
                                            cv::Point( erosion_size, erosion_size ) );
        
        cv::erode(inverseSubMask, inverseSubMask, erodeKernel);
        
        cv::Mat negativePixelVector;
        [RMOpenCVUtils convertImage:mat toImageVector:negativePixelVector withMask:inverseSubMask];
        
        // Build training data object
        self.trainingData = [[RMVisionTrainingData alloc] initWithPositivePixels:positivePixelVector withNegativePixels:negativePixelVector];
        
        cv::Mat visualizationMat = [UIImage cvMatWithImage:self.inputImage];
        
        std::vector<cv::Mat> layers;
        cv::split(visualizationMat, layers);
        
        // Keep alpha on line to zero and set to UCHAR_MAX everywhere else
        cv::Mat enlargedSubMask;
        cv::resize(subMask, enlargedSubMask, visualizationMat.size());
        
        layers[3] -= enlargedSubMask;
        cv::merge(layers, visualizationMat);
        
        
        // Set the outputImage
        
        UIImageOrientation imageOrientation = UIImageOrientationUp;
        
        // Mirror the image if it hasn't been already
        if (self.vision.camera == RMCamera_Front && !self.vision.isImageFlipped) {
            imageOrientation = UIImageOrientationUpMirrored;
        }
        
        *outputImage = [UIImage imageWithCVMat:visualizationMat scale:1.0 orientation:imageOrientation];
        
        if ([self.delegate respondsToSelector:@selector(module:didFinishWithLabeledImage:)]) {
            
            UIImage *labelImage = [UIImage imageWithCVMat:subMask scale:1.0 orientation:imageOrientation];
            
            __weak RMVisionNaiveLineTrainingModule *weakSelf = self;
            dispatch_async(dispatch_get_main_queue(), ^(void){
                [self.delegate module:weakSelf didFinishWithLabeledImage:labelImage];
            });
        }
    }
}

@end
