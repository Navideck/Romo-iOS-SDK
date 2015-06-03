//
//  RMDispatchTimer.m
//  Romo
//

#import "RMDispatchTimer.h"

static const float timerLeeway = NSEC_PER_MSEC;

@interface RMDispatchTimer ()

@property (nonatomic, readwrite, getter=isRunning) BOOL running;
@property (nonatomic, strong) dispatch_source_t timer;
@property (nonatomic, strong, readwrite) dispatch_queue_t queue;

@end

@implementation RMDispatchTimer

- (id)initWithName:(NSString *)name frequency:(double)frequency
{
    return [self initWithQueue:dispatch_queue_create(name.UTF8String, 0) frequency:frequency];
}

- (id)initWithQueue:(dispatch_queue_t)queue frequency:(double)frequency
{
    self = [super init];
    if (self) {
        _frequency = frequency;
        _queue = queue;
    }
    return self;
}

- (void)startRunning
{
    @synchronized(self) {
        if (!self.isRunning && self.eventHandler) {
            dispatch_resume(self.timer);
            self.running = YES;
        }
    }
}

- (void)stopRunning
{
    @synchronized(self) {
        if (self.isRunning) {
            dispatch_suspend(self.timer);
            self.running = NO;
        }
    }
}

- (void)trigger
{
    if (self.eventHandler) {
        dispatch_async(self.queue, self.eventHandler);
    }
}

- (void)setEventHandler:(dispatch_block_t)eventHandler
{
    _eventHandler = eventHandler;
    dispatch_source_set_event_handler(self.timer, eventHandler);
}

- (void)setFrequency:(double)frequency
{
    if (frequency != _frequency) {
        _frequency = frequency;
        dispatch_source_set_timer(self.timer, DISPATCH_TIME_NOW, NSEC_PER_SEC / self.frequency, timerLeeway);
    }
}

- (void)dealloc
{
    if (_timer) {
        if (!self.isRunning) {
            dispatch_resume(self.timer);
        }
        dispatch_source_cancel(self.timer);
    }
}

#pragma mark - Private Properties

- (dispatch_source_t)timer
{
    if (!_timer && self.eventHandler) {
        _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.queue);
        dispatch_source_set_timer(_timer, DISPATCH_TIME_NOW, NSEC_PER_SEC / self.frequency, timerLeeway);
        dispatch_source_set_event_handler(_timer, self.eventHandler);
    }
    return _timer;
}

@end
