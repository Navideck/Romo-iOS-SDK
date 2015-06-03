
//  RMMotionTriggeredColorTrainingModule.m
//  RMVision
//
//  Created on 10/2/13.
//  Copyright (c) 2013 Romotive, Inc. All rights reserved.
//

#import "RMMotionTriggeredColorTrainingModule.h"
#import "RMVisionDebugBroker.h"
#import "GPUImageMotionSegmentation.h"
#import "GPUImageBrightColorNotchFilter.h"
#import "UIImage+OpenCV.h"

using namespace cv;

void runSynchronouslyOnGPUImageQueue(void (^block)(void))
{
    dispatch_queue_t videoProcessingQueue = [GPUImageContext sharedContextQueue];
#if (!defined(__IPHONE_6_0) || (__IPHONE_OS_VERSION_MAX_ALLOWED < __IPHONE_6_0))
    if (dispatch_get_current_queue() == videoProcessingQueue)
#else
        if (dispatch_get_specific([GPUImageContext contextKey]))
#endif
        {
            block();
        }else
        {
            dispatch_sync(videoProcessingQueue, block);
        }
}

@interface RMMotionTriggeredColorTrainingModule ()

@property (nonatomic) GPUImageRawDataInput *rawDataInput;
@property (nonatomic) GPUImageBrightColorNotchFilter *notchFilter;
@property (nonatomic) GPUImageMotionSegmentation *motionSegmentation;
@property (nonatomic) GPUImageRawDataOutput *rawDataOutput;

@property (nonatomic) cv::Mat lastFrame;
@property (nonatomic) cv::Mat positiveTrainingData;
@property (nonatomic) cv::Mat negativeTrainingData;

@property (nonatomic) int triggerCount;

@property (nonatomic, readwrite) NSString *name;
@property (nonatomic) float scaleFactor;

@end

@implementation RMMotionTriggeredColorTrainingModule

// Remap the paused property to the GPUImageFilter's property named "enabled"
@synthesize paused = enabled;

// Synthesize the properties from RMVisionModuleProtocol
@synthesize vision = _vision;
@synthesize name = _name;
@synthesize frameNumber = _frameNumber;

#pragma mark - Initialization / Teardown

//------------------------------------------------------------------------------
-(id)initWithVision:(RMVision *)core
{
    return [self initModule:NSStringFromClass([self class]) withVision:core];
}

//------------------------------------------------------------------------------
- (id)initModule:(NSString *)moduleName withVision:(RMVision *)core
{
    self = [super init];
    if (self) {
        _vision = core;
        _name = moduleName;
        
        // Good default values found through trail and error:
        _percentOfPixelsMovingThreshold = 0.002;
        _kmeansAttempts = 1;
        _maximumAccumulatedPixels = 75000;
        _numberOfKMeansClusters = 3;
        _triggerCountThreshold = 30;
        
        if (self.vision.isSlow) {
            _scaleFactor = 1.0/18.0;
        } else {
            _scaleFactor = 1.0/4.0;
        }
        
        // The size of video frames we want to be getting
        CGSize processingSize = CGSizeMake(self.vision.width*_scaleFactor, self.vision.height*_scaleFactor);
        
        // Initialize the raw data output
        runSynchronouslyOnGPUImageQueue(^{
            _rawDataOutput = [[GPUImageRawDataOutput alloc] initWithImageSize:processingSize resultsInBGRAFormat:YES];
        });
        
        _notchFilter = [[GPUImageBrightColorNotchFilter alloc] init];
        _motionSegmentation = [[GPUImageMotionSegmentation alloc] init];
        
        // These use self since we are overriding the setters
        self.brightnessThreshold = 0.65;
        self.saturationThreshold = 0.5;
        self.lowPassFilterStrength = 0.6;
        
        
        [self addFilter:_notchFilter];
        [self addFilter:_motionSegmentation];

        __weak RMMotionTriggeredColorTrainingModule *weakSelf = self;
        [_rawDataOutput setNewFrameAvailableBlock:^{
            
            GLubyte *outputBytes = [weakSelf.rawDataOutput rawBytesForImage];
            cv::Mat outputMat(processingSize.height, processingSize.width, CV_8UC4, outputBytes);
            
            [weakSelf processRawDataOutputMat:outputMat];
        }];
        
        [_notchFilter forceProcessingAtSize:processingSize];
        [_motionSegmentation forceProcessingAtSize:processingSize];
        
        // Assemble the filter pipeline
        [_motionSegmentation addTarget:_notchFilter];
        [_notchFilter addTarget:_rawDataOutput];
        
        // Input filters
        // Multiple filters can act as input filters
        self.initialFilters = [NSArray arrayWithObjects:_motionSegmentation, nil];
        
        // Output filter
        // There can only be one
        self.terminalFilter = _notchFilter;
    }
    return self;
}

//------------------------------------------------------------------------------
- (void)shutdown
{
    for (GPUImageOutput *filter in filters) {
        if ([filter respondsToSelector:@selector(removeAllTargets)]) {
            [filter removeAllTargets];
        }
    }
}

#pragma mark - Per Image Processing

- (void)processRawDataOutputMat:(cv::Mat)outputMat
{
    // Do nothing if training is complete
    if (self.isTrainingComplete || !self.isCapturingPositiveTrainingData) {
        return;
    }
    
    int numberOfPixels = outputMat.rows*outputMat.cols;
    cv::cvtColor(outputMat, outputMat, CV_BGRA2BGR);
    
    Mat grayImage;
    cv::cvtColor(outputMat, grayImage, CV_BGR2GRAY);
    
    size_t validPixelCount = countNonZero(grayImage);
    float percentPixelsValid = (float)validPixelCount/numberOfPixels;
        
    // Do a simple rolling average to soften falling edges
    static float rollingPercentPixels = 0.005;
    if (percentPixelsValid > rollingPercentPixels) {
        rollingPercentPixels = percentPixelsValid;
    } else {
        rollingPercentPixels = 0.65 * percentPixelsValid + 0.45 * rollingPercentPixels;
    }
    
    // If enough of the image is triggered with motion, save the bright moving pixels to aacumMat
    if (rollingPercentPixels >= self.percentOfPixelsMovingThreshold && percentPixelsValid > 0.0)
    {
        self.triggerCount++;
        
        // Accumulate training data
        // imageVector is a n-by-3 matrix with each row the BGR pixel values of the brightly,
        // colored moving region
        Mat imageVector;
        [self convertImage:outputMat toImageVector:imageVector withMask:grayImage];
        
        // Convert from uchar to float since the classification training needs float values
        imageVector.convertTo(imageVector, CV_32FC1);
        
        // Accumulate pixel data from multiple frames before clustering
        if (self.positiveTrainingData.empty()) {
            self.positiveTrainingData = imageVector;
        } else {
            cv::Mat positiveTrainingData = self.positiveTrainingData;
            vconcat(positiveTrainingData, imageVector, positiveTrainingData); // vertically concatenate the pixel data
            self.positiveTrainingData = positiveTrainingData;
        }
        
        // Ring buffer of pixels. Discharge pixels if the buffer grows too large.
        if (self.positiveTrainingData.rows > self.maximumAccumulatedPixels) {
            self.positiveTrainingData = self.positiveTrainingData.rowRange(self.positiveTrainingData.rows - self.maximumAccumulatedPixels, self.positiveTrainingData.rows);
        }
        
        
        // Update our delegate regarding the training process
        // cv::mean returns a 4 element cv::Scalar. We want to 0th element in that scalar.
        float meanRed   = ((cv::mean(self.positiveTrainingData.col(2)))[0])/255.0;
        float meanGreen = ((cv::mean(self.positiveTrainingData.col(1)))[0])/255.0;
        float meanBlue  = ((cv::mean(self.positiveTrainingData.col(0)))[0])/255.0;
        UIColor *meanColor = [UIColor colorWithRed:meanRed green:meanGreen blue:meanBlue alpha:1.0];
        
        float trainingProgress = (float)self.triggerCount/self.triggerCountThreshold;
        
        if ([self.delegate respondsToSelector:@selector(motionTriggeredTrainingModule:didUpdateWithProgress:withEstimatedColor:)]) {
            dispatch_async(dispatch_get_main_queue(), ^(void){
                [self.delegate motionTriggeredTrainingModule:self didUpdateWithProgress:trainingProgress withEstimatedColor:meanColor];
            });
        }
        
        
        // Check if we have seen sustained motion for enough frames. If so, cluster the data to
        // find the most popular cluster.
        // This attempts to find the most dominate cluster to use for training with the idea that
        // it will not train on a person's hand or other background objects that are moving.
        if (self.triggerCount >= self.triggerCountThreshold)
        {
            self.trainingComplete = YES;
            RMVisionTrainingData *trainingDataObject;
            UIColor *clusterColor;
            
            if (self.shouldCluster) {
                [self doKMeansClusterFromMat:self.positiveTrainingData toResultColor:&clusterColor toResultTrainingData:&trainingDataObject];
            } else {
                clusterColor = meanColor;
                trainingDataObject = nil;
            }
            
            if ([self.delegate respondsToSelector:@selector(motionTriggeredTrainingModule:didFinishWithColor:withTrainingData:)]) {
                __weak RMMotionTriggeredColorTrainingModule *weakSelf = self;
                dispatch_async(dispatch_get_main_queue(), ^(void){
                    [weakSelf.delegate motionTriggeredTrainingModule:self didFinishWithColor:clusterColor withTrainingData:trainingDataObject];
                });
            }
            
            // Clear our copy of the training data
            self.positiveTrainingData = cv::Mat();
            self.triggerCount = 0;
        }
    } else {
        // Motion triggered training ended early. Reset!
        self.triggerCount--;

        if (self.triggerCount <= 0) {
            self.triggerCount = 0;
            self.positiveTrainingData = cv::Mat();
        }
        
        float trainingProgress = (float)self.triggerCount/self.triggerCountThreshold;
        
        if ([self.delegate respondsToSelector:@selector(motionTriggeredTrainingModule:didUpdateWithProgress:withEstimatedColor:)]) {
            __weak RMMotionTriggeredColorTrainingModule *weakSelf = self;
            dispatch_async(dispatch_get_main_queue(), ^(void){
                [weakSelf.delegate motionTriggeredTrainingModule:self didUpdateWithProgress:trainingProgress withEstimatedColor:[UIColor clearColor]];
            });
        }
    }
    
}

//------------------------------------------------------------------------------
- (void)processFrame:(const cv::Mat)mat
           videoRect:(CGRect)rect
    videoOrientation:(AVCaptureVideoOrientation)videoOrientation
{
    // Waiting a few frames since the initial frames sometimes are dark or not fully initialized
    self.frameNumber++;
    self.lastFrame = mat;
}

#pragma mark - Training Data

- (void)captureNegativeTrainingData
{
    if (self.vision.videoOutput.sampleBufferCallbackQueue) {
        dispatch_async(self.vision.videoOutput.sampleBufferCallbackQueue, ^{
            if (!self.lastFrame.empty()) {
                cv::Mat lastFrameBGR;
                cvtColor(self.lastFrame, lastFrameBGR, CV_BGRA2BGR);
                
                if (self.negativeTrainingData.empty()) {
                    self.negativeTrainingData = lastFrameBGR;
                }
                else {
                    cv::Mat negativeTrainingData = self.negativeTrainingData;
                    cv::vconcat(negativeTrainingData, lastFrameBGR, negativeTrainingData);
                    self.negativeTrainingData = negativeTrainingData;
                }
            } else {
                double delayInSeconds = 0.1;
                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                    [self captureNegativeTrainingData];
                });
            }
        });
    }
}

-(void)clearNegativeTrainingData
{
    self.negativeTrainingData = cv::Mat();
}

#pragma mark - Helper Functions

- (void)doKMeansClusterFromMat:(cv::Mat)accumMat toResultColor:(UIColor **)color toResultTrainingData:(RMVisionTrainingData **)trainingDataObject
{
    // Build clusters
    TermCriteria criteria = TermCriteria( TermCriteria::EPS+TermCriteria::COUNT, 10, 1.0);
    Mat bestLabels;
    Mat clusterCenters;
    
    kmeans(accumMat, self.numberOfKMeansClusters, bestLabels, criteria, self.kmeansAttempts, KMEANS_PP_CENTERS, clusterCenters);

    // Find the most dominate cluster
    NSArray *modeAndCountArray = [self findModeInVector:bestLabels];
    NSNumber *largestClusterLabel = modeAndCountArray[0];    
    
    // Build vectors from training data from the clusters
    cv::Mat labelMask = (bestLabels == largestClusterLabel.intValue);
    cv::Mat positiveExamples = [self extractRowsFromMat:accumMat withMask:labelMask];

    int negativeResponseLabel = 1;
    int positiveResponseLabel = 2;
    
    cv::Mat negativeExamples;
    [self convertImage:self.negativeTrainingData toImageVector:negativeExamples withMask:cv::Mat()];

    // Convert from uchar to float since the classification training needs float values
    negativeExamples.convertTo(negativeExamples, CV_32FC1);

    cv::Mat trainData;
    cv::vconcat(negativeExamples, positiveExamples, trainData);
    
    // Responses are the class label (either negative or positive)
    cv::Mat responses;
    cv::vconcat(cv::Mat(negativeExamples.rows, 1, CV_32F, Scalar(negativeResponseLabel)),
                cv::Mat(positiveExamples.rows, 1, CV_32F, Scalar(positiveResponseLabel)),
                responses);
    
    // Create the RMVisionTrainingData object
    *trainingDataObject = [[RMVisionTrainingData alloc] init];
    (*trainingDataObject).labels = responses;
    (*trainingDataObject).trainingData = trainData;
    (*trainingDataObject).positiveResponseLabel = positiveResponseLabel;
    (*trainingDataObject).negativeResponseLabel = negativeResponseLabel;

    // Check that the data is in the right form
    assert((*trainingDataObject).labels.type() == CV_32F);
    assert((*trainingDataObject).trainingData.type() == CV_32F);
    
    cv::Scalar clusterRed   = clusterCenters.at<float>(largestClusterLabel.intValue, 2)/255.0;
    cv::Scalar clusterGreen = clusterCenters.at<float>(largestClusterLabel.intValue, 1)/255.0;
    cv::Scalar clusterBlue  = clusterCenters.at<float>(largestClusterLabel.intValue, 0)/255.0;
    
    *color = [UIColor colorWithRed:clusterRed[0]
                             green:clusterGreen[0]
                              blue:clusterBlue[0]
                             alpha:1.0];
}

- (void)convertImage:(const cv::Mat)image
       toImageVector:(cv::Mat &)imageVector
            withMask:(cv::Mat)mask
{
    if (mask.empty()) {
        mask = cv::Mat(image.size(), CV_8UC1, cv::Scalar(255));
    }

    size_t totalPixels = image.rows * image.cols;
    cv::Mat tmp = image.reshape(1, totalPixels);
    cv::Mat maskVector = mask.reshape(1, mask.rows*mask.cols);

    size_t nonZeroCount = cv::countNonZero(maskVector);

    imageVector.create(nonZeroCount, tmp.cols, tmp.type());

    size_t imageVectorRow = 0;
    for (size_t i = 0; i < tmp.rows; i++) {
        if (maskVector.at<uchar>(i)) {
            tmp.row(i).copyTo(imageVector.row(imageVectorRow));
            imageVectorRow++;
        }
    }
}

- (cv::Mat)extractRowsFromMat:(const cv::Mat)mat withMask:(const cv::Mat)mask
{
    int nonZeroCount = cv::countNonZero(mask);
    cv::Mat output(nonZeroCount, mat.cols, mat.type());
    
    size_t outputRow = 0;
    for (size_t i = 0; i < mat.rows; i++) {
        if (mask.at<uchar>(i)) {
            mat.row(i).copyTo(output.row(outputRow));
            outputRow++;
        }
    }
    
    return output;
}

- (NSArray *)findModeInVector:(cv::Mat)vector
{
    double maxValue, minValue;
    cv::minMaxIdx(vector, &minValue, &maxValue);
    
    // Find the largest cluster
    int numberOfBins = (int)maxValue + 1;
    int countInBin[numberOfBins];
    memset(countInBin, 0, sizeof(countInBin));
    
    MatIterator_<int> it = vector.begin<int>();
    
    for ( ; it != vector.end<int>(); it++) {
        countInBin[(int)*it]++;
    }
    
    int binIndex = -1;
    int largestCount = -1;
    for (int i = 0; i < numberOfBins; i++) {
        if (countInBin[i] > largestCount) {
            largestCount = countInBin[i];
            binIndex = i;
        }
    }
    
    NSArray *result = @[@(binIndex), @(largestCount)];
    return result;
}

#pragma mark - Getters / Setters

- (float)brightnessThreshold
{
    return self.notchFilter.brightnessThreshold;
}

- (void)setBrightnessThreshold:(float)brightnessThreshold
{
    self.notchFilter.brightnessThreshold = brightnessThreshold;
}

- (float)saturationThreshold
{
    return self.notchFilter.brightnessThreshold;
}

- (void)setSaturationThreshold:(float)saturationThreshold
{
    self.notchFilter.saturationThreshold = saturationThreshold;
}

- (void)setLowPassFilterStrength:(float)lowPassFilterStrength
{
    _lowPassFilterStrength = lowPassFilterStrength;
    self.motionSegmentation.lowPassFilterStrength = lowPassFilterStrength;
}

@end
