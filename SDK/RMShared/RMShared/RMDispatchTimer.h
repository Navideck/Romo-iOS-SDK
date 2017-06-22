//
//  RMDispatchTimer.h
//  Romo
//

#import <Foundation/Foundation.h>

@interface RMDispatchTimer : NSObject

/** The state of the timer */
@property (nonatomic, readonly, getter=isRunning) BOOL running;

/** The event handler to run each time the timer fires */
@property (nonatomic, copy) dispatch_block_t eventHandler;

/**
 The frequency that this timer fires at,
 e.g. 20 for 20 Hz.
 */
@property (nonatomic) double frequency;

/** The queue that the event handler is dispatched onto */
@property (nonatomic, strong, readonly) dispatch_queue_t queue;

/**
 Creates a timer that fires at the provided frequency
 on its own queue named with the provided name
 e.g. "com.Romotive.SomePerception" & 20 Hz
 */
- (id)initWithName:(NSString *)name frequency:(double)frequency;

/**
 Creates a timer that fires at the provided frequency
 on the provided queue
 */
- (id)initWithQueue:(dispatch_queue_t)queue frequency:(double)frequency;

/** Starts execution */
- (void)startRunning;

/** Stops execution */
- (void)stopRunning;

/** Manually trigger the event handler on the timer's queue */
- (void)trigger;

@end
