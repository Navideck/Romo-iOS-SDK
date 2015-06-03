//
//  RMVisionObjectTrackTests.mm
//  RMVision
//
//  Created on 10/24/13.
//  Copyright (c) 2013 Romotive, Inc. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "RMVision.h"
#import "RMVisionModuleProtocol.h"
#import "RMVision_Internal.h"
#import "RMVisionTestHelpers.h"
#import "RMVisionObjectTrackingModule.h"
#import "RMVisionObjects.h"

#import "GPUImage.h"
#import "GPUImageRawDataInput+RMAdditions.h"

static const float kErrorTolerance = 0.26;

@interface RMVisionObjectTrackTests : SenTestCase <RMVisionDelegate, RMVisionObjectTrackingModuleDelegate>

@property (nonatomic) UIImageView *visualizationView;
@property (atomic) BOOL waitingForFrame;
@property (atomic) BOOL waitingForDebugImage;
@property (atomic) BOOL trainingFinished;

@property (nonatomic) RMVision *vision;
@property (nonatomic) RMVisionObjectTrackingModule *objectTrackingModule;
@property (nonatomic) RMBlob *measuredBlob;

@property (nonatomic) unsigned int width;
@property (nonatomic) unsigned int height;

@end

@implementation RMVisionObjectTrackTests

- (void)setUp
{
    [super setUp];
    
    self.visualizationView = [[UIImageView alloc] initWithFrame:[[[UIApplication sharedApplication] delegate] window].rootViewController.view.bounds];
    [[[[UIApplication sharedApplication] delegate] window].rootViewController.view addSubview:self.visualizationView];
    
    self.trainingFinished = NO;
    
    // Start vision
    self.vision = [[RMVision alloc] initWithCamera:RMCamera_Front];
    self.vision.delegate = self;
    
    self.width = self.vision.width;
    self.height = self.vision.height;

}

- (void)tearDown
{
    // Deactivate all modules and stop capturing
    [self.vision deactivateAllModules];
    
    __block BOOL visionRunning = YES;
    [self.vision stopCaptureWithCompletion:^(BOOL didSuccessfullyStop) {
        visionRunning = self.vision.isRunning;
    }];
    
    WaitWhile(visionRunning);
    self.vision = nil;
    
    [super tearDown];
}

#pragma mark - Tests

- (void)testColorTrackObjectRandomJumps
{
    // Load image of color to track
    UIImage *positiveExamplesUIImage = [UIImage imageNamed:@"green_ball_cropped"];  // Image must be in the Images.xcassets for this to work
    
    [self trainTrackingModuleWithPositiveImage:positiveExamplesUIImage withNegativeImage:Nil];

    // Generate test matrix
    cv::Mat testMat(self.height, self.width, CV_8UC4, cv::Scalar::all(1));
    CGRect videoRect = CGRectMake(0, 0, self.width, self.height);
    
    cv::Scalar ballColor(115,242,115,255); // BGRA

    
    cv::Point centroids[5] = {cv::Point(testMat.cols / 4, testMat.rows / 4),
                              cv::Point(testMat.cols * 3 / 4, testMat.rows / 4),
                              cv::Point(testMat.cols / 4, testMat.rows * 3 / 4),
                              cv::Point(testMat.cols * 3 / 4, testMat.rows * 3 / 4),
                              cv::Point(testMat.cols / 2, testMat.rows / 2)};
    // Test
    for (int i = 0; i < 5; i++) {
        
        // Clear the matrix with random values or zeros
        testMat = cv::Mat(testMat.rows, testMat.cols, testMat.type(), cv::Scalar(0,0,0,255));
        
        // Draw a green circle
        cv::Point centroid = centroids[i];
        
        int radius = self.width/8;
        drawFilledCircle(testMat, centroid, radius, ballColor);
        
        // Process the frame

        self.waitingForFrame = YES;
        self.waitingForDebugImage = YES;

        [self.vision processFrame:testMat videoRect:videoRect videoOrientation:AVCaptureVideoOrientationPortrait modules:[NSSet setWithObject:self.objectTrackingModule]];
        
        WaitWhile(self.waitingForFrame);
        
        
        // Generate ground truth RMBlob
        RMBlob *trueBlob = [[RMBlob alloc] init];
        
        trueBlob.frameNumber = i + 1;
        trueBlob.area = (float)radius*radius*M_PI / (testMat.cols * testMat.rows);
        trueBlob.centroid = CGPointMake(((float)centroid.x / testMat.cols - 0.5) * 2.0,
                                        ((float)centroid.y / testMat.rows - 0.5) * 2.0);
        
        
        BOOL blobsAreEqual = [trueBlob isApproximatelyEqual:self.measuredBlob withTolerance:kErrorTolerance];

        STAssertTrue(blobsAreEqual, @"Blobs not equal");
    }
    
}

- (void)testColorTrackMovingObject
{
    // Load image of color to track
    UIImage *positiveExamplesUIImage = [UIImage imageNamed:@"green_ball_cropped"];  // Image must be in the Images.xcassets for this to work

    [self trainTrackingModuleWithPositiveImage:positiveExamplesUIImage withNegativeImage:Nil];
    
    // Generate test matrix
    cv::Mat testMat(self.height, self.width, CV_8UC4, cv::Scalar::all(1));
    CGRect videoRect = CGRectMake(0, 0, self.width, self.height);
    
    cv::Scalar ballColor(115,242,115,255); // BGRA
    
    
    // Test
    const int testIterations = 100;
    
    const int stepSize = 50;
    int walkingX = testMat.rows/2;
    int walkingY = testMat.cols/2;
    
    int radius = testMat.cols/8;
    const int radiusStepSize = 16;
    const int minRadius = 32;
    const int maxRadius = testMat.cols/2;

    for (int i = 0; i < testIterations; i++) {
        
        // Clear the matrix with random values or zeros
        testMat = cv::Mat(testMat.rows, testMat.cols, testMat.type(), cv::Scalar(0,0,0,255));

        walkingX += arc4random_uniform(2*stepSize+1) - stepSize;
        walkingY += arc4random_uniform(2*stepSize+1) - stepSize;
        radius += arc4random_uniform(2*radiusStepSize+1) - radiusStepSize;
        
        // Checks on the size and location of the tracked object
        radius = MAX(minRadius, MIN(maxRadius, radius));
        walkingX = MAX(radius, MIN(testMat.cols - radius - 1, walkingX));
        walkingY = MAX(radius, MIN(testMat.rows - radius - 1, walkingX));
        
        // Draw a green circle
        cv::Point centroid = cv::Point(walkingX, walkingY);
        
        drawFilledCircle(testMat, centroid, radius, ballColor);
        
        // Process the frame
        
        self.waitingForFrame = YES;
        self.waitingForDebugImage = YES;
        
        [self.vision processFrame:testMat videoRect:videoRect videoOrientation:AVCaptureVideoOrientationPortrait modules:[NSSet setWithObject:self.objectTrackingModule]];
        
        WaitWhile(self.waitingForFrame);
        
        
        // Generate ground truth RMBlob
        RMBlob *trueBlob = [[RMBlob alloc] init];
        
        trueBlob.frameNumber = i + 1;
        trueBlob.area = (float)radius*radius*M_PI / (testMat.cols * testMat.rows);
        trueBlob.centroid = CGPointMake(((float)centroid.x / testMat.cols - 0.5) * 2.0,
                                        ((float)centroid.y / testMat.rows - 0.5) * 2.0);
        
        
        BOOL blobsAreEqual = [trueBlob isApproximatelyEqual:self.measuredBlob withTolerance:kErrorTolerance];
        
        STAssertTrue(blobsAreEqual, @"Blobs not equal");
    }
    
}

#pragma mark - Helper methods

- (void)trainTrackingModuleWithPositiveImage:(UIImage *)positiveImage withNegativeImage:(UIImage *)negativeImage
{
    // Generate training object
    RMVisionTrainingData *trainingDataObject = [[RMVisionTrainingData alloc] initWithPositiveImage:positiveImage withNegativeExamplesImage:negativeImage];
    
    // Start and train vision module
    self.objectTrackingModule = [[RMVisionObjectTrackingModule alloc] initWithVision:self.vision];
    self.objectTrackingModule.delegate = self;
    [self.objectTrackingModule trainWithData:trainingDataObject];
    [self.vision activateModule:self.objectTrackingModule];
    
    WaitWhile(!self.trainingFinished);
}

void drawFilledCircle(cv::Mat &img, cv::Point center, int radius, cv::Scalar color )
{
    int thickness = -1;
    int lineType = 8;

    cv::circle( img,
               center,
               radius,
               color,
               thickness,
               lineType,
               0);
}

#pragma mark - Test Delegates

- (void)objectTrackingModule:(RMVisionObjectTrackingModule *)module didDetectObject:(RMBlob *)object
{
    self.waitingForFrame = NO;
    self.measuredBlob = object;
}

- (void)objectTrackingModuleDidLoseObject:(RMVisionObjectTrackingModule *)module
{
    self.waitingForFrame = NO;
}

-(void)showDebugImage:(UIImage *)debugImage
{
    self.visualizationView.image = debugImage;
    self.waitingForDebugImage = NO;
}

- (void)objectTrackingModuleFinishedTraining:(RMVisionObjectTrackingModule *)module
{
    self.trainingFinished = YES;
}

@end
