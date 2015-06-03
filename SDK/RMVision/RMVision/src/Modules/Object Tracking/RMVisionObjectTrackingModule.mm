//
//  RMVisionObjectTrackingModule.m
//  RMVision
//
//  Created on 8/28/13.
//  Copyright (c) 2013 Romotive, Inc. All rights reserved.
//

#import "RMVisionObjectTrackingModule.h"
#import "UIImage+OpenCV.h"
#import "RMVision.h"
#import <RMShared.h>
#import "GPUImageNormalBayesFilter.h"
#import "RMNormalBayes.h"
#import "RMOpenCVUtils.h"

#define NUM_FEATURES 3
#define RMLINE_POSITIVE_CLASS 2
#define ADAPTIVE_FLOOR_DEFAULT 0.0005

const static int kNumberOfPixelsPerFrameToReplace = 1000;
const static int kRetrainModuleFramePeriod = 30;
const static int kGrabCutFramePeriod = 5;

using namespace cv;

// Private members
//==============================================================================
@interface RMVisionObjectTrackingModule ()
{
    GPUVector3 lastCoordinate;
    GLfloat adaptiveFloorValue;
    
    dispatch_semaphore_t trainingDataSemaphore;

}

// GPUImage filters
@property (nonatomic) GPUImageRawDataOutput *rawDataOutput;
@property (nonatomic) GPUImageNormalBayesFilter *nbFilter;
@property (nonatomic) GPUImageBrightnessFilter *nopFilter;

@property (nonatomic) GPUImageAverageColor *positionAverageColor;

@property (nonatomic) NormalBayesModel *nbModel;

// OpenCV classifier
@property (nonatomic) RMNormalBayes *classifier;

@property (nonatomic) RMBlob *blobObject;

@property (nonatomic, readwrite) NSString *name;

// Training data properties
@property (nonatomic) int negativeResponseLabel;
@property (nonatomic) int positiveResponseLabel;

@property (nonatomic) RMVisionTrainingData *trainingDataObject;

@property (nonatomic) cv::Mat negativePixels;
@property (nonatomic) cv::Mat positivePixels;
@property (nonatomic) cv::Mat newPositivePixels;

@property (nonatomic) cv::Point2f previousPoint;



// Region of interest
@property (nonatomic) cv::Rect roiRect;
@property (nonatomic) cv::Mat roiMask;


@end

@implementation RMVisionObjectTrackingModule

// Remap the paused property to the GPUImageFilter's property named "enabled"
@synthesize paused = enabled;

// Synthesize the properties from RMVisionModuleProtocol
@synthesize vision = _vision;
@synthesize name = _name;
@synthesize frameNumber = _frameNumber;

#pragma mark - Initialization

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
        
        // Fix the processing resolution and don't depend that RMVision is giving us images at a certain resolution
        float scaleFactor = core.isSlow ? 16.0 : 8.0;
        _processingResolution = CGSizeMake(core.width / scaleFactor, core.height / scaleFactor);
        
        _blobObject = [[RMBlob alloc] init];
        
        _generateVisualization = YES;
        
        // Contours look for the largest blob in the image. Without contours, multiple
        // smaller blobs will all trigger and contribute towards the mean centroid.
        _useContours = YES;
        _previousPoint = cv::Point2f(-1, -1);

        trainingDataSemaphore = dispatch_semaphore_create(1);
        
        adaptiveFloorValue = ADAPTIVE_FLOOR_DEFAULT;
        
        // Initialize the filters
        _positionAverageColor = [[GPUImageAverageColor alloc] init];
        [self addFilter:_positionAverageColor];
        
        _nbFilter = [[GPUImageNormalBayesFilter alloc] init];
        [_nbFilter forceProcessingAtSize:_processingResolution];
        [self addFilter:_nbFilter];
        
        _nopFilter = [[GPUImageBrightnessFilter alloc] init];
        [_nopFilter forceProcessingAtSize:_processingResolution];
        [self addFilter:_nopFilter];
        
        _rawDataOutput = [[GPUImageRawDataOutput alloc] initWithImageSize:_processingResolution resultsInBGRAFormat:YES]; // Will be in RGBA format if resultsInBGRAFormat == NO
        
        
        // Weak self
        __weak RMVisionObjectTrackingModule *weakSelf = self;
        
        /**********************************/
        // Process blocks when using CPU (with OpenCV)
        /**********************************/
        
        [_rawDataOutput setNewFrameAvailableBlock:^{
            
            // Check that the model is ready
            if (weakSelf.nbModel) {
                
                weakSelf.frameNumber = weakSelf.frameNumber + 1;
                GLubyte *outputBytes = [weakSelf.rawDataOutput rawBytesForImage];
                
                cv::Mat outputMat(weakSelf.processingResolution.height, weakSelf.processingResolution.width, CV_8UC4, outputBytes, [weakSelf.rawDataOutput bytesPerRowInOutput]);
                [weakSelf processOutputMat:outputMat];
            }
        }];
        
        /**********************************/
        // Process blocks when using GPU
        /**********************************/
        
        // Initial conditions set for GPU filters
        lastCoordinate.one = 0.5;
        lastCoordinate.two = 0.5;
        [_nbFilter setFloatVec3:lastCoordinate forUniformName:@"lastCoordinate"];
        
        [_positionAverageColor setColorAverageProcessingFinishedBlock:^(CGFloat redComponent, CGFloat greenComponent, CGFloat blueComponent, CGFloat alphaComponent, CMTime frameTime) {
            weakSelf.frameNumber = weakSelf.frameNumber + 1;
            [weakSelf processAverageColorWithRed:redComponent withGreen:greenComponent withBlue:blueComponent withAlpha:alphaComponent withTime:frameTime];
        }];
        
        
        
        // Assemble the filter pipeline

        // Input filters
        // Multiple filters can act as input filters
        
        // The NOP filter has to be listed first since in the nbFilter we need results from that filter.
        // The filters are run in the order listed here!
        self.initialFilters = @[_nopFilter, _nbFilter];
        
        // Setup the internal pipeline
        
        if (_useContours) {
            [_nbFilter addTarget:_rawDataOutput];
        }
        else {
            [_nbFilter addTarget:_positionAverageColor];
            
        }
        
        // Output filter
        // There can only be one
        self.terminalFilter = _nbFilter;
    }
    return self;
}

//------------------------------------------------------------------------------
-(void)shutdown
{
    for (GPUImageOutput *filter in self->filters) {
        if ([filter respondsToSelector:@selector(removeAllTargets)]) {
            [filter removeAllTargets];
        }
    }
}

#pragma mark - Processing new images

/// Process function for incoming image stream
/**
 Processes the incoming frames and classifies each pixel according to the model.
 Depending on if the line is found, this function will call the delegate methods
 for detecting or not detecting a line. It will also call the display debug image
 delegate method so the results can be shown on screen.
 
 @param mat CV_8UC4 BGRA camera image
 */
//------------------------------------------------------------------------------
- (void)processFrame:(const cv::Mat)mat
           videoRect:(CGRect)rect
    videoOrientation:(AVCaptureVideoOrientation)videOrientation
{
    if (self.allowAdaptiveBackgroundUpdates && self.classifier) {
        [self updateTrainingDataFromMatrix:mat];
    }
}

/// Cleans up the line image
/**
 Processes the detected line image and isolates the single largest
 blob. The input image is modified by this function!
 @param image The binary mask image for the detected line
 */
- (vector<vector<cv::Point> >)cleanLineImage:(cv::Mat&)image
{
    vector<vector<cv::Point> > contours;
    vector<Vec4i> hierarchy;
    findContours( image, contours, hierarchy, CV_RETR_EXTERNAL, CV_CHAIN_APPROX_SIMPLE, cv::Point(0, 0) );
    
    vector<double> contourSize;
    vector<float> contourDistance;
    
    // We will judge the contours based on size and distance from contour in the previous frame
    int bestContourIndex = -1;
    float smallestDistance = INFINITY;
    
    
    for (int i = 0; i < contours.size(); i++) {
        
        // Find the area of contour
        double area = contourArea( contours[i],false);
        contourSize.push_back(area);
        
        // Find the distance of the new contour from the last contour
        
        // Find each contour's centroid
        float x = 0;
        float y = 0;
        for (int j = 0; j < contours[i].size(); j++) {
            x += contours[i][j].x;
            y += contours[i][j].y;
        }
        
        x /= contours[i].size();
        y /= contours[i].size();
        
        // If the previous frame had a valid contour
        if (self.previousPoint.x >= 0) {
            // Manhattan distance
            contourDistance.push_back(ABS(x - self.previousPoint.x) + ABS(y - self.previousPoint.y));
        } else {
            // else set all the distances to zero
            contourDistance.push_back(0);
        }
        
        // Pick the contour with the smallest distance but with a non zero area
        // We could do some more complex weighting in the future but this is working pretty well now
        if ( contourSize[i] > 0 && contourDistance[i] < smallestDistance) {
            smallestDistance = contourDistance[i];
            bestContourIndex = i;
        }
        
    }
    
    // Draw the best contour
    image = Mat::zeros(image.size(), image.type());
    
    if (bestContourIndex >= 0) {
        drawContours(image, contours, bestContourIndex, Scalar(UCHAR_MAX), CV_FILLED);
    }
    
    return contours;
}

/// Finds the centroid from a binary mask image
/**
 */
-(CGPoint)findLineCentroidFromBinaryImage:(const cv::Mat&)image
{
    CGPoint centroid;
    
    Mat roi;
    cv::Point cvCentroid;
    
    if (countNonZero(image) > 0)
    {
        cv::Moments m = moments(image, true);
        cv::Point cvCentroid(m.m10/m.m00, m.m01/m.m00);
        
        self.previousPoint = cv::Point2f(cvCentroid.x, cvCentroid.y);

        centroid.x = (float)cvCentroid.x/(image.cols-1) * 2 - 1;
        
        
        centroid.y = (float)cvCentroid.y/(image.rows-1) * 2 - 1;
    }
    else
    {
        centroid.x = NAN;
        centroid.y = NAN;
        
        self.previousPoint = cv::Point2f(-1, -1);

    }
    
    return centroid;
}

//------------------------------------------------------------------------------
-(cv::Point) computeCentroidOfMask:(const cv::Mat&)mask
{
    
    cv::Moments m = moments(mask, true);
    cv::Point centroid(m.m10/m.m00, m.m01/m.m00);
    
    return centroid;
}


//------------------------------------------------------------------------------
-(void)processAverageColorWithRed:(CGFloat)redComponent
                        withGreen:(CGFloat)greenComponent
                         withBlue:(CGFloat)blueComponent
                        withAlpha:(CGFloat)alphaComponent
                         withTime:(CMTime)frameTime
{
    
    if (alphaComponent > 0)
    {
        
        lastCoordinate.one = redComponent / alphaComponent;
        lastCoordinate.two = greenComponent / alphaComponent;
        
        
        if (lastCoordinate.one >= 1.0 || lastCoordinate.one <= 0.0 || lastCoordinate.two >= 1.0 || lastCoordinate.two <= 0.0)
        {
            lastCoordinate.one = 0.5;
            lastCoordinate.two = 0.5;
            adaptiveFloorValue *= 2.0;
            adaptiveFloorValue = fmin(adaptiveFloorValue, 1.0);
            
        }
        else
        {
            adaptiveFloorValue /= 1.1;
            adaptiveFloorValue = fmax(adaptiveFloorValue, ADAPTIVE_FLOOR_DEFAULT);
            
            CGPoint currentTrackingLocation = CGPointMake(lastCoordinate.one, lastCoordinate.two);
            
            // Calculate RMBlob characteristics and normalize for Romo's coordinates
            float x = currentTrackingLocation.x * 2 - 1;
            float y = currentTrackingLocation.y * 2 - 1;
            
            self.blobObject.centroid = CGPointMake(x, y);
            
            self.blobObject.area = alphaComponent;
            self.blobObject.frameNumber = self.frameNumber;
            
            if ([self.delegate respondsToSelector:@selector(objectTrackingModule:didDetectObject:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate objectTrackingModule:self didDetectObject:self.blobObject];
                });
            }
        }
        
        [self.nbFilter setFloatVec3:lastCoordinate forUniformName:@"lastCoordinate"];
        [self.nbFilter setFloat:adaptiveFloorValue forUniformName:@"adaptiveFloorValue"];
    }
    else
    {
        adaptiveFloorValue *= 2.0;
        adaptiveFloorValue = fmin(adaptiveFloorValue, 1.0);
        
        [self.nbFilter setFloat:adaptiveFloorValue forUniformName:@"adaptiveFloorValue"];
        
    }
    
    // Visualization
    if (self.generateVisualization && [self.vision.delegate respondsToSelector:@selector(showDebugImage:)])
    {
        UIImageOrientation debugOrientation = UIImageOrientationUp;
        if (self.vision.camera == RMCamera_Front) {
            debugOrientation = UIImageOrientationUpMirrored;
        }
        
        UIImage *resultUIImage = [self.nbFilter imageFromCurrentlyProcessedOutputWithOrientation:debugOrientation];
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.vision.delegate respondsToSelector:@selector(showDebugImage:)]) {
                [self.vision.delegate showDebugImage:resultUIImage];
            }
        });
    }
    
}

//------------------------------------------------------------------------------
- (void)processOutputMat:(cv::Mat)outputMat
{
    cv::cvtColor(outputMat, outputMat, CV_BGRA2GRAY);
    cv::threshold(outputMat, outputMat, 1, UCHAR_MAX, THRESH_BINARY);
    
    // If a ROI is set, set everything outside of the ROI to zero
    if (!self.roiMask.empty()) {
        outputMat &= self.roiMask;
    }
    
    [self cleanLineImage:outputMat];
    
    // Initialize and populate a new RMBlob object to send out to the delegate
    RMBlob *blobObject = [[RMBlob alloc] init];
    blobObject.centroid = [self findLineCentroidFromBinaryImage:outputMat];
    blobObject.frameNumber = self.frameNumber;
    blobObject.area = (float)cv::countNonZero(outputMat)/(outputMat.cols * outputMat.rows);
    
    // Send to delegates
    __weak RMVisionObjectTrackingModule *weakSelf = self;
    
    if (!std::isnan(blobObject.centroid.x) && !std::isnan(blobObject.centroid.y)) {
        if ([self.delegate respondsToSelector:@selector(objectTrackingModule:didDetectObject:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf.delegate objectTrackingModule:self didDetectObject:blobObject];
            });
        }
    } else {
        if ([self.delegate respondsToSelector:@selector(objectTrackingModuleDidLoseObject:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf.delegate objectTrackingModuleDidLoseObject:self];
            });
        }
    }
    
    if (self.allowAdaptiveForegroundUpdates && self.frameNumber % kGrabCutFramePeriod == 0) {
        [self growTrainingDataWithGrabCut:outputMat];
    }
    
    // Visualization
    if (self.generateVisualization && [self.delegate respondsToSelector:@selector(showDebugImage:)])
    {
        cvtColor(outputMat, outputMat, CV_GRAY2BGRA);
        
        UIImageOrientation debugOrientation = UIImageOrientationUp;
        if (self.vision.camera == RMCamera_Front) {
            debugOrientation = UIImageOrientationUpMirrored;
        }

        UIImage *resultUIImage = [UIImage imageWithCVMat:outputMat scale:1.0 orientation:debugOrientation];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate showDebugImage:resultUIImage];
        });
    }
}

#pragma mark - Training

- (void)trainWithData:(id)data
{
    dispatch_queue_t trainingQueue = dispatch_queue_create("com.romotive.vision.objecttracking.training", NULL);
    dispatch_async(trainingQueue, ^{
        
        if ([data isKindOfClass:[NSArray class]]) {
            [self trainWithArray:(NSArray *)data];
        } else if ([data isKindOfClass:[RMVisionTrainingData class]]) {
            self.trainingDataObject = (RMVisionTrainingData *)data;
            [self trainWithRMVisionTrainingData:(RMVisionTrainingData *)data];
        }
        
    });
}


-(void)trainWithRMVisionTrainingData:(RMVisionTrainingData *)data
{
    // Separate out the training data before training the module
    [self separateTrainingData:data];
    
    // Train the classifier
    if (!self.classifier) {
        
        assert(data.labels.type() == CV_32F);
        assert(data.trainingData.type() == CV_32F);
        
        self.classifier = new RMNormalBayes();
        self.classifier->train(data.trainingData, data.labels);
    } else {
        // Re-train the classifier with additional data
        bool update = true;
        self.classifier->train(data.trainingData, data.labels, Mat(), Mat(), update);
    }
    
    // Create the Normal Bayes model
    self.nbModel = [[NormalBayesModel alloc] init];
    [self populateModel:self.nbModel fromClassifier:self.classifier];
    
    // Initialize the filter
    if (!self.nbFilter) {
        self.nbFilter = [[GPUImageNormalBayesFilter alloc] initWithModel:self.nbModel];
    } else {
        [self.nbFilter setModel:self.nbModel];
    }
    
    [self scalePositiveCovarianceByScaler:data.covarianceScaling];
    
    [self didFinishTraining];
}

-(void)separateTrainingData:(RMVisionTrainingData *)data
{
    self.negativeResponseLabel = data.negativeResponseLabel;
    self.positiveResponseLabel = data.positiveResponseLabel;
    
    cv::Mat negativePixels = cv::Mat(0, data.trainingData.cols, data.trainingData.type());
    cv::Mat positivePixels = cv::Mat(0, data.trainingData.cols, data.trainingData.type());

    // We want to randomize the training data since we are going to be replacing only part of it.
    // By randomizing it, we remove any bias for certain areas of the original training data image.
    std::vector<int> randomizedIndices;
    for (int i = 0; i < data.labels.rows; i++)
    {
        randomizedIndices.push_back(i);
    }
    
    std::random_shuffle(randomizedIndices.begin(), randomizedIndices.end());
    
    for (int i = 0; i < data.labels.rows; i++)
    {
        int randomIndex = randomizedIndices[i];
        int response = (int)data.labels.at<float>(randomIndex);
        
        if (response == data.positiveResponseLabel) {
            positivePixels.push_back(data.trainingData.row(randomIndex));
        } else if (response == data.negativeResponseLabel) {
            negativePixels.push_back(data.trainingData.row(randomIndex));
        }
    }
    
    self.negativePixels = negativePixels;
    self.positivePixels = positivePixels;
    
#ifdef VISION_DEBUG
    NSLog(@"Total positive pixels: %u", positivePixels.rows);
    NSLog(@"Total negative pixels: %u", negativePixels.rows);

#endif
    
}


// Trains line following
// NSArray contains: @[UIImage, UIImage, NSArray]
//      First item is sampled image, second item contains annotations, 3rd item contains an array of UIColors
//------------------------------------------------------------------------------
- (void)trainWithArray:(NSArray *)data
{
    
    // Pull data out of the NSArray
    Mat trainingImage = [ UIImage cvMatWithImage:data[0] ];
    cvtColor(trainingImage, trainingImage, CV_BGRA2BGR);
    
    Mat annotationsImage = [ UIImage cvMatWithImage:data[1] ];
    NSArray *labelArray = data[2];
    
    // Convert user input into a label image
    Mat labelImage = [self extractLabelsFromImage:annotationsImage withLabelArray:labelArray];
    
    // Properly format the training data
    Mat imageVector, labelVector;
    [self buildTrainingVectorFromImage:trainingImage
                        fromLabelImage:labelImage
                         toImageVector:imageVector
                         toLabelVector:labelVector];
    
    
    // Train the classifier
    if (!self.classifier)
    {
        self.classifier = new RMNormalBayes();
        self.classifier->train(imageVector, labelVector);
    }
    else // Re-train the classifier with additional data
    {
        bool update = true;
        self.classifier->train(imageVector, labelVector, Mat(), Mat(), update);
    }
    
    // Create the Normal Bayes model
    self.nbModel = [[NormalBayesModel alloc] init];
    [self populateModel:self.nbModel fromClassifier:self.classifier];
    
    // Initialize the filter
    if (!self.nbFilter) {
        self.nbFilter = [[GPUImageNormalBayesFilter alloc] initWithModel:self.nbModel];
    }
    else {
        [self.nbFilter setModel:self.nbModel];
    }
    
    [self didFinishTraining];
}

//------------------------------------------------------------------------------
- (void)populateModel:(NormalBayesModel *)model fromClassifier:(RMNormalBayes *)classifier
{
    // Store covariance determinates
    
    cv::Mat logDetCovar = cv::Mat(classifier->getC());
    //    model.logDetCovar = (GPUVector3){exp(logDetCovar.at<double>(0)), exp(logDetCovar.at<double>(1)), 0.0};
    model.logDetCovar = (GPUVector3){(float)logDetCovar.at<double>(0), (float)logDetCovar.at<double>(1), 0.0};
    
    
    // Store averages
    //    CvMat** avg = classifier->getAvg();
    //    model.muA = (GPUVector3){avg[0]->data.fl[0], avg[0]->data.fl[1], avg[0]->data.fl[2]};
    //    model.muB = (GPUVector3){avg[1]->data.fl[0], avg[1]->data.fl[1], avg[1]->data.fl[2]};
    
    cv::Mat muA = cv::Mat(classifier->getAvg()[0]);
    model.muA = (GPUVector3){(float)muA.at<double>(0), (float)muA.at<double>(1), (float)muA.at<double>(2)};
    
    cv::Mat muB = cv::Mat(classifier->getAvg()[1]);
    model.muB = (GPUVector3){(float)muB.at<double>(0), (float)muB.at<double>(1), (float)muB.at<double>(2)};
    
    // Store covariances
    // A
    cv::Mat inv_w = cv::Mat(classifier->getInvEigenValues()[0]);
    cv::Mat u = cv::Mat(classifier->getCovRotateMats()[0]);
    cv::Mat w = 1.0/inv_w;
    cv::Mat covar = u.t()*cv::Mat::diag(w)*u;
    
    cv::Mat inv_covar = covar.inv();
    model.invCovarianceA = (GPUMatrix3x3){
        {(float)inv_covar.at<double>(0,0), (float)inv_covar.at<double>(0,1), (float)inv_covar.at<double>(0,2)},
        {(float)inv_covar.at<double>(1,0), (float)inv_covar.at<double>(1,1), (float)inv_covar.at<double>(1,2)},
        {(float)inv_covar.at<double>(2,0), (float)inv_covar.at<double>(2,1), (float)inv_covar.at<double>(2,2)}
    };
    
    // B
    inv_w = cv::Mat(classifier->getInvEigenValues()[1]);
    u = cv::Mat(classifier->getCovRotateMats()[1]);
    w = 1.0/inv_w;
    covar = u.t()*cv::Mat::diag(w)*u;
    
    inv_covar = covar.inv();
    model.invCovarianceB = (GPUMatrix3x3){
        {(float)inv_covar.at<double>(0,0), (float)inv_covar.at<double>(0,1), (float)inv_covar.at<double>(0,2)},
        {(float)inv_covar.at<double>(1,0), (float)inv_covar.at<double>(1,1), (float)inv_covar.at<double>(1,2)},
        {(float)inv_covar.at<double>(2,0), (float)inv_covar.at<double>(2,1), (float)inv_covar.at<double>(2,2)}
    };
    
#ifdef DEBUG
//    std::cout << logDetCovar << std::endl;
//    std::cout << muA << std::endl;
//    std::cout << muB << std::endl;
//    std::cout << covar << std::endl;
//    std::cout << covar << std::endl;
#endif
    
}

//------------------------------------------------------------------------------
- (void)didFinishTraining
{
    dispatch_async(dispatch_get_main_queue(), ^(void){
        if ([self.delegate respondsToSelector:@selector(objectTrackingModuleFinishedTraining:)]) {
            [self.delegate objectTrackingModuleFinishedTraining:self];
        }
    });
}


/// Generates image labels from the user input annotated image
/**
 Generates a label (1, 2, 3, ...) for each of the labels in the labelsArray
 @param image Annotated image from the user
 @return Single channel uchar label image - the same size as the input image
 */
- (cv::Mat)extractLabelsFromImage:(const cv::Mat)image withLabelArray:(const NSArray *)labelArray
{
    // Check that we have an BGRA input image
    assert(image.type() == CV_8UC4);
    
    Mat labelImage(image.size(), CV_32FC1);
    labelImage = Scalar::all(0.0);
    
    
    // For each label, iterate through the image and create a corresponding labelImage with the label value at the location
    int labelIndex = 1;
    int totalLabelCount = 0;
    
    for (UIColor *color in labelArray)
    {
        // Determine RGB color for each label
        CGFloat red, green, blue;
        [color getRed:&red green:&green blue:&blue alpha:nil];
        
        // UIColor components range are from 0.0 to 1.0. Need to scale;
        uchar ucharRed = red * 255;
        uchar ucharGreen = green * 255;
        uchar ucharBlue = blue * 255;
        
        // Iterate through the input image to find this RGB color
        MatIterator_<float> labelIt = labelImage.begin<float>();
        MatConstIterator_<Vec4b> it  = image.begin<Vec4b>();
        MatConstIterator_<Vec4b> end = image.end<Vec4b>();
        
        int labelCount = 0;
        
        for(; it != end; ++it)
        {
            if ( (*it)[0] == ucharBlue && (*it)[1] == ucharGreen && (*it)[2] == ucharRed )
            {
                *labelIt = (float)labelIndex;
                labelCount++;
            }
            
            labelIt++;
        }
        
        totalLabelCount += labelCount;
        
        labelIndex++;
    }
    
    assert(countNonZero(labelImage) == totalLabelCount);
    
    return labelImage;
}


/// Builds training vectors from the raw image and label image
/**
 Prepares the data for training the classifier by converting it into the correct formats
 @param image 2D raw BGRA image
 @param label 2D label image
 @param imageVector Nx4 matrix with each row as a training example
 @param labelVector Nx1 matrix with each row as a label for the corresponding training example in imageVector
 */
//------------------------------------------------------------------------------
- (void)buildTrainingVectorFromImage:(const cv::Mat)image
                      fromLabelImage:(const cv::Mat)labelImage
                       toImageVector:(cv::Mat &)imageVector
                       toLabelVector:(cv::Mat &)labelVector
{
    
    size_t validLabelCount = countNonZero(labelImage);
    
    imageVector.create(validLabelCount, 1, CV_8UC(NUM_FEATURES));
    labelVector.create(validLabelCount, 1, CV_32FC1);
    
    assert(image.type() == CV_8UC(NUM_FEATURES));
    assert(labelImage.type() == CV_32FC1);
    
    // Iterate through the label image and save corresponding pixel data from the training image
    
    // Input
    MatConstIterator_<float> it = labelImage.begin<float>();
    MatConstIterator_<float> end = labelImage.end<float>();
    MatConstIterator_< Vec<uchar, NUM_FEATURES> > imageIt = image.begin< Vec<uchar, NUM_FEATURES> >();
    
    // Output
    MatIterator_< Vec<uchar, NUM_FEATURES> > trainingImageIt = imageVector.begin< Vec<uchar, NUM_FEATURES> >();
    MatIterator_<float> labelVectorIt = labelVector.begin<float>();
    
    while (it != end)
    {
        if (*it != 0)
        {
            *labelVectorIt = *it;
            *trainingImageIt = *imageIt;
            
            labelVectorIt++;
            trainingImageIt++;
        }
        
        imageIt++;
        it++;
    }
    
    
    // Reshape and convert the image vector
    if (imageVector.isContinuous())
    {
        // Convert imageVector from 4 channel to 1 channel with BGRA values on each column
        imageVector = imageVector.reshape(1,validLabelCount);
        
        // Convert from uchar to float since the classification training needs float values
        imageVector.convertTo(imageVector, CV_32FC1);
    }
}

#pragma mark - Adaptive training

-(void)updateTrainingDataFromMatrix:(cv::Mat)image
{
    // Don't do anything if we haven't train the classifier yet
    if (!self.classifier) {
        return;
    }

    cv::Mat negativePixels = self.negativePixels;
    
    for (int i = 0; i < kNumberOfPixelsPerFrameToReplace; i++) {
        int replacementRowNumber = arc4random_uniform(negativePixels.rows/2); // Divide by two since we want to save a portion of the original data
        
        cv::Vec4b negativePixel = image.at<Vec4b>(arc4random_uniform(image.rows), arc4random_uniform(image.cols));
        
        negativePixels.at<float>(replacementRowNumber,0) = negativePixel[0];
        negativePixels.at<float>(replacementRowNumber,1) = negativePixel[1];
        negativePixels.at<float>(replacementRowNumber,2) = negativePixel[2];

    }
    
    self.negativePixels = negativePixels;
    
    if (self.frameNumber % kRetrainModuleFramePeriod == 0) {
        
        dispatch_queue_t lowPriorityQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
        __weak RMVisionObjectTrackingModule *weakSelf = self;
        dispatch_async(lowPriorityQueue, ^{
            
            // Semaphore is used. Return immediately
            if (dispatch_semaphore_wait(trainingDataSemaphore, DISPATCH_TIME_NOW)) {
                return;
            }
            
            cv::Mat labels;
            vconcat(cv::Mat(weakSelf.positivePixels.rows, 1, CV_32F, cv::Scalar::all(weakSelf.positiveResponseLabel)),
                    cv::Mat(weakSelf.negativePixels.rows, 1, CV_32F, cv::Scalar::all(weakSelf.negativeResponseLabel)),
                    labels);
            
            cv::Mat trainingData;
            vconcat(weakSelf.positivePixels,
                    weakSelf.negativePixels,
                    trainingData);
            
            // Save the training data
            weakSelf.trainingDataObject.trainingData = trainingData;
            weakSelf.trainingDataObject.labels = labels;
            
            weakSelf.classifier->train(trainingData, labels);
            [weakSelf populateModel:weakSelf.nbModel fromClassifier:weakSelf.classifier];
            [weakSelf.nbFilter setModel:weakSelf.nbModel];
            
            // Done using the semaphore. Let GCD know that it can be used again.
            dispatch_semaphore_signal(trainingDataSemaphore);
            
        });
    }
    
}

-(void)growTrainingDataWithGrabCut:(cv::Mat)outputMat
{
    // Erode the outputMat from Normal Bayes labeling
    // Erosion helps to remove any pixels on the edge of the object that might cause problems
    int kernelSize = 1;
    cv::Mat kernel = getStructuringElement( cv::MORPH_RECT,
                                           cv::Size( 2*kernelSize + 1, 2*kernelSize+1 ),
                                           cv::Point( kernelSize, kernelSize ) );
    
    cv::Mat mask;
    erode(outputMat, mask, kernel);
    int remainingMaskPixels = countNonZero(mask);
    
    if (remainingMaskPixels > 4) {
        
        // Pull out the raw image for processing
        // Orientation should not be mirrored since our outputMat is not mirrored either
        UIImage *rawImage = [self.nopFilter imageFromCurrentlyProcessedOutputWithOrientation:UIImageOrientationUp];
        cv::Mat rawMat = [UIImage cvMatWithImage:rawImage];
        cv::cvtColor(rawMat, rawMat, CV_BGRA2BGR);

        cv::threshold(mask, mask, 127, GC_FGD, THRESH_BINARY);
        
        // Set unlabeled pixels to "probably background"
        for( int i = 0; i < mask.elemSize()*mask.rows*mask.cols; ++i)
        {
            if (mask.data[i] < 0.5) {
                mask.data[i] = GC_PR_BGD;
            }
        }
        
        // Perform 2 iterations of grabcut
        cv::Mat bgdModel, fgdModel;
        int iterCount = 1;
        
        cv::grabCut(rawMat, mask, self.roiRect, bgdModel, fgdModel, iterCount, GC_INIT_WITH_MASK );
        cv::grabCut(rawMat, mask, self.roiRect, bgdModel, fgdModel, iterCount );
        
        // Pull out the pixels that are now labeled as foreground to use to retrain the model
        for( int i = 0; i < mask.elemSize()*mask.total(); ++i)
        {
            if (mask.data[i] == GC_PR_FGD) {
                mask.data[i] = UCHAR_MAX;
            } else {
                mask.data[i] = 0;
            }
        }
        
        // Vectorize the matrix
        cv::Mat additionalPositivePixels;
        [RMOpenCVUtils convertImage:rawMat toImageVector:additionalPositivePixels withMask:mask];
        
        // If we have valid pixels to use, retrain
        if (additionalPositivePixels.rows > 0) {
            
            // Need to convert pixels to float type
            additionalPositivePixels.convertTo(additionalPositivePixels, CV_32FC1);
            
            // Run on a low priority queue and update the model
            dispatch_queue_t lowPriorityQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
            __weak RMVisionObjectTrackingModule *weakSelf = self;
            dispatch_async(lowPriorityQueue, ^{
                
                // Semaphore is used. Return immediately
                if (dispatch_semaphore_wait(trainingDataSemaphore, DISPATCH_TIME_NOW)) {
                    return;
                }
                
                // Original training data
                cv::Mat labels;
                vconcat(cv::Mat(weakSelf.positivePixels.rows, 1, CV_32F, cv::Scalar::all(weakSelf.positiveResponseLabel)),
                        cv::Mat(weakSelf.negativePixels.rows, 1, CV_32F, cv::Scalar::all(weakSelf.negativeResponseLabel)),
                        labels);
                
                cv::Mat trainingData;
                vconcat(weakSelf.positivePixels,
                        weakSelf.negativePixels,
                        trainingData);
                
                
                
                // Add additional data
                if (self.newPositivePixels.rows > 0) {
                    cv::Mat newPositivePixels;
                    vconcat(additionalPositivePixels,
                            weakSelf.newPositivePixels,
                            newPositivePixels);
                    
                    
                    // Allow new training data but only 1/10 the size of the original data
                    const int maxNewPositivePixelSize = MIN(self.positivePixels.rows * 0.1, 1000);
                    
                    if (newPositivePixels.rows > maxNewPositivePixelSize) {
                        weakSelf.newPositivePixels = newPositivePixels.rowRange(0, maxNewPositivePixelSize);
                    } else {
                        weakSelf.newPositivePixels = newPositivePixels;
                    }
                    
                } else {
                    // First time through.. Just copy the pixels in
                    weakSelf.newPositivePixels = additionalPositivePixels;
                }
                
                
                
                // Concatinate onto the training and label vector
                vconcat(labels,
                        cv::Mat(weakSelf.newPositivePixels.rows, 1, CV_32F, cv::Scalar::all(weakSelf.positiveResponseLabel)),
                        labels);
                
                vconcat(trainingData,
                        weakSelf.newPositivePixels,
                        trainingData);
                
                
                
                // Save the training data
                weakSelf.trainingDataObject.trainingData = trainingData;
                weakSelf.trainingDataObject.labels = labels;
                
                weakSelf.classifier->train(trainingData, labels);
                [weakSelf populateModel:weakSelf.nbModel fromClassifier:weakSelf.classifier];
                [weakSelf.nbFilter setModel:weakSelf.nbModel];
                
                // Done using the semaphore. Let GCD know that it can be used again.
                dispatch_semaphore_signal(trainingDataSemaphore);
                
            });
        }
        
    }
}

#pragma mark - Adjustments

-(void)scalePositiveCovarianceByScaler:(float)scaler
{
    [self.nbFilter scaleCovarianceBy:scaler];
}

#pragma mark - Accessors

// Threadsafe accessorer for training data object
-(RMVisionTrainingData *)copyOfTrainingData
{
    dispatch_semaphore_wait(trainingDataSemaphore, DISPATCH_TIME_FOREVER);
    RMVisionTrainingData *data = [self.trainingDataObject copy];
    dispatch_semaphore_signal(trainingDataSemaphore);
    
    return data;
}

-(void)setRoi:(CGRect)roi{
    
    CGFloat x = roi.origin.x;
    CGFloat y = roi.origin.y;
    
    CGFloat width = roi.size.width;
    CGFloat height = roi.size.height;
    
    x = CLAMP(-1.0, x, 1.0);
    y = CLAMP(-1.0, y, 1.0);
    
    width = CLAMP(0.0, width, 1.0 - x);   // 0.0 to 2.0
    height = CLAMP(0.0, height, 1.0 - y); // 0.0 to 2.0
    
    _roi = CGRectMake(x, y, width, height);
    
    // Convert from Romo coordinates to pixel coordinates
    _roiRect = cv::Rect((x + 1.0)/2.0 * _processingResolution.width, (y + 1.0)/2.0 * _processingResolution.height, width/2.0 * _processingResolution.width, height/2.0 * _processingResolution.height);
    
    _roiMask = cv::Mat(_processingResolution.height, _processingResolution.width, CV_8UC1, cv::Scalar::all(0));
    _roiMask(_roiRect) = UCHAR_MAX; // Set everything inside the mask to UCHAR_MAX
    

}

@end
