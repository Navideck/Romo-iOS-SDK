//
//  LineTrainingBenchmarks.mm
//  RMVision
//
//  Created on 12/2/13.
//  Copyright (c) 2013 Romotive, Inc. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "RMVision.h"
#import "RMVisionModuleProtocol.h"
#import "RMVisionTestHelpers.h"
#import "RMVisionNaiveLineTrainingModule.h"
#import "RMVisionObjects.h"
#import "UIImage+OpenCV.h"
#import "RMOpenCVUtils.h"

static const float kMinimumPrecision = 0.9;
static const float kMinimumRecall = 0.6;

@interface LineTrainingBenchmarks : SenTestCase <RMVisionDelegate, RMVisionNaiveLineTrainingModuleDelegate>

@property (nonatomic) UIImageView *visualizationView;
@property (atomic) BOOL waitingForFrame;
@property (atomic) BOOL waitingForDebugImage;
@property (atomic) BOOL trainingFinished;

@property (nonatomic) RMVision *vision;
@property (nonatomic) RMVisionNaiveLineTrainingModule *trainingModule;

@property (nonatomic) UIImage *resultUIImage;

@end

@implementation LineTrainingBenchmarks

- (void)setUp
{
    [super setUp];
    
    self.visualizationView = [[UIImageView alloc] initWithFrame:[[[UIApplication sharedApplication] delegate] window].rootViewController.view.bounds];
    [[[[UIApplication sharedApplication] delegate] window].rootViewController.view addSubview:self.visualizationView];
    
    self.vision = [[RMVision alloc] initWithCamera:RMCamera_Front andQuality:RMCameraQuality_Low] ;
    self.vision.delegate = self;
    
    self.trainingModule = [[RMVisionNaiveLineTrainingModule alloc] initWithVision:self.vision];
    self.trainingModule.delegate = self;
    
    self.trainingFinished = NO;
}

- (void)tearDown
{
    // Deactivate all modules and stop capturing
    [self.vision deactivateAllModules];
    
    __block BOOL visionRunning = YES;
    [self.vision stopCaptureWithCompletion:^(BOOL isRunning) {
        visionRunning = isRunning;
    }];
    
    WaitWhile(visionRunning);
    self.vision = nil;
    
    [super tearDown];
}

- (void)testNaiveLineTraining
{
    // Training image
    UIImage *trainingUIImage = [UIImage imageNamed:@"line_training"];  // Image must be in the Images.xcassets for this to work
    STAssertNotNil(trainingUIImage, @"trainingUIImage is nil");
    
    UIImage *groundTruthUIImage = [UIImage imageNamed:@"line_training_ground_truth"];  // Image must be in the Images.xcassets for this to work
    STAssertNotNil(groundTruthUIImage, @"groundTruthUIImage is nil");
    
    self.trainingModule.inputImage = trainingUIImage;
    UIColor *averageColor;
    UIImage *tmpImage;
    
    self.waitingForFrame = YES;
    [self.trainingModule getTrainedColor:&averageColor withOutputImage:&tmpImage];
    WaitWhile(self.waitingForFrame);
    
    // Compare the algorithm results to the labeled ground truth image
    cv::Mat resultMat = [UIImage cvMatWithImage:self.resultUIImage];

    cv::Mat groundTruthMat = [UIImage cvMatWithImage:groundTruthUIImage];
    
    cv::resize(resultMat, resultMat, groundTruthMat.size());
    
    cv::Mat confusionMatrix = [self compareResultImage:resultMat toGroundTruthImage:groundTruthMat];
    
    float precision = (float)confusionMatrix.at<int>(0,0) / (confusionMatrix.at<int>(0,0) + confusionMatrix.at<int>(1,0));
    float recall = (float)confusionMatrix.at<int>(0,0) / (confusionMatrix.at<int>(0,0) + confusionMatrix.at<int>(0,1));
    
    STAssertTrue(precision >= kMinimumPrecision, @"Precision is below threshold");
    STAssertTrue(recall >= kMinimumRecall, @"Recall is below threshold");

    // Hardcode the expected confusion matrix to check for algorithm changes
    cv::Mat expectedConfusionMatrix;
    
    if (self.vision.isSlow) {
        expectedConfusionMatrix = (cv::Mat_<int>(2,2)  <<
                                   3723, 1032,
                                   309, 96312);
    } else {
        expectedConfusionMatrix = (cv::Mat_<int>(2,2)  <<
                                   3045, 1710,
                                   32, 96589);
    }
    
    STAssertTrue(matIsEqual(confusionMatrix, expectedConfusionMatrix), @"Confusion matrix NOT equal to the expected confusion matrix");
    
}

-(cv::Mat)compareResultImage:(cv::Mat)resultImage toGroundTruthImage:(cv::Mat)groundTruthImage
{
    if (resultImage.channels() == 4) {
        cv::cvtColor(resultImage, resultImage, CV_BGRA2GRAY);
    }
    
    if (groundTruthImage.channels() == 4) {
        cv::cvtColor(groundTruthImage, groundTruthImage, CV_BGRA2GRAY);
    }
    
    cv::threshold(resultImage, resultImage, 0.5, UCHAR_MAX, cv::THRESH_BINARY);
    cv::threshold(groundTruthImage, groundTruthImage, 0.5, UCHAR_MAX, cv::THRESH_BINARY);

    cv::Mat truePositiveMat, falsePositiveMat;
    cv::Mat trueNegativeMat, falseNegativeMat;
    
    cv::multiply(resultImage, groundTruthImage, truePositiveMat);
    cv::compare(resultImage, groundTruthImage, falsePositiveMat, cv::CMP_GT);          // greater than
    cv::compare(resultImage, groundTruthImage, falseNegativeMat, cv::CMP_LT);          // less than
    cv::multiply((255 - resultImage), (255 - groundTruthImage), trueNegativeMat);      // equal
    
    
    int truePositive = cv::countNonZero(truePositiveMat);
    int falsePositive = cv::countNonZero(falsePositiveMat);
    int falseNegative = cv::countNonZero(falseNegativeMat);
    int trueNegative = cv::countNonZero(trueNegativeMat);
    
    // Make sure that we are not under or over counting somewhere
    int totalClassifiedPixels = truePositive + falsePositive + falseNegative + trueNegative;
    int totalPixelsInImage = resultImage.total();
    STAssertEquals(totalClassifiedPixels, totalPixelsInImage, @"Total pixels classified NOT equal to total pixels in the image");
    
    cv::Mat confusionMatrix = (cv::Mat_<int>(2,2)  <<
                               truePositive, falseNegative,
                               falsePositive, trueNegative);


    // Please retain for future debugging
//    std::cout << "Confusion matrix" << std::endl;
//    std::cout << "\t\tGuess:" << std::endl;
//    std::cout << "\t\tt \t\tf" << std::endl;
//    std::cout << "TRUE \t" << truePositive << "\t\t" << falseNegative << std::endl;
//    std::cout << "FALSE \t" << falsePositive << "\t\t" << trueNegative << std::endl;
//    
//    float precision = (float)confusionMatrix.at<int>(0,0) / (confusionMatrix.at<int>(0,0) + confusionMatrix.at<int>(1,0));
//    float recall = (float)confusionMatrix.at<int>(0,0) / (confusionMatrix.at<int>(0,0) + confusionMatrix.at<int>(0,1));
//    
//    NSLog(@"Precision: %f", precision);
//    NSLog(@"Recall: %f", recall);

    return confusionMatrix;
}

#pragma mark - Delegates

-(void)showDebugImage:(UIImage *)debugImage
{
    
}

-(void)naiveLineTrainingModule:(RMVisionNaiveLineTrainingModule *)module didFinishWithColor:(UIColor *)color withTrainingData:(RMVisionTrainingData *)trainingData
{
    
}

-(void)module:(RMVisionNaiveLineTrainingModule *)module didFinishWithLabeledImage:(UIImage *)labeledImage
{
    self.waitingForFrame = NO;
    self.resultUIImage = labeledImage;
}

@end
