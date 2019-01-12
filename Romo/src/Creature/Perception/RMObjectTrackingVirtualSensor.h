//
//  RMObjectTrackingVirtualSensor.h
//  Romo
//

#import <Foundation/Foundation.h>
#import "RMVirtualSensor.h"

@class RMVisionTrainingData;
@class RMRomo;
@class RMBlob;

@protocol RMObjectTrackingVirtualSensorDelegate;

@interface RMObjectTrackingVirtualSensor : RMVirtualSensor

@property (nonatomic, weak) id<RMObjectTrackingVirtualSensorDelegate> delegate;

/** State */
@property (nonatomic, readonly) float trainingProgress;
@property (nonatomic, readonly, strong) UIColor *trainingColor;
@property (nonatomic, readonly, strong) UIColor *trainedColor;

@property (nonatomic, readonly, strong) RMVisionTrainingData *trainingData;

@property (nonatomic, readonly, strong) RMBlob *object;
@property (nonatomic, readonly, strong) RMBlob *lastSeenObject;
@property (nonatomic, readonly, getter=isPossessingObject) BOOL possessingObject;

/** Defaults to YES */
@property (nonatomic) BOOL shouldCluster;
@property (nonatomic) BOOL allowAdaptiveBackgroundUpdates;
@property (nonatomic) BOOL allowAdaptiveForegroundUpdates;

-(void)captureNegativeTrainingDataWithCompletion:(void (^)(void))completion;

- (void)startMotionTriggeredColorTraining;
- (void)stopMotionTriggeredColorTraining;

- (void)startTrackingObjectWithTrainingData:(RMVisionTrainingData *)trainingData regionOfInterest:(CGRect)regionOfInterest;
- (void)stopTracking;

@end

@protocol RMObjectTrackingVirtualSensorDelegate <NSObject>

/** Motion-Triggered Color Training */
- (void)virtualSensor:(RMObjectTrackingVirtualSensor *)virtualSensor didUpdateMotionTriggeredColorTrainingWithColor:(UIColor *)color progress:(float)progress;
- (void)virtualSensor:(RMObjectTrackingVirtualSensor *)virtualSensor didFinishMotionTriggeredColorTraining:(RMVisionTrainingData *)trainingData;

/** Line Detection */
- (void)virtualSensor:(RMObjectTrackingVirtualSensor *)virtualSensor didDetectLineWithColor:(UIColor *)lineColor;

/** Object Tracking */
- (void)virtualSensor:(RMObjectTrackingVirtualSensor *)virtualSensor didDetectObject:(RMBlob *)object;
- (void)virtualSensorFailedToDetectObject:(RMObjectTrackingVirtualSensor *)virtualSensor;
- (void)virtualSensorJustLostObject:(RMObjectTrackingVirtualSensor *)virtualSensor;
- (void)virtualSensorDidLoseObject:(RMObjectTrackingVirtualSensor *)virtualSensor;

/** Possession */
- (void)virtualSensor:(RMObjectTrackingVirtualSensor *)virtualSensor didStartPossessingObject:(RMBlob *)object;
- (void)virtualSensor:(RMObjectTrackingVirtualSensor *)virtualSensor didStopPossessingObject:(RMBlob *)object;

/** Object Tracking Events */
- (void)virtualSensorDidDetectObjectHeldOverHead:(RMObjectTrackingVirtualSensor *)virtualSensor;
- (void)virtualSensorDidDetectObjectFlyOverHead:(RMObjectTrackingVirtualSensor *)virtualSensor;

#ifdef VISION_DEBUG
- (void)showDebugImage:(UIImage *)debugImage;
#endif

@end
