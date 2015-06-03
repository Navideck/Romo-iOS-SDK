//
//  RMStasisVirtualSensor.h
//  Romo
//

#import <Foundation/Foundation.h>
#import "RMVirtualSensor.h"

@class RMRomo;

@protocol RMStasisVirtualSensorDelegate;

@interface RMStasisVirtualSensor : RMVirtualSensor

@property (nonatomic, weak) id<RMStasisVirtualSensorDelegate> delegate;

@property (nonatomic, readonly, getter=isInStasis) BOOL inStasis;

- (void)beginGeneratingStasisNotifications;
- (void)finishGeneratingStasisNotifications;

@end

@protocol RMStasisVirtualSensorDelegate <NSObject>

/** Stasis */
- (void)virtualSensorDidDetectStasis:(RMStasisVirtualSensor *)stasisVirtualSensor;
- (void)virtualSensorDidLoseStasis:(RMStasisVirtualSensor *)stasisVirtualSensor;

@end