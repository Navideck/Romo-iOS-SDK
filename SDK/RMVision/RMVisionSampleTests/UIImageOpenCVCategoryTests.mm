//
//  UIImageOpenCVCategoryTests.m
//  RMVision
//
//  Created on 11/22/13.
//  Copyright (c) 2013 Romotive, Inc. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "UIImage+OpenCV.h"
#import "RMOpenCVUtils.h"

@interface UIImageOpenCVCategoryTests : SenTestCase

@property (nonatomic) unsigned int testImageHeight;
@property (nonatomic) unsigned int testImageWidth;

@end

@implementation UIImageOpenCVCategoryTests

- (void)setUp
{
    [super setUp];
    // Put setup code here; it will be run once, before the first test case.

    // Require a minimum sized image
    self.testImageHeight = arc4random_uniform(256) + 3;
    self.testImageWidth = arc4random_uniform(256) + 3;    
}

- (void)tearDown
{
    // Put teardown code here; it will be run once, after the last test case.
    [super tearDown];
}

#pragma mark - Tests

- (void)testGrayImage
{
    cv::Mat inputImage(self.testImageHeight, self.testImageWidth, CV_8UC1);

    cv::randu(inputImage, cv::Scalar(0), cv::Scalar::all(256));
    
    bool matEqualToSelf = matIsEqual(inputImage, inputImage);
    STAssertTrue(matEqualToSelf, @"inputImage is not equal to itself");

    UIImage *tmpUIImage = [UIImage imageWithCVMat:inputImage];
    STAssertNotNil(tmpUIImage, @"nil result for conversion to UIImage");
    
    cv::Mat outputImage = [UIImage cvMatWithImage:tmpUIImage];
    cv::cvtColor(outputImage, outputImage, CV_BGRA2GRAY);
    
    bool isEqual = matIsEqual(inputImage, outputImage);
    STAssertTrue(isEqual, @"Nil result for conversion to UIImage");
}

- (void)testGrayImageROI
{
    cv::Mat fullImage(self.testImageHeight, self.testImageWidth, CV_8UC1);
    
    cv::randu(fullImage, cv::Scalar(0), cv::Scalar::all(256));
    
    cv::Rect roiRect(1, 1, self.testImageWidth - 1, self.testImageHeight - 1);
    cv::Mat roiImage = fullImage(roiRect);
    
    STAssertTrue(roiImage.isSubmatrix(), @"roiImage should be a submatrix");

    bool matEqualToSelf = matIsEqual(roiImage, roiImage);
    STAssertTrue(matEqualToSelf, @"roiImage is not equal to itself");
    
    UIImage *tmpUIImage = [UIImage imageWithCVMat:roiImage];
    STAssertNotNil(tmpUIImage, @"nil result for conversion to UIImage");
    
    cv::Mat outputImage = [UIImage cvMatWithImage:tmpUIImage];
    cv::cvtColor(outputImage, outputImage, CV_BGRA2GRAY);
    
    bool isEqual = matIsEqual(roiImage, outputImage);
    STAssertTrue(isEqual, @"Input and output images are not equal");
}

- (void)testBGRColorImage
{
    cv::Mat inputImage(self.testImageHeight, self.testImageWidth, CV_8UC3);
    
    cv::randu(inputImage, cv::Scalar(0,0,0), cv::Scalar::all(256));
    
    bool matEqualToSelf = matIsEqual(inputImage, inputImage);
    STAssertTrue(matEqualToSelf, @"inputImage is not equal to itself");
    
    UIImage *tmpUIImage = [UIImage imageWithCVMat:inputImage];
    STAssertNotNil(tmpUIImage, @"nil result for conversion to UIImage");
    
    cv::Mat outputImage = [UIImage cvMatWithImage:tmpUIImage];
    cv::cvtColor(outputImage, outputImage, CV_BGRA2BGR);
    
    bool isEqual = matIsEqual(inputImage, outputImage);
    STAssertTrue(isEqual, @"Input and output images are not equal");
}

- (void)testBGRColorImageROI
{
    cv::Mat fullImage(self.testImageHeight, self.testImageWidth, CV_8UC3);
    cv::randu(fullImage, cv::Scalar(0,0,0), cv::Scalar::all(256));
    
    cv::Rect roiRect(1, 1, self.testImageWidth - 1, self.testImageHeight - 1);
    cv::Mat roiImage = fullImage(roiRect);
    
    STAssertTrue(roiImage.isSubmatrix(), @"roiImage should be a submatrix");
    
    bool matEqualToSelf = matIsEqual(roiImage, roiImage);
    STAssertTrue(matEqualToSelf, @"roiImage is not equal to itself");

    UIImage *tmpUIImage = [UIImage imageWithCVMat:roiImage];
    STAssertNotNil(tmpUIImage, @"nil result for conversion to UIImage");
    
    cv::Mat outputImage = [UIImage cvMatWithImage:tmpUIImage];
    cv::cvtColor(outputImage, outputImage, CV_BGRA2BGR);
    
    bool isEqual = matIsEqual(roiImage, outputImage);
    STAssertTrue(isEqual, @"Input and output images are not equal");
}


- (void)testBGRAColorImage
{
    cv::Mat inputImage(self.testImageHeight, self.testImageWidth, CV_8UC4);
    
    cv::randu(inputImage, cv::Scalar(0,0,0,0), cv::Scalar(256, 256, 256, 256));
    
    bool matEqualToSelf = matIsEqual(inputImage, inputImage);
    STAssertTrue(matEqualToSelf, @"inputImage is not equal to itself");
    
    UIImage *tmpUIImage = [UIImage imageWithCVMat:inputImage];
    STAssertNotNil(tmpUIImage, @"nil result for conversion to UIImage");
    
    cv::Mat outputImage = [UIImage cvMatWithImage:tmpUIImage];
    
    bool isEqual = matIsEqual(inputImage, outputImage);
    STAssertTrue(isEqual, @"Input and output images are not equal");
}

- (void)testBGRAColorImageROI
{
    cv::Mat fullImage(self.testImageHeight, self.testImageWidth, CV_8UC4);
    cv::randu(fullImage, cv::Scalar(0,0,0,0), cv::Scalar::all(256));
    
    cv::Rect roiRect(1, 1, self.testImageWidth - 1, self.testImageHeight - 1);
    cv::Mat roiImage = fullImage(roiRect);
    
    STAssertTrue(roiImage.isSubmatrix(), @"roiImage should be a submatrix");
    
    bool matEqualToSelf = matIsEqual(roiImage, roiImage);
    STAssertTrue(matEqualToSelf, @"roiImage is not equal to itself");
    
    UIImage *tmpUIImage = [UIImage imageWithCVMat:roiImage];
    STAssertNotNil(tmpUIImage, @"nil result for conversion to UIImage");
    
    cv::Mat outputImage = [UIImage cvMatWithImage:tmpUIImage];
    
    bool isEqual = matIsEqual(roiImage, outputImage);
    STAssertTrue(isEqual, @"Input and output images are not equal");
}

@end
