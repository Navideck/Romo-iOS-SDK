//
//  RMVisionSampleTests.m
//  RMVisionSampleTests
//
//  Created on 10/21/13.
//  Copyright (c) 2013 Romotive, Inc. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "RMVision.h"
#import "RMVision_Internal.h"
#import "RMVisionTestHelpers.h"
#import "RMBrightnessMeteringModule.h"
#import "RMVisualStasisDetectionModule.h"
#import "RMThroughRomosEyesModule.h"
#import "RMMotionDetectionModule.h"
#import "RMVideoModule.h"
#import "RMImageUtils.h"

@interface RMVisionTests : SenTestCase <RMVisionDelegate>

@property (nonatomic, strong) RMVision *vision;
@property (nonatomic, assign, getter = isVisionRunning) BOOL visionRunning;
@property (nonatomic, strong) RMBrightnessMeteringModule *brightnessMeteringModule;

@end

@implementation RMVisionTests

- (void)setUp
{
    [super setUp];
    
    srand48(time(0));
    
    [self initVision];
    [self startVisionWithPreBlock:nil
                    andCompletion:nil];
    
    WaitWhile(!self.isVisionRunning);
}

- (void)tearDown
{
    [self stopVisionWithPreBlock:nil
                   andCompletion:nil];
    
    WaitWhile(self.isVisionRunning);
    [self setVisionToNil];
    
    [super tearDown];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object == self.vision && [keyPath isEqualToString:@"videoPreviewLayer"]) {
        if (self.vision.videoPreviewLayer) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                self.vision.videoPreviewLayer.frame = [[[[UIApplication sharedApplication] delegate] window] bounds];
                [[[[UIApplication sharedApplication] delegate] window].rootViewController.view.layer addSublayer:self.vision.videoPreviewLayer];
                
            });
        }
    }
}

#pragma mark - Tests
// Capture starting and stopping
//==============================================================================
- (void)testStartingAndStoppingRapidly
{
    int numOfSwitches = 10;
    for (int i = 0; i < numOfSwitches; i++) {
        [self stopVisionWithPreBlock:nil andCompletion:^{
            STAssertTrue(!self.vision.running, @"RMVision is still initialized after being stopped");
        }];
        WaitWhile(self.isVisionRunning);
        [self setVisionToNil];
        
        [self initVision];
        [self startVisionWithPreBlock:nil andCompletion:^{
            STAssertTrue(self.vision.running, @"RMVision is not running after being started");
        }];
        WaitWhile(!self.isVisionRunning);
    }
}

- (void)testStartingWhileStopping
{
    __block BOOL startDone = NO;
    __block BOOL stopDone = NO;

    // Vision should be running to start
    STAssertTrue(self.vision.running, @"RMVision should be running, but is not");

    [self stopVisionWithPreBlock:^{
        [self startVisionWithPreBlock:^{

        } andCompletion:^{
            STAssertTrue(self.vision.running, @"RMVision should be running, but is not");
            startDone = YES;

        }];
    } andCompletion:^{
        stopDone = YES;

    }];
    WaitWhile(!startDone || !stopDone);
    STAssertTrue(self.vision.running, @"RMVision should be running, but is not");
}

- (void)testStoppingWhileStarting
{
    __block BOOL startDone = NO;
    __block BOOL stopDone = NO;
    
    [self stopVisionWithPreBlock:nil andCompletion:^{
        STAssertTrue(!self.vision.running, @"RMVision is still initialized after being stopped");
    }];
    WaitWhile(self.isVisionRunning);
    [self setVisionToNil];
    
    [self initVision];
    [self startVisionWithPreBlock:^{
        [self stopVisionWithPreBlock:^{
            
        } andCompletion:^{
            STAssertFalse(self.vision.running, @"RMVision shouldn't be running, but it is");
            stopDone = YES;
            
        }];
    } andCompletion:^{
        startDone = YES;

    }];
    WaitWhile(!startDone || !stopDone);
    STAssertFalse(self.vision.running, @"RMVision shouldn't be running, but it is");

}

- (void)testStartingWhileRunning
{
    __block BOOL done = NO;
    [self.vision startCaptureWithCompletion:^(BOOL didSuccessfullyStart) {
        STAssertTrue(self.vision.running, @"RMVision is not running after being started");
        STAssertTrue(!didSuccessfullyStart, @"RMVision thinks it successfully started, but was already running");
        done = YES;
    }];

    WaitWhile(!done);
}

- (void)testStoppingWhileStopped
{
    [self stopVisionWithPreBlock:nil andCompletion:^{
        STAssertTrue(!self.vision.running, @"RMVision is running after being stopped");
    }];
    WaitWhile(self.isVisionRunning);
    
    [self stopVisionWithPreBlock:nil andCompletion:^{
        STAssertTrue(!self.vision.running, @"RMVision is running after calling stop");
    }];
    WaitWhile(self.isVisionRunning);
    [self setVisionToNil];
}

// Modules
//==============================================================================
static NSInteger runs = 0;
const NSInteger MAX_RUNS = 500;
// const NSInteger MAX_RUNS = 50000; // -- This amount really ensures success

- (void)testActivatingModule
{
    self.brightnessMeteringModule = [[RMBrightnessMeteringModule alloc] initWithVision:self.vision];
    [self.vision activateModule:self.brightnessMeteringModule];
    STAssertTrue([self.vision.activeModules containsObject:self.brightnessMeteringModule], @"%@", self.vision.activeModules);
}

- (void)testDeactivatingModule
{
    [self.vision deactivateModule:self.brightnessMeteringModule];
    STAssertTrue(![self.vision.activeModules containsObject:self.brightnessMeteringModule], @"%@", self.vision.activeModules);
}

- (void)testActivatingModuleWithName
{
    [self.vision activateModuleWithName:RMVisionModule_FaceDetection];
    STAssertTrue([[self.vision.activeModules valueForKeyPath:@"name"] containsObject:RMVisionModule_FaceDetection], @"%@", self.vision.activeModules);
}

- (void)testDeactivatingModuleWithName
{
    [self.vision activateModuleWithName:RMVisionModule_FaceDetection];
    [self.vision deactivateModuleWithName:RMVisionModule_FaceDetection];
    STAssertTrue(![[self.vision.activeModules valueForKeyPath:@"name"] containsObject:RMVisionModule_FaceDetection], @"%@", self.vision.activeModules);
}

- (void)testAddingAndRemovingModulesRapidly
{
    /**
     * This is working to find a threading bug where as video is being processed, and at the
     * same time a module is being removed. The issue is that during processing the modules
     * are looped so if another thread is modifing this array you get an exception thrown.
     *
     * Due to the threaded nature of this test, it requires a lot of randomization and also
     * a lot of attempts to reproduce. By default it is set to 500 attempts which will catch
     * major issues, but 50000 is a more reasonable amount to be sure this bug is not reintroduced.
     */
    
    runs = 0;
    
    // Add a few heavy modules
    RMMotionDetectionModule *motionModule = [[RMMotionDetectionModule alloc] initWithVision:self.vision];
    [self.vision activateModule:motionModule];
    
    RMVisualStasisDetectionModule *visualStasisModule = [[RMVisualStasisDetectionModule alloc] initWithVision:self.vision];
    [self.vision activateModule:visualStasisModule];
    
    RMThroughRomosEyesModule *throughRomosEyesModule = [[RMThroughRomosEyesModule alloc] initWithVision:self.vision];
    [self.vision activateModule:throughRomosEyesModule];
    
    [self addThenRemoveModuleRepeatedly];
    
    WaitWhile(runs < MAX_RUNS);
}

- (void)testSettingExposurePointOfInterest
{
    if (self.vision.device.isExposurePointOfInterestSupported) {
        
        float x = drand48() * 2.0 - 1.0;
        float y = drand48() * 2.0 - 1.0;

        CGPoint point = CGPointMake(x, y);
        [self.vision setExposurePointOfInterest:point];
        
        STAssertTrue([RMImageUtils isCGPoint:self.vision.exposurePointOfInterest approximatelyEqualToCGPoint:point withTolerance:FLT_EPSILON],
                     @"RMVision exposurePointOfInterest is %@, should be %@",
                     NSStringFromCGPoint(self.vision.exposurePointOfInterest), NSStringFromCGPoint(point));
    }
}

- (void)testSettingFocusPointOfInterest
{
    if (self.vision.device.isFocusPointOfInterestSupported) {
        
        double x = drand48() * 2.0 - 1.0;
        double y = drand48() * 2.0 - 1.0;
        
        // Round the point since there is limit precision to set the interest point in hardware
        x = floorf(x * 1000) / 1000;
        y = floorf(y * 1000) / 1000;

        CGPoint point = CGPointMake(x, y);
        [self.vision setFocusPointOfInterest:point];
        
        STAssertTrue([RMImageUtils isCGPoint:self.vision.focusPointOfInterest approximatelyEqualToCGPoint:point withTolerance:FLT_EPSILON],
                     @"RMVision focusPointOfInterest is %@, should be %@",
                     NSStringFromCGPoint(self.vision.focusPointOfInterest), NSStringFromCGPoint(point));
    }
}

- (void)testDefaultExposurePointOfInterest
{
    // By default, the exposure point should be the middle of the image
    CGPoint defaultPoint = CGPointMake(0.0, 0.0);
    STAssertTrue(CGPointEqualToPoint(self.vision.exposurePointOfInterest, defaultPoint), @"RMVision exposurePointOfInterest is %@, should be %@",
                 NSStringFromCGPoint(self.vision.exposurePointOfInterest), NSStringFromCGPoint(defaultPoint));
}

- (void)testDefaultFocusPointOfInterest
{
    // By default, the focus point should be the middle of the image
    CGPoint defaultPoint = CGPointMake(0.0, 0.0);
    STAssertTrue(CGPointEqualToPoint(self.vision.focusPointOfInterest, defaultPoint), @"RMVision focusPointOfInterest is %@, should be %@",
                 NSStringFromCGPoint(self.vision.focusPointOfInterest), NSStringFromCGPoint(defaultPoint));
}

- (void)testFocusPointNotSavedAcrossVisionSessions
{
    if (self.vision.device.isFocusPointOfInterestSupported) {
        
        // Set a focus point
        CGPoint point = CGPointMake(0.75, 0.75);
        [self.vision setFocusPointOfInterest:point];
        
        STAssertTrue(CGPointEqualToPoint(self.vision.focusPointOfInterest, point), @"RMVision focusPointOfInterest is %@, should be %@",
                     NSStringFromCGPoint(self.vision.focusPointOfInterest), NSStringFromCGPoint(point));
        
        // Stop vision
        [self stopVisionWithPreBlock:nil andCompletion:^{
            STAssertFalse(self.vision.running, @"RMVision is still initialized after being stopped");
        }];
        WaitWhile(self.isVisionRunning);
        [self setVisionToNil];
        
        // Start vision again
        [self initVision];
        [self startVisionWithPreBlock:nil andCompletion:nil];
        WaitWhile(!self.isVisionRunning);
        
        // Make sure the focus point is back to normal
        // By default, the focus point should be the middle of the image
        CGPoint defaultPoint = CGPointMake(0.0, 0.0);
        STAssertTrue(CGPointEqualToPoint(self.vision.focusPointOfInterest, defaultPoint), @"RMVision focusPointOfInterest is %@, should be %@",
                     NSStringFromCGPoint(self.vision.focusPointOfInterest), NSStringFromCGPoint(defaultPoint));
    }
}

- (void)testExposurePointNotSavedAcrossVisionSessions
{
    if (self.vision.device.isExposurePointOfInterestSupported) {
        
        // Set a exposure point
        CGPoint point = CGPointMake(0.75, 0.75);
        [self.vision setExposurePointOfInterest:point];
        
        STAssertTrue(CGPointEqualToPoint(self.vision.exposurePointOfInterest, point), @"RMVision exposurePointOfInterest is %@, should be %@",
                     NSStringFromCGPoint(self.vision.exposurePointOfInterest), NSStringFromCGPoint(point));
        
        // Stop vision
        [self stopVisionWithPreBlock:nil andCompletion:^{
            STAssertFalse(self.vision.running, @"RMVision is still initialized after being stopped");
        }];
        WaitWhile(self.isVisionRunning);
        [self setVisionToNil];
        
        // Start vision again
        [self initVision];
        [self startVisionWithPreBlock:nil andCompletion:nil];
        WaitWhile(!self.isVisionRunning);
        
        // Make sure the exposure point is back to normal
        // By default, the exposure point should be the middle of the image
        CGPoint defaultPoint = CGPointMake(0.0, 0.0);
        STAssertTrue(CGPointEqualToPoint(self.vision.exposurePointOfInterest, defaultPoint), @"RMVision exposurePointOfInterest is %@, should be %@",
                     NSStringFromCGPoint(self.vision.exposurePointOfInterest), NSStringFromCGPoint(defaultPoint));
    }
}

- (void)testChangeExposurePointWhileStarting
{
    if (self.vision.device.isExposurePointOfInterestSupported) {
      
        __block BOOL startDone = NO;
        __block CGPoint point;
        
        [self stopVisionWithPreBlock:nil andCompletion:nil];
        WaitWhile(self.isVisionRunning);
        STAssertFalse(self.vision.running, @"RMVision is still initialized after being stopped");
        [self setVisionToNil];
        
        [self initVision];
        [self startVisionWithPreBlock:^{
            
            float x = drand48() * 2.0 - 1.0;
            float y = drand48() * 2.0 - 1.0;
            
            point = CGPointMake(x, y);
            [self.vision setExposurePointOfInterest:point];
            
        } andCompletion:^{
            startDone = YES;
        }];
        WaitWhile(!startDone);
        
        STAssertTrue([RMImageUtils isCGPoint:self.vision.exposurePointOfInterest approximatelyEqualToCGPoint:point withTolerance:FLT_EPSILON],
                     @"RMVision exposurePointOfInterest is %@, should be %@",
                     NSStringFromCGPoint(self.vision.exposurePointOfInterest), NSStringFromCGPoint(point));
        
    }
}

- (void)testChangeFocusPointWhileStarting
{
    if (self.vision.device.isFocusPointOfInterestSupported) {
        
        __block BOOL startDone = NO;
        __block CGPoint point;
        
        [self stopVisionWithPreBlock:nil andCompletion:nil];
        WaitWhile(self.isVisionRunning);
        STAssertFalse(self.vision.running, @"RMVision is still initialized after being stopped");
        [self setVisionToNil];
        
        [self initVision];
        [self startVisionWithPreBlock:^{
            
            float x = drand48() * 2.0 - 1.0;
            float y = drand48() * 2.0 - 1.0;
            self.vision.focusPointOfInterest = CGPointMake(x, y);
            
        } andCompletion:^{
            startDone = YES;
        }];
        WaitWhile(!startDone);
        
        STAssertTrue([RMImageUtils isCGPoint:self.vision.focusPointOfInterest approximatelyEqualToCGPoint:point withTolerance:FLT_EPSILON],
                     @"RMVision focusPointOfInterest is %@, should be %@",
                     NSStringFromCGPoint(self.vision.focusPointOfInterest), NSStringFromCGPoint(point));
        
    }
}

- (void)testRunningMultipleVideoModules
{
    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *path1 = [[documentsDirectory stringByAppendingPathComponent:@"RomoVideo1"] stringByAppendingString:@".mp4"];
    NSString *path2 = [[documentsDirectory stringByAppendingPathComponent:@"RomoVideo2"] stringByAppendingString:@".mp4"];
    
    RMVideoModule *videoModule1 = [[RMVideoModule alloc] initWithVision:self.vision recordToPath:path1];
    RMVideoModule *videoModule2 = [[RMVideoModule alloc] initWithVision:self.vision recordToPath:path2];
    
    [self.vision activateModule:videoModule1];
    [self.vision activateModule:videoModule2];
    
    STAssertTrue([self.vision.activeModules containsObject:videoModule1], @"%@ is missing videoModule1", self.vision.activeModules);
    STAssertTrue([self.vision.activeModules containsObject:videoModule2], @"%@ is missing videoModule2", self.vision.activeModules);
    
    // Record for 1.0 seconds
    __block BOOL timerHasFired = NO;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        timerHasFired = YES;
    });
    
    WaitWhile(!timerHasFired);
    
    [self.vision deactivateModule:videoModule1];
    [self.vision deactivateModule:videoModule2];
    
    STAssertFalse([self.vision.activeModules containsObject:videoModule1], @"%@ is has videoModule1", self.vision.activeModules);
    STAssertFalse([self.vision.activeModules containsObject:videoModule2], @"%@ is has videoModule2", self.vision.activeModules);
    
    __block BOOL videoComplete1 = NO;
    __block BOOL videoComplete2 = NO;
    
    [videoModule1 shutdownWithCompletion:^{
        videoComplete1 = YES;
    }];
    [videoModule2 shutdownWithCompletion:^{
        videoComplete2 = YES;
    }];
    
    WaitWhile(!videoComplete1 && !videoComplete2);
}

// Capture framerate
//==============================================================================
- (void)testSettingFramerateRapidly
{
    // Test setting framerates when vision is running
    static const int NUM_FRAMERATE_CHANGES = 5;
    
    // Only frame rates from 2 to 30 are typically supported
    int desiredFrameRates[NUM_FRAMERATE_CHANGES] = {5, 10, 30, 2, 24};
    
    for (int i = 0; i < NUM_FRAMERATE_CHANGES; i++) {
        int desiredFrameRate = desiredFrameRates[i];
        [self.vision setTargetFrameRate:desiredFrameRate];
        STAssertTrue(self.vision.targetFrameRate == desiredFrameRate, @"RMVision framerate is %d, should be %d", self.vision.targetFrameRate, desiredFrameRate);
    }
}

- (void)testSettingFramerateDuringTransition
{
    // Shut down vision
    [self stopVisionWithPreBlock:nil andCompletion:nil];
    WaitWhile(self.isVisionRunning);
    [self setVisionToNil];
    
    // Init vision and set target framerate when it's transitioning
    int desiredFrameRate = 7;
    [self initVision];
    [self startVisionWithPreBlock:^{
        [self.vision setTargetFrameRate:desiredFrameRate];
    } andCompletion:^{
        STAssertTrue(self.vision.targetFrameRate == desiredFrameRate, @"RMVision framerate is %d, should be %d", self.vision.targetFrameRate, desiredFrameRate);
    }];
    
    WaitWhile(!self.isVisionRunning);
}

#pragma mark - Test Helpers

- (void)startVisionWithPreBlock:(void (^)(void))preblock
                  andCompletion:(void (^)(void))completion
{
    [self.vision startCaptureWithCompletion:^(BOOL didSuccessfullyStart) {
        if (completion) {
            completion();
        }
        if (didSuccessfullyStart) {
            self.visionRunning = YES;
        }
    }];
    if (preblock) {
        preblock();
    }
}

- (void)stopVisionWithPreBlock:(void (^)(void))preblock
                 andCompletion:(void (^)(void))completion
{
    [self.vision stopCaptureWithCompletion:^(BOOL didSuccessfullyStop) {
        if (completion) {
            completion();
        }
        if (didSuccessfullyStop) {
            self.visionRunning = NO;
        }
    }];
    if (preblock) {
        preblock();
    }
}

- (void)initVision
{
    self.visionRunning = NO;
    self.vision = [[RMVision alloc] initWithCamera:RMCamera_Front];
    self.vision.delegate = self;
    [self.vision addObserver:self forKeyPath:@"videoPreviewLayer" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:nil];
}

- (void)setVisionToNil
{
    [self.vision removeObserver:self forKeyPath:@"videoPreviewLayer"];
    self.vision.delegate = nil;
    self.vision = nil;
}

- (void)addThenRemoveModuleRepeatedly
{
    if (!self.brightnessMeteringModule) {
        self.brightnessMeteringModule = [[RMBrightnessMeteringModule alloc] initWithVision:self.vision];
    }
    [self.vision activateModule:self.brightnessMeteringModule];
    [self performSelector:@selector(removeModule) withObject:nil afterDelay:drand48() / 100.0];
}

- (void)removeModule
{
    [self.vision deactivateModule:self.brightnessMeteringModule];
    
    if (runs % (MAX_RUNS / 10) == 0) {
        NSLog(@"Completed run %d of %d", runs, MAX_RUNS);
    }
    
    if (++runs < MAX_RUNS) {
        [self performSelector:@selector(addThenRemoveModuleRepeatedly) withObject:nil afterDelay:drand48() / 100.0];
    }
}

@end
