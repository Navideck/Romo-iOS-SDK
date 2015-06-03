//
//  RMMotionDetectionModule.h
//  RMVision
//

#import "RMVisionModuleProtocol.h"
#import "GPUImage.h"

@protocol RMMotionDetectionModuleDelegate;

@interface RMMotionDetectionModule : GPUImageFilterGroup <RMVisionModuleProtocol>

@property (nonatomic, weak) id<RMMotionDetectionModuleDelegate> delegate;

@property (nonatomic, readonly, getter=isDetectingMotion) BOOL detectingMotion;

/** 
 The number of consecutive frames with motion to trigger
 Higher leads to a less-sensitive trigger, best for larger, long-term motion
 This value is tuned for 24 fps and scaled for other framerates
 Defaults to 5
 */
@property (nonatomic) int minimumConsecutiveTriggerCount;

/**
 What percentage of pixels must be moving for this to trigger?
 Higher is less sensitive and requires more motion
 On [0, 100]
 Defaults to 2.5
 */
@property (nonatomic) float minimumPercentageOfPixelsMoving;

@end

@protocol RMMotionDetectionModuleDelegate <NSObject>

/** Start of motion */
- (void)motionDetectionModuleDidDetectMotion:(RMMotionDetectionModule *)module;

/** End of motion */
- (void)motionDetectionModuleDidDetectEndOfMotion:(RMMotionDetectionModule *)module;

@end