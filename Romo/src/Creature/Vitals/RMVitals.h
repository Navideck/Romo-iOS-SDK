//
//  RMVitals.h
//  Romo
//

#import <Foundation/Foundation.h>

@protocol RMVitalsDelegate;

 typedef enum {
    RMVitalsWakefulnessAwake         = 1,
    RMVitalsWakefulnessSleepy        = 2,
    RMVitalsWakefulnessAsleep        = 3,
} RMVitalsWakefulness;

@protocol RMVitalsDelegate;

@interface RMVitals : NSObject

@property (nonatomic, weak) id<RMVitalsDelegate> delegate;

@property (nonatomic, readonly) RMVitalsWakefulness wakefulness;
@property (nonatomic, readonly) float odometer; // Distance in mm
@property (nonatomic, getter=isWakefulnessEnabled) BOOL wakefulnessEnabled;

/** If a significant-enough event happens, wake Romo up */
- (void)wakeUp;

/** Romo becomes sleepy on his own, but you can accelerate this process */
- (void)becomeSleepy;

@end

@protocol RMVitalsDelegate <NSObject>

@optional

- (void)robotDidChangeWakefulness:(RMVitalsWakefulness)wakefulness;

@end