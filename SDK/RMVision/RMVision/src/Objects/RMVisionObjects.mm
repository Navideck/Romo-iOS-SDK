////////////////////////////////////////////////////////////////////////////////
//                             _
//                            | | (_)
//   _ __ ___  _ __ ___   ___ | |_ ___   _____
//  | '__/ _ \| '_ ` _ \ / _ \| __| \ \ / / _ \
//  | | | (_) | | | | | | (_) | |_| |\ V /  __/
//  |_|  \___/|_| |_| |_|\___/ \__|_| \_/ \___|
//
////////////////////////////////////////////////////////////////////////////////
//
//  RMVisionObjects.cpp
//  Romo3
//
//  Created on 5/8/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
////////////////////////////////////////////////////////////////////////////////
#import "RMVisionObjects.h"
#import "RMImageUtils.h"
#import "RMOpenCVUtils.h"
#import "UIImage+OpenCV.h"
#import "RMOpenCVUtils.h"

//static const float kRMObjectTimeTrackedThreshold = 0.5;
static const int kNegativeResponseLabel = 1;
static const int kPositiveResponseLabel = 2;

//==============================================================================
@implementation RMObject

-(id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    
    if (self) {
        self.identifier = [(NSNumber *)[aDecoder decodeObjectForKey:@"identifier"] integerValue];
        self.timeTracked = [(NSNumber *)[aDecoder decodeObjectForKey:@"timeTracked"] floatValue];
        self.boundingBox = [aDecoder decodeCGRectForKey:@"boundingBox"];
        self.justFound = [(NSNumber *)[aDecoder decodeObjectForKey:@"justFound"] boolValue];
        self.frameNumber = [(NSNumber *)[aDecoder decodeObjectForKey:@"frameNumber"] unsignedIntegerValue];
    }
    
    return self;
}

-(void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:@(self.identifier) forKey:@"identifier"];
    [aCoder encodeObject:@(self.timeTracked) forKey:@"timeTracked"];
    [aCoder encodeCGRect:self.boundingBox forKey:@"boundingBox"];
    [aCoder encodeObject:@(self.justFound) forKey:@"justFound"];
    [aCoder encodeObject:@(self.frameNumber) forKey:@"frameNumber"];
}

-(NSDictionary *)convertToNSDictionary
{
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];

    [data setObject:@(self.identifier) forKey:@"identifier"];
    [data setObject:@(self.timeTracked) forKey:@"timeTracked"];
    [data setObject:NSStringFromCGRect(self.boundingBox) forKey:@"boundingBox"];
    [data setObject:@(self.justFound) forKey:@"justFound"];
    [data setObject:@(self.frameNumber) forKey:@"frameNumber"];
    
    return data;
}

-(id)initWithDictionary:(NSDictionary *)dictionary
{
    self = [super init];
    
    if (self) {
        self.identifier = [(NSNumber *)[dictionary objectForKey:@"identifier"] integerValue];
        self.timeTracked = [(NSNumber *)[dictionary objectForKey:@"timeTracked"] floatValue];
        self.boundingBox = CGRectFromString((NSString *)[dictionary objectForKey:@"boundingBox"]);
        self.justFound = [(NSNumber *)[dictionary objectForKey:@"justFound"] boolValue];
        self.frameNumber = [(NSNumber *)[dictionary objectForKey:@"frameNumber"] unsignedIntegerValue];
    }
    
    return self;
}

-(BOOL)isApproximatelyEqual:(RMObject *)other withTolerance:(float)tolerance
{
    
    if (self.identifier != other.identifier) {
        return NO;
    }

    // Varies too much between devices
//    if (fabs(self.timeTracked - other.timeTracked) > kRMObjectTimeTrackedThreshold) {
//        return NO;
//    }

    if (![RMImageUtils isCGRect:self.boundingBox approximatelyEqualToCGRect:other.boundingBox withTolerance:tolerance]) {
        return NO;
    }
    
//    if (self.justFound != other.justFound) {
//        return NO;
//    }
    
    if (self.frameNumber != other.frameNumber) {
        return NO;
    }
    
    return YES;
}

@end

//==============================================================================
@implementation RMBlob

-(NSDictionary *)convertToNSDictionary
{
    NSDictionary *superDictionary = [super convertToNSDictionary];
    
    NSMutableDictionary *data = [[NSMutableDictionary alloc] initWithDictionary:superDictionary];
    
    [data setObject:NSStringFromCGPoint(self.centroid) forKey:@"centroid"];
    [data setObject:@(self.area) forKey:@"area"];
    if (self.path) {
        [data setObject:self.path forKey:@"path"];
    }
    [data setObject:@(self.isColorBlob) forKey:@"isColorBlob"];
    
    return data;
}


-(id)initWithDictionary:(NSDictionary *)dictionary
{
    self = [super initWithDictionary:dictionary];
    
    if (self) {
        self.centroid = CGPointFromString((NSString *)[dictionary objectForKey:@"centroid"]);
        self.area = [(NSNumber *)[dictionary objectForKey:@"area"] floatValue];
        self.path = [dictionary objectForKey:@"path"];
        self.isColorBlob = [(NSNumber *)[dictionary objectForKey:@"isColorBlob"] boolValue];
    }
    return self;
}

-(BOOL)isApproximatelyEqual:(RMBlob *)other withTolerance:(float)tolerance
{
    
    if (![super isApproximatelyEqual:other withTolerance:tolerance]) {
        return NO;
    }
    
    if (![RMImageUtils isCGPoint:self.centroid approximatelyEqualToCGPoint:other.centroid withTolerance:tolerance]) {
        return NO;
    }
    
    if (fabs(self.area - other.area) > tolerance) {
        return NO;
    }
    
    
    return YES;
}

@end

//==============================================================================
@implementation RMFace

@end

//==============================================================================
@implementation RMMotion

@end

//==============================================================================
@implementation RMLine

@end

//==============================================================================
@implementation RMColors

@end

//==============================================================================
@implementation RMVisionTrainingData

-(id)init
{
    self = [super init];
    if (self) {
        _covarianceScaling = 1.0;
    }
    
    return self;
}

-(id)initWithPositiveImage:(UIImage *)positiveImage withNegativeExamplesImage:(UIImage *)negativeImage
{
    // Use the alpha channel as the mask
    
    // Positive examples
    cv::Mat positiveMatFull = [ UIImage cvMatWithImage:positiveImage ];
    
    cv::Mat positiveVectorBGRAImage = positiveMatFull.reshape(1, positiveMatFull.cols*positiveMatFull.rows);
    cv::Mat positiveMask = positiveVectorBGRAImage.col(3);
    
    cv::Mat positiveExamples = [RMOpenCVUtils extractRowsFromVectorizedMat:positiveVectorBGRAImage withMask:positiveMask];
    
    cv::Mat trimmedPositiveExamples = positiveExamples.colRange(0, 3); // Range end is exclusive so up to but not including col 3
    trimmedPositiveExamples.convertTo(trimmedPositiveExamples, CV_32F);
    
    
    // Negative examples
    
    cv::Mat trimmedNegativeExamples;
    
    if (negativeImage) {
        cv::Mat negativeMatFull = [ UIImage cvMatWithImage:negativeImage ];
        
        
        cv::Mat negativeVectorBGRAImage = negativeMatFull.reshape(1, negativeMatFull.cols*negativeMatFull.rows);
        cv::Mat negativeMask = negativeVectorBGRAImage.col(3);
        
        cv::Mat negativeExamples = [RMOpenCVUtils extractRowsFromVectorizedMat:negativeVectorBGRAImage withMask:negativeMask];
        
        trimmedNegativeExamples = negativeExamples.colRange(0, 3); // Range end is exclusive so up to but not including col 3
        trimmedNegativeExamples.convertTo(trimmedNegativeExamples, CV_32F);
        
    }
    else {
        
        // For negative examples are not available, we will use random values
        trimmedNegativeExamples = cv::Mat(trimmedPositiveExamples.rows, trimmedPositiveExamples.cols, CV_32F);
        cv::randu(trimmedNegativeExamples, cv::Scalar(0), cv::Scalar(256)); // Up to but not including 256
    }
    
    self = [self initWithPositivePixels:trimmedPositiveExamples withNegativePixels:trimmedNegativeExamples];
    
    return self;
}

-(id)initWithPositivePixels:(cv::Mat)positivePixels withNegativePixels:(cv::Mat)negativePixels
{
    self = [super init];
    
    if (self)
    {
        
        positivePixels.convertTo(positivePixels, CV_32F);
        negativePixels.convertTo(negativePixels, CV_32F);

        cv::Mat trainData;
        cv::vconcat(positivePixels,
                    negativePixels,
                    trainData);
        
        cv::Mat responses;
        cv::vconcat(cv::Mat(positivePixels.rows, 1, CV_32F, cv::Scalar(kPositiveResponseLabel)),
                    cv::Mat(negativePixels.rows, 1, CV_32F, cv::Scalar(kNegativeResponseLabel)),
                    responses);
        
        
        // Create the RMVisionTrainingData object
        self.trainingData = trainData;
        self.labels = responses;
        self.positiveResponseLabel = kPositiveResponseLabel;
        self.negativeResponseLabel = kNegativeResponseLabel;
        
    }
    
    return self;
}

-(id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        self.positiveResponseLabel = [(NSNumber *)[aDecoder decodeObjectForKey:@"positiveResponseLabel"] integerValue];
        self.negativeResponseLabel = [(NSNumber *)[aDecoder decodeObjectForKey:@"negativeResponseLabel"] integerValue];

        NSData *trainingDataObject = (NSData *)[aDecoder decodeObjectForKey:@"trainingData"];
        int trainingDataRows = [(NSNumber *)[aDecoder decodeObjectForKey:@"trainingDataRows"] integerValue];
        int trainingDataCols = [(NSNumber *)[aDecoder decodeObjectForKey:@"trainingDataCols"] integerValue];
        int trainingDataDepth = [(NSNumber *)[aDecoder decodeObjectForKey:@"trainingDataDepth"] integerValue];
        int trainingDataChannels = [(NSNumber *)[aDecoder decodeObjectForKey:@"trainingDataChannels"] integerValue];

        self.trainingData = cv::Mat(trainingDataRows, trainingDataCols, CV_MAKETYPE(trainingDataDepth, trainingDataChannels));
        [trainingDataObject getBytes:self.trainingData.data length:self.trainingData.elemSize() * self.trainingData.total()];
        
        
        NSData *labelsObject = (NSData *)[aDecoder decodeObjectForKey:@"labels"];
        int labelsRows = [(NSNumber *)[aDecoder decodeObjectForKey:@"labelsRows"] integerValue];
        int labelsCols = [(NSNumber *)[aDecoder decodeObjectForKey:@"labelsCols"] integerValue];
        int labelsDepth = [(NSNumber *)[aDecoder decodeObjectForKey:@"labelsDepth"] integerValue];
        int labelsChannels = [(NSNumber *)[aDecoder decodeObjectForKey:@"labelsChannels"] integerValue];

        self.labels = cv::Mat(labelsRows, labelsCols, CV_MAKETYPE(labelsDepth, labelsChannels));
        [labelsObject getBytes:self.labels.data length:self.labels.elemSize() * self.labels.total()];
        
        
        _covarianceScaling = 1.0;
        NSNumber *storedCovarianceScaling = (NSNumber *)[aDecoder decodeObjectForKey:@"covarianceScaling"];
        if (storedCovarianceScaling) {
            _covarianceScaling = [storedCovarianceScaling floatValue];
        }

    }
    
    return self;
}

-(id)initRandomTestData
{
    self = [self init];
    
    if (self) {
        
        NSUInteger rows = arc4random_uniform(1000) + 1;
        NSUInteger cols = arc4random_uniform(1000) + 1;
        NSUInteger depth = arc4random_uniform(CV_USRTYPE1);
        
        _trainingData = cv::Mat(rows, cols, CV_MAKETYPE(depth, 1));
        _labels = cv::Mat(rows, 1, CV_32FC1);
        
        cv::randu(_trainingData, cv::Scalar(0), cv::Scalar(256));
        cv::randu(_labels, cv::Scalar(0), cv::Scalar(256));
        
        // Rather than using the predefine labels. We will use random labels
        // to test for compabilility with different labelsß
        _positiveResponseLabel = arc4random_uniform(256);
        do {
            _negativeResponseLabel = arc4random_uniform(256);
        } while (_negativeResponseLabel != _positiveResponseLabel);

    }
    
    return self;
}

-(void)encodeWithCoder:(NSCoder *)aCoder
{
    // In this case, the super class is meaningless with respect to the training data
    [super encodeWithCoder:aCoder];
    
    [aCoder encodeObject:@(self.positiveResponseLabel) forKey:@"positiveResponseLabel"];
    [aCoder encodeObject:@(self.negativeResponseLabel) forKey:@"negativeResponseLabel"];

    NSData *trainingDataObject = [NSData dataWithBytes:self.trainingData.data length:self.trainingData.elemSize() * self.trainingData.total()];
    [aCoder encodeObject:trainingDataObject forKey:@"trainingData"];
    [aCoder encodeObject:@(self.trainingData.rows) forKey:@"trainingDataRows"];
    [aCoder encodeObject:@(self.trainingData.cols) forKey:@"trainingDataCols"];
    [aCoder encodeObject:@(self.trainingData.depth()) forKey:@"trainingDataDepth"];
    [aCoder encodeObject:@(self.trainingData.channels()) forKey:@"trainingDataChannels"];
    
    NSData *labelsObject = [NSData dataWithBytes:self.labels.data length:self.labels.elemSize() * self.labels.total()];
    [aCoder encodeObject:labelsObject forKey:@"labels"];
    [aCoder encodeObject:@(self.labels.rows) forKey:@"labelsRows"];
    [aCoder encodeObject:@(self.labels.cols) forKey:@"labelsCols"];
    [aCoder encodeObject:@(self.labels.depth()) forKey:@"labelsDepth"];
    [aCoder encodeObject:@(self.labels.channels()) forKey:@"labelsChannels"];

    [aCoder encodeObject:@(self.covarianceScaling) forKey:@"covarianceScaling"];
}

- (BOOL)isEqual:(id)object
{
    if (self == object) {
        return YES;
    }
    
    if (![object isKindOfClass:[RMVisionTrainingData class]]) {
        return NO;
    }
    
    return [self isEqualToRMVisionTrainingData:(RMVisionTrainingData *)object];
}

-(BOOL)isEqualToRMVisionTrainingData:(RMVisionTrainingData *)other
{
    if (self.positiveResponseLabel != other.positiveResponseLabel) {
        return NO;
    }
    
    if (self.negativeResponseLabel != other.negativeResponseLabel) {
        return NO;
    }
    
    if (!matIsEqual(self.trainingData, other.trainingData)) {
        return NO;
    }
    
    if (!matIsEqual(self.labels, other.labels)) {
        return NO;
    }
    
    return YES;
    
}

-(id)copyWithZone:(NSZone *)zone
{
    RMVisionTrainingData *data = [[RMVisionTrainingData alloc] init];
    data.trainingData = self.trainingData.clone();
    data.labels = self.labels.clone();
    data.positiveResponseLabel = self.positiveResponseLabel;
    data.negativeResponseLabel = self.negativeResponseLabel;
    data.covarianceScaling = self.covarianceScaling;
    
    return data;
}

@end
