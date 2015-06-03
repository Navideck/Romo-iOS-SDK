//
//  RMVisionObjectsTests.m
//  RMVision
//
//  Created on 10/24/13.
//  Copyright (c) 2013 Romotive, Inc. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "RMVision.h"
#import "RMVision_Internal.h"
#import "RMVisionTestHelpers.h"

@interface RMVisionObjectsTests : SenTestCase


@end

@implementation RMVisionObjectsTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

#pragma mark - Tests
- (void)testRMVisionTrainingDataWithNSCoder
{
    RMVisionTrainingData *originalObject = [[RMVisionTrainingData alloc] initRandomTestData];
    
    
    NSMutableData *encodeData = [[NSMutableData alloc] init];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:encodeData];
    
    // Encode
    [originalObject encodeWithCoder:archiver];
    [archiver finishEncoding];
    

    // Save to the file system
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    path = [path stringByAppendingString:@"/testRMVisionTrainingDataWithNSCoder.data"];
    BOOL writeSuccessful = [encodeData writeToFile:path atomically:NO];
    STAssertTrue(writeSuccessful, @"Failed to write encoded data to file: %@", path);
    
    // Decode

    NSData *decodeData = [NSData dataWithContentsOfFile:path];
    
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:decodeData];
    
    RMVisionTrainingData *retrieveObject = [[RMVisionTrainingData alloc] initWithCoder:unarchiver];
    [unarchiver finishDecoding];
    
    BOOL areObjectsEqual = [originalObject isEqual:retrieveObject];
    
    STAssertTrue(areObjectsEqual, @"Modules are not equal after NSCoding");
    
}


#pragma mark - Test Helpers


@end
