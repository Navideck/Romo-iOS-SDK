//
//  RMVisionBenchmarks.m
//  Romo Vision Benchmarking
//
//  Created on 10/14/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
#import <UIKit/UIKit.h>
#import <SenTestingKit/SenTestingKit.h>
#import "RMVision.h"
#import "RMFakeVision.h"
#import "RMVisionObjects.h"
#import "UIDevice+Hardware.h"
#import "RMVisionObjectTrackingModule.h"

// Macro - Wait for condition to be NO/false in blocks and asynchronous calls
#define WaitWhile(condition) \
do { \
while(condition) { \
[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]]; \
} \
} while(0)

static const float kBoundingBoxTolerance = 0.00001;

@interface RMVisionBenchmarks : SenTestCase <RMVisionDelegate, RMVisionObjectTrackingModuleDelegate>

@property (nonatomic) RMFakeVision *vision;
@property (nonatomic) NSMutableDictionary *resultsDictionary;
@property (nonatomic) UIImageView *visualizationView;
@property (nonatomic) UIImageView *rawImageView;

@property (atomic) BOOL moduleIsTraining;

@end

@implementation RMVisionBenchmarks

#pragma mark - Set up / Tear down

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
    self.resultsDictionary = [[NSMutableDictionary alloc] init];
    
    self.rawImageView = [[UIImageView alloc] initWithFrame:[[[UIApplication sharedApplication] delegate] window].rootViewController.view.bounds];
    [[[[UIApplication sharedApplication] delegate] window].rootViewController.view addSubview:self.rawImageView];
    
    self.visualizationView = [[UIImageView alloc] initWithFrame:[[[UIApplication sharedApplication] delegate] window].rootViewController.view.bounds];
    [[[[UIApplication sharedApplication] delegate] window].rootViewController.view addSubview:self.visualizationView];
    self.visualizationView.alpha = 0.5;

}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
    
    self.vision = nil;
    self.resultsDictionary = nil;
}

#pragma mark - Helpers

- (RMFakeVision *)createFakeVisionWithVideo:(NSString *)videoPath
                             andLoadModules:(NSArray *)modules
{
    NSURL *videoURL = [NSURL fileURLWithPath:videoPath];
    RMFakeVision *vision = [[RMFakeVision alloc] initWithFileURL:videoURL
                                                      inRealtime:NO];
    
    STAssertNotNil(vision, @"Unable to load video file");
    
    for (NSString *module in modules) {
        BOOL loaded = [vision activateModuleWithName:module];
        STAssertTrue(loaded, @"Module not loaded: %@", module);
    }
    return vision;
}

- (void)timedRunWithVision:(RMVision *)vision
         benchmarkDataPath:(NSString *)benchmarkDataPath
         resultsDictionary:(NSMutableDictionary *)resultsDictionary
{
    NSBundle *bundle = [NSBundle bundleForClass:self.class];
    // Load the reference results
    NSString *benchmarkDataPlist = [bundle pathForResource:benchmarkDataPath
                                                    ofType:@"plist"];
    NSDictionary *benchmarkDictionary = [NSDictionary dictionaryWithContentsOfFile:benchmarkDataPlist];
    STAssertNotNil(benchmarkDictionary, @"Unable to load benchmark dictionary");
    
    // Start the benchmark timer
    NSDate *start = [NSDate date];
    
    [vision startCapture];
    WaitWhile(vision.isRunning);
    
    // End the benchmark timer
    NSDate *methodFinish = [NSDate date];
    NSTimeInterval executionTime = [methodFinish timeIntervalSinceDate:start];
    NSLog(@"Execution Time: %f", executionTime);
    
    resultsDictionary[@"executionTime"] = @(executionTime);
    
    // Check the count
    STAssertEquals(benchmarkDictionary.count, resultsDictionary.count,
                   @"Result sets are not the same size, expected: %lu got: %lu",
                   benchmarkDictionary.count, resultsDictionary.count);
    
    // Check results
    for (NSString *key in benchmarkDictionary) {
        if ([key compare:@"executionTime"] == NSOrderedSame) {
            // Skip over checking the execution time
            continue;
        }
        NSDictionary *result = [resultsDictionary objectForKey:key];
        STAssertNotNil(result, @"Result for key: %@ not created during test", key);
        
        RMObject *resultObject = [[RMObject alloc] initWithDictionary:result];
        RMObject *benchmarkObject = [[RMObject alloc] initWithDictionary:(NSDictionary *)[benchmarkDictionary objectForKey:key]];
        STAssertTrue([resultObject isApproximatelyEqual:benchmarkObject
                                          withTolerance:kBoundingBoxTolerance],
                     @"Objects are not equal within tolerance: %f\n%@\n%@",
                     kBoundingBoxTolerance, result,
                     [benchmarkObject convertToNSDictionary]);
    }
}

#pragma mark - Tests

- (void)testFaceDetection
{
    NSString *deviceSpecificPath;
    
    if ([UIDevice currentDevice].isFastDevice) {
        deviceSpecificPath = @"face_isFast_FaceDetection";
    }
    else {
        deviceSpecificPath = @"face_notFast_FaceDetection";
    }
    
    
    NSString *testVidPath = [[NSBundle bundleForClass:self.class] pathForResource:@"face"
                                                                           ofType:@"mov"];
    
    self.vision = [self createFakeVisionWithVideo:testVidPath
                                   andLoadModules:@[RMVisionModule_FaceDetection]];
    self.vision.delegate = self;
    
    [self timedRunWithVision:self.vision
           benchmarkDataPath:deviceSpecificPath
           resultsDictionary:self.resultsDictionary];
    
    // Save results
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *basePath = [paths objectAtIndex:0];
    NSString *fileName = [NSString stringWithFormat:@"%@_results.plist", deviceSpecificPath];
    NSString *filePath = [basePath stringByAppendingPathComponent:fileName];
    STAssertTrue([self.resultsDictionary writeToFile:filePath atomically:YES],
                 @"Failed to write resultsDictionary");
}

- (void)testColorTracking
{
    NSBundle *bundle = [NSBundle bundleForClass:self.class];
    NSString *deviceSpecificPath;
    
    if ([UIDevice currentDevice].isFastDevice) {
        deviceSpecificPath = @"green_ball_isFast_ColorTracking";
    }
    else {
        deviceSpecificPath = @"green_ball_notFast_ColorTracking";
    }
    
    // Load image of color to track
    NSString *imagePath = [bundle pathForResource:@"green_ball_cropped"
                                           ofType:@"png"];
    UIImage *positiveExamplesUIImage = [UIImage imageWithContentsOfFile:imagePath];
    
    RMVisionTrainingData *trainingDataObject = [[RMVisionTrainingData alloc] initWithPositiveImage:positiveExamplesUIImage withNegativeExamplesImage:nil];
    
    // Load the test movie
    NSString *testVidPath = [bundle pathForResource:@"green_ball"
                                             ofType:@"mov"];
    
    self.vision = [self createFakeVisionWithVideo:testVidPath
                                   andLoadModules:@[]];
    self.vision.delegate = self;
    
    RMVisionObjectTrackingModule *objectTrackingModule = [[RMVisionObjectTrackingModule alloc] initWithVision:self.vision];
    
    // Since the adaptive data model takes random data from the camera feed to update the negative background mode,
    // the benchmarking results will not be exactly the same every time. This usually happens in when the ball is small
    // and blending into the background.
    objectTrackingModule.allowAdaptiveForegroundUpdates = NO;
    objectTrackingModule.allowAdaptiveBackgroundUpdates = NO;

    objectTrackingModule.delegate = self;
    
    self.moduleIsTraining = YES;
    [objectTrackingModule trainWithData:trainingDataObject];
    
    WaitWhile(self.moduleIsTraining);
    
    // Activate module
    [self.vision activateModule:objectTrackingModule];
    
    [self timedRunWithVision:self.vision
           benchmarkDataPath:deviceSpecificPath
           resultsDictionary:self.resultsDictionary];
    
    // Save results
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *basePath = [paths objectAtIndex:0];
    NSString *fileName = [NSString stringWithFormat:@"%@_results.plist", deviceSpecificPath];
    NSString *filePath = [basePath stringByAppendingPathComponent:fileName];
    STAssertTrue([self.resultsDictionary writeToFile:filePath atomically:YES], @"Failed to write resultsDictionary");
}


// A temporary video replay solution for captured debug data
- (void)testColorTrackingReplayOnly
{
    NSString *trainingDataName = @"RMVisionTrainingData.data";
    NSString *movieName = @"inputVideo.mp4";
    
    // Load training data
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *basePath = [paths objectAtIndex:0];
    NSString *filePath = [basePath stringByAppendingPathComponent:trainingDataName];

    // Decode training data
    NSData *decodeData = [NSData dataWithContentsOfFile:filePath];
    
    // If unable to load the decode data, just return.
    // This test should only be run if that data was present.
    if (!decodeData) {
        return;
    }
    
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:decodeData];
    RMVisionTrainingData *trainingDataObject = [[RMVisionTrainingData alloc] initWithCoder:unarchiver];
    [unarchiver finishDecoding];

    // Load the movie
    NSString *testVidPath = [basePath stringByAppendingPathComponent:movieName];
    
    // Start up fake vision
    self.vision = [self createFakeVisionWithVideo:testVidPath
                                   andLoadModules:@[]];
    self.vision.delegate = self;
    
    // Create and train the tracing module
    RMVisionObjectTrackingModule *objectTrackingModule = [[RMVisionObjectTrackingModule alloc] initWithVision:self.vision];
    objectTrackingModule.delegate = self;
    objectTrackingModule.allowAdaptiveBackgroundUpdates = NO;
    objectTrackingModule.allowAdaptiveForegroundUpdates = YES;
    
    // Region of interest for line follow
    objectTrackingModule.roi = CGRectMake(-1.0, 0.1, 2.0, 0.9);
    
    [self.vision activateModule:objectTrackingModule];

    // Train the module
    [objectTrackingModule trainWithData:trainingDataObject];
    
    self.moduleIsTraining = YES;
    WaitWhile(self.moduleIsTraining);

    // Run vision
    [self.vision startCapture];
    WaitWhile(self.vision.isRunning);
    
}


#pragma mark - Helper functions

-(void)writeDictionary:(NSDictionary *)dictionary toFileNamed:(NSString *)name
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    NSString *filePath = [basePath stringByAppendingPathComponent:name];
    
    [dictionary writeToFile:filePath  atomically:YES];
}

-(NSData *)buildJSONDataFromNSDictionary:(NSDictionary *)dictionary
{
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dictionary
                                                       options:0
                                                         error:&error];
    return jsonData;
}

#pragma mark - Delegate methods

- (void)didDetectFace:(RMFace *)face
{
    NSLog(@"didDetectFace - frame: %u", face.frameNumber);
    NSDictionary *faceObjectionDictionary = [face convertToNSDictionary];
    
    [self.resultsDictionary setObject:faceObjectionDictionary forKey:[NSString stringWithFormat:@"%u",face.frameNumber]];
    
}

- (void)didLoseFace
{
    NSLog(@"didLoseFace");
    
}

#pragma mark - RMVisionObjectTrackingModuleDelegate

-(void)objectTrackingModuleFinishedTraining:(RMVisionObjectTrackingModule *)module
{
    self.moduleIsTraining = NO;
}

-(void)objectTrackingModule:(RMVisionObjectTrackingModule *)module didDetectObject:(RMBlob *)object
{
    NSLog(@"didDetectBlob - frame: %u", object.frameNumber);
    
    NSDictionary *blobObjectionDictionary = [object convertToNSDictionary];
    
    [self.resultsDictionary setObject:blobObjectionDictionary forKey:[NSString stringWithFormat:@"%u",object.frameNumber]];
}

-(void)objectTrackingModuleDidLoseObject:(RMVisionObjectTrackingModule *)module
{
    NSLog(@"didLoseBlob");
}

-(void)showDebugImage:(UIImage *)debugImage
{
    self.rawImageView.image = [self.vision currentImage];
    self.visualizationView.image = debugImage;
}
@end
