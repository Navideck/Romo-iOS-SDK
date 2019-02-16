//
//  RMObjectTrackingVirtualSensor.m
//  Romo
//

#import "RMObjectTrackingVirtualSensor.h"
#import <Romo/RMVision.h>
#import <Romo/RMMotionTriggeredColorTrainingModule.h>
#import <Romo/RMVisionObjectTrackingModule.h>
#import "RMRomo.h"
#import <Romo/UIDevice+Romo.h>

/** How many frames must be seen for training */
static const float motionTriggeredDuration = 1.75; // seconds
static const int motionTriggeredFrameRateFastDevice = 24; // fps
static const int motionTriggeredFrameRateSlowDevice = 8; // fps
static const int motionTriggeredMaximumAccumulatedPixelsFastDevice = 30000; // # of pixels
static const int motionTriggeredMaximumAccumulatedPixelsSlowDevice = 10000; // # of pixels
static const int motionTriggeredClusterCount = 3;

/** How many pixels need to be moving each frame? */
static const float motionTriggeredMovingPixelPercentage = 0.5; // percent

static const int objectTrackingFrameRateFastDevice = 24; // fps
static const int objectTrackingFrameRateSlowDevice = 10; // fps

static const float heldOverHeadDuration = 3.5; // seconds
static const float notHeldOverHeadDuration = 0.35; // seconds
static const float heldOverHeadMinY = -INFINITY;
static const float heldOverHeadMaxY = -0.45;

static const float maximumFlyOverHeadX = 1.15;
static const float minimumFlyOverHeadY = 0.92;

static const float possessionConfirmationDuration = 1.25; // seconds
static const float lostPossessionCancellationDuration = 0.5; // seconds
static const float lostPossessionConfirmationDuration = 1.5; // seconds
static const float possessionMinY = 0.15;
static const float possessionMaxY = INFINITY;

static const float lostObjectConfirmationDelay = 1.25;

static const float invalidLocation = -2.0;

#define objectIsOverhead(y) (heldOverHeadMinY <= (y) && (y) <= heldOverHeadMaxY)
#define objectIsInPossession(y) (possessionMinY <= (y) && (y) <= possessionMaxY)

@interface RMObjectTrackingVirtualSensor () <RMMotionTriggeredColorTrainingModuleDelegate, RMVisionObjectTrackingModuleDelegate>

@property (nonatomic, strong) RMMotionTriggeredColorTrainingModule *motionTriggeredTrainingModule;
@property (nonatomic, strong) RMVisionObjectTrackingModule *objectTrackingModule;

@property (nonatomic) float previousTrainingProgress;

@property (nonatomic, strong) NSTimer *heldOverHeadTimer;
@property (nonatomic, strong) NSTimer *notHeldOverHeadTimer;

@property (nonatomic, strong) NSTimer *possessionTimer;
@property (nonatomic, strong) NSTimer *lostPossessionTimer;

@property (nonatomic) CGPoint previousPreviousCentroid;
@property (nonatomic) CGPoint previousCentroid;
@property (nonatomic) CGPoint centroid;

@property (nonatomic) BOOL sentLostMessage;
@property (nonatomic, strong) NSTimer *lostObjectConfirmationTimer;

/** Readwrite */
@property (nonatomic, readwrite) float trainingProgress;
@property (nonatomic, readwrite, strong) UIColor *trainingColor;
@property (nonatomic, readwrite, strong) UIColor *trainedColor;
@property (nonatomic, readwrite, strong) RMVisionTrainingData *trainingData;
@property (nonatomic, readwrite, strong) RMBlob *object;
@property (nonatomic, readwrite, strong) RMBlob *lastSeenObject;
@property (nonatomic, readwrite, getter=isPossessingObject) BOOL possessingObject;

@end

@implementation RMObjectTrackingVirtualSensor

#pragma mark - Public Methods

- (id)init
{
    self = [super init];
    if (self) {
        _shouldCluster = YES;
        _allowAdaptiveBackgroundUpdates = YES;
    }
    return self;
}

- (void)captureNegativeTrainingDataWithCompletion:(void (^)(void))completion
{
    RMObjectTrackingVirtualSensor *weakSelf = self;
    void (^setupCompletion)(void) = ^{
        [weakSelf.motionTriggeredTrainingModule captureNegativeTrainingData];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion();
            });
        }
    };
    
    if (!_motionTriggeredTrainingModule) {
        [self setUpMotionTriggeredColorTrainingWithCompletion:setupCompletion];
    } else {
        setupCompletion();
    }
}

- (void)startMotionTriggeredColorTraining
{
    [self setUpMotionTriggeredColorTrainingWithCompletion:nil];
    self.motionTriggeredTrainingModule.capturingPositiveTrainingData = YES;
}

- (void)startTrackingObjectWithTrainingData:(RMVisionTrainingData *)trainingData regionOfInterest:(CGRect)regionOfInterest
{
    if ([UIDevice currentDevice].isFastDevice) {
        self.Romo.vision.targetFrameRate = objectTrackingFrameRateFastDevice;
    } else {
        self.Romo.vision.targetFrameRate = objectTrackingFrameRateSlowDevice;
    }
    
#ifdef VISION_DEBUG
    self.objectTrackingModule.generateVisualization = YES;
#else
    self.objectTrackingModule.generateVisualization = NO;
#endif
    
    self.objectTrackingModule.roi = regionOfInterest;
    [self.objectTrackingModule trainWithData:trainingData];
}

- (void)stopMotionTriggeredColorTraining
{
    if (_motionTriggeredTrainingModule) {
        [self.motionTriggeredTrainingModule.vision deactivateModule:self.motionTriggeredTrainingModule];
        self.motionTriggeredTrainingModule = nil;
    }
}

- (void)stopTracking
{
    [self.heldOverHeadTimer invalidate];
    [self.notHeldOverHeadTimer invalidate];
    [self.possessionTimer invalidate];
    [self.lostPossessionTimer invalidate];
    [self.lostObjectConfirmationTimer invalidate];
    
    if (_objectTrackingModule) {
        [self.objectTrackingModule.vision deactivateModule:self.objectTrackingModule];
        self.objectTrackingModule = nil;
    }
}

#pragma mark - RMMotionTriggeredColorTrainingModuleDelegate

#ifdef VISION_DEBUG
- (void)showDebugImage:(UIImage *)debugImage
{
    [self.delegate showDebugImage:debugImage];
}
#endif

- (void)motionTriggeredTrainingModule:(RMMotionTriggeredColorTrainingModule *)module didUpdateWithProgress:(float)progress withEstimatedColor:(UIColor *)color
{
    self.trainingProgress = progress;
    self.trainingColor = color;
    [self.delegate virtualSensor:self didUpdateMotionTriggeredColorTrainingWithColor:color progress:progress];
    
    self.previousTrainingProgress = progress;
}

- (void)motionTriggeredTrainingModule:(RMMotionTriggeredColorTrainingModule *)module didFinishWithColor:(UIColor *)color withTrainingData:(RMVisionTrainingData *)trainingData
{
    [self stopMotionTriggeredColorTraining];
    
    self.trainingColor = nil;
    self.trainedColor = color;
    self.trainingData = trainingData;
    [self.delegate virtualSensor:self didFinishMotionTriggeredColorTraining:trainingData];
}

#pragma mark - RMVisionObjectTrackingModuleDelegate

- (void)objectTrackingModuleFinishedTraining:(RMVisionObjectTrackingModule *)module
{
    [self.Romo.vision activateModule:self.objectTrackingModule];
}

- (void)objectTrackingModule:(RMVisionObjectTrackingModule *)module didDetectObject:(RMBlob *)object
{
    self.object = object;
    
    if (self.sentLostMessage) {
        self.sentLostMessage = NO;
        [self.lostObjectConfirmationTimer invalidate];
        self.lostObjectConfirmationTimer = nil;
    }
    
    [self.delegate virtualSensor:self didDetectObject:object];
    
    if (objectIsOverhead(object.centroid.y)) {
        [self isHoldingOverHead];
    } else {
        [self isNotHoldingOverHead];
    }
    
    if (objectIsInPossession(object.centroid.y) && ABS(self.Romo.robot.headAngle - self.Romo.robot.minimumHeadTiltAngle) < 5.0) {
        [self hasPossession];
    } else {
        [self lostPossession];
    }
    
    self.previousPreviousCentroid = self.previousCentroid;
    self.previousCentroid = self.centroid;
    self.centroid = object.centroid;
}

- (void)objectTrackingModuleDidLoseObject:(RMVisionObjectTrackingModule *)module
{
    // Clear state
    BOOL didFlyOverHead = NO;
    [self isNotHoldingOverHead];
    [self lostPossession];
    
    // Exaggerate the x position of the centroid to indicate that the ball likely moved further in that direction
    self.lastSeenObject = self.object;
    self.lastSeenObject.centroid = CGPointMake(self.lastSeenObject.centroid.x * 1.25, self.lastSeenObject.centroid.y);
    self.object = nil;
    
    if (self.centroid.x != invalidLocation && self.previousCentroid.x != invalidLocation && self.previousPreviousCentroid.x != invalidLocation) {
        // If we just lost the object and saw it for the last three frames
        // Estimate where the centroid is based on the previous position, velocity, and acceleration of the object
        // d = d0 + vt + 0.5at^2
        CGPoint reckonedCentroid = CGPointZero;
        reckonedCentroid.x = self.centroid.x + (self.centroid.x - self.previousCentroid.x) + 0.5*((self.centroid.x - self.previousCentroid.x) - (self.previousCentroid.x - self.previousPreviousCentroid.x));
        reckonedCentroid.y = self.centroid.y + (self.centroid.y - self.previousCentroid.y) + 0.5*((self.centroid.y - self.previousCentroid.y) - (self.previousCentroid.y - self.previousPreviousCentroid.y));
        
        // Did the object go over top of us and not too far to the sides?
        didFlyOverHead = reckonedCentroid.y < -minimumFlyOverHeadY && ABS(reckonedCentroid.x) <= maximumFlyOverHeadX;
    }
    
    // Invalidate our old centroids
    self.centroid = CGPointMake(invalidLocation, invalidLocation);
    self.previousCentroid = CGPointMake(invalidLocation, invalidLocation);
    self.previousPreviousCentroid = CGPointMake(invalidLocation, invalidLocation);
    
    if (didFlyOverHead) {
        [self.delegate virtualSensorDidDetectObjectFlyOverHead:self];
    } else {
        if (!self.sentLostMessage) {
            self.sentLostMessage = YES;
            [self.delegate virtualSensorJustLostObject:self];
            
            // delay the lost confirmation by a small amount of time
            [self.lostObjectConfirmationTimer invalidate];
            self.lostObjectConfirmationTimer = [NSTimer scheduledTimerWithTimeInterval:lostObjectConfirmationDelay
                                                                                target:self
                                                                              selector:@selector(didConfirmLostObject)
                                                                              userInfo:nil
                                                                               repeats:NO];
        }
        
        [self.delegate virtualSensorFailedToDetectObject:self];
    }
}

#pragma mark - Private Properties

- (RMMotionTriggeredColorTrainingModule *)motionTriggeredTrainingModule
{
    if (!_motionTriggeredTrainingModule && self.Romo.vision) {
        _motionTriggeredTrainingModule = [[RMMotionTriggeredColorTrainingModule alloc] initWithVision:self.Romo.vision];
        _motionTriggeredTrainingModule.delegate = self;
        _motionTriggeredTrainingModule.percentOfPixelsMovingThreshold = (motionTriggeredMovingPixelPercentage / 100.0);
        _motionTriggeredTrainingModule.shouldCluster = self.shouldCluster;
        _motionTriggeredTrainingModule.capturingPositiveTrainingData = NO;
        _motionTriggeredTrainingModule.numberOfKMeansClusters = motionTriggeredClusterCount;
    }
    return _motionTriggeredTrainingModule;
}

- (RMVisionObjectTrackingModule *)objectTrackingModule
{
    if (!_objectTrackingModule && self.Romo.vision) {
        _objectTrackingModule = [[RMVisionObjectTrackingModule alloc] initWithVision:self.Romo.vision];
        _objectTrackingModule.delegate = self;
        _objectTrackingModule.allowAdaptiveBackgroundUpdates = self.allowAdaptiveBackgroundUpdates;
        _objectTrackingModule.allowAdaptiveForegroundUpdates = self.allowAdaptiveForegroundUpdates;

    }
    return _objectTrackingModule;
}

#pragma mark - Private Methods

- (void)setUpMotionTriggeredColorTrainingWithCompletion:(void (^)(void))completion
{
    if (!_motionTriggeredTrainingModule) {
        self.Romo.activeFunctionalities = enableFunctionality(RMRomoFunctionalityVision, self.Romo.activeFunctionalities);
        
        float targetFrameRate = 0;
        float maximumAccumulatedPixels = 0;
        if ([UIDevice currentDevice].isFastDevice) {
            targetFrameRate = motionTriggeredFrameRateFastDevice;
            maximumAccumulatedPixels = motionTriggeredMaximumAccumulatedPixelsFastDevice;
        } else {
            targetFrameRate = motionTriggeredFrameRateSlowDevice;
            maximumAccumulatedPixels = motionTriggeredMaximumAccumulatedPixelsSlowDevice;
        }
        self.motionTriggeredTrainingModule.triggerCountThreshold = ceilf(targetFrameRate * motionTriggeredDuration);
        self.motionTriggeredTrainingModule.maximumAccumulatedPixels = maximumAccumulatedPixels;

        self.trainingColor = [UIColor clearColor];
        self.trainingProgress = 0.0;
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            self.Romo.vision.targetFrameRate = targetFrameRate;
            [self.Romo.vision activateModule:self.motionTriggeredTrainingModule];
            
            if (completion) {
                completion();
            }
        });
    }
}

- (void)hasPossession
{
    [self.lostPossessionTimer invalidate];
    self.lostPossessionTimer = nil;
    
    if (!self.possessionTimer.isValid && !self.isPossessingObject) {
        self.possessionTimer = [NSTimer scheduledTimerWithTimeInterval:possessionConfirmationDuration
                                                                target:self
                                                              selector:@selector(didConfirmPossession:)
                                                              userInfo:nil
                                                               repeats:NO];
    }
}

- (void)lostPossession
{
    if (self.isPossessingObject) {
        self.lostPossessionTimer = [NSTimer scheduledTimerWithTimeInterval:lostPossessionConfirmationDuration
                                                                    target:self
                                                                  selector:@selector(didConfirmPossessionLost:)
                                                                  userInfo:nil
                                                                   repeats:NO];
    } else if (!self.lostPossessionTimer.isValid && self.possessionTimer.isValid) {
        self.lostPossessionTimer = [NSTimer scheduledTimerWithTimeInterval:lostPossessionCancellationDuration
                                                                    target:self
                                                                  selector:@selector(didConfirmPossessionLost:)
                                                                  userInfo:nil
                                                                   repeats:NO];
    }
}

- (void)didConfirmPossession:(NSTimer *)timer
{
    if (!self.isPossessingObject) {
        self.possessingObject = YES;
        [self.delegate virtualSensor:self didStartPossessingObject:nil];
    }
}

- (void)didConfirmPossessionLost:(NSTimer *)timer
{
    [self.possessionTimer invalidate];
    self.possessionTimer = nil;
    
    if (self.isPossessingObject) {
        self.possessingObject = NO;
        [self.delegate virtualSensor:self didStopPossessingObject:nil];
    }
}

- (void)isHoldingOverHead
{
    [self.notHeldOverHeadTimer invalidate];
    self.notHeldOverHeadTimer = nil;
    
    if (!self.heldOverHeadTimer.isValid) {
        self.heldOverHeadTimer = [NSTimer scheduledTimerWithTimeInterval:heldOverHeadDuration
                                                                  target:self
                                                                selector:@selector(didConfirmHeldOverHead:)
                                                                userInfo:nil
                                                                 repeats:NO];
    }
}

- (void)isNotHoldingOverHead
{
    if (!self.notHeldOverHeadTimer.isValid && self.heldOverHeadTimer.isValid) {
        self.notHeldOverHeadTimer = [NSTimer scheduledTimerWithTimeInterval:notHeldOverHeadDuration
                                                                     target:self
                                                                   selector:@selector(didConfirmNotHeldOverHead:)
                                                                   userInfo:nil
                                                                    repeats:NO];
    }
}

- (void)didConfirmHeldOverHead:(NSTimer *)timer
{
    [self.delegate virtualSensorDidDetectObjectHeldOverHead:self];
}

- (void)didConfirmNotHeldOverHead:(NSTimer *)timer
{
    [self.heldOverHeadTimer invalidate];
    self.heldOverHeadTimer = nil;
}

- (void)didConfirmLostObject
{
    [self.lostObjectConfirmationTimer invalidate];
    self.lostObjectConfirmationTimer = nil;
    
    [self.delegate virtualSensorDidLoseObject:self];
}

@end
