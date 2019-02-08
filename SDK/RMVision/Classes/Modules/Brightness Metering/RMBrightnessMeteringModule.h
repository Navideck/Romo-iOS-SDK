//
//  RMBrightnessMeteringModule.h
//  RMVision
//

#import "RMVisionModule.h"

@protocol RMBrightnessMeteringModuleDelegate;

@interface RMBrightnessMeteringModule : RMVisionModule

@property (nonatomic, weak) id<RMBrightnessMeteringModuleDelegate> delegate;

@property (nonatomic, readonly) RMVisionBrightnessState brightnessState;

- (void)processSampleBuffer:(CMSampleBufferRef)samplebuffer;

@end

@protocol RMBrightnessMeteringModuleDelegate <NSObject>

/**
 Delegate method that is triggered when the absolute brightness of the scene changes
 */
- (void)brightnessMeteringModule:(RMBrightnessMeteringModule *)module didDetectBrightnessChangeFromState:(RMVisionBrightnessState)previousState toState:(RMVisionBrightnessState)brightnessState;

@end