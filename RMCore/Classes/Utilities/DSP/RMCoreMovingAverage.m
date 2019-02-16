//
//  RMCoreMovingAverage.m
//  Romo3
//
//  Created on 2/11/13.
//  Copyright (c) 2013 Romotive. All rights reserved.

#import "RMCoreMovingAverage.h"

#pragma mark - "private interface"

@interface RMCoreMovingAverageSimple()
{
    int _windowSize;       // size of the moving average windows (in datapoints)
    double _filterValue;   // the most up-to-date value of the filter
    BOOL _filterReset;     // flag noting that filter history has been cleared
    double *_data;         // filter's FIFO data buffer
    double *_moveBuffer;   // temp buffer for shifting data in data buffer
    int _dataFillCounter;  // tracks how many pieces of have been put in buffer
    
    // block handler, to be used for getting new data into the filter
    RMCoreMovingAverageInputSourceHandler _inputDataHandler;
    
    // queue used to execute controller update, and timer used to trigger those
    // updates
    dispatch_queue_t _movingAverageQueue;
    dispatch_source_t _movingAverageTimer;
}

#pragma mark - "private" methods

// generate new filter instance (by internal call)
- (id) initWithFrequency:(float)updateRate
              windowSize:(int)windowSize
             inputSource:(RMCoreMovingAverageInputSourceHandler)inputSourceHandler;

// process new data
- (void) updateFilter;

@end

#pragma mark - class implementation

/* --Class Implementation-- */
@implementation RMCoreMovingAverageSimple

// generate new filter instance (by internal call)
- (id) initWithFrequency:(float)updateRate
              windowSize:(int)windowSize
             inputSource:(RMCoreMovingAverageInputSourceHandler)inputSourceHandler
{
    self = [super init];
    
    if (self)
    {
        // copy in properties
        _filterFrequency = updateRate;
        _windowSize = windowSize;
        _inputDataHandler = inputSourceHandler;
        
        // create a queue on which this filter will run
        _movingAverageQueue = dispatch_queue_create(
                     "com.romotive.MovingAverageQueue", DISPATCH_QUEUE_SERIAL );
        
        // create trigger source for filter updates (using a timer)
        _movingAverageTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,
                                                     0, 0,
                                                    _movingAverageQueue );
        
        // calculate filter period
        double timerIntervalInNanoseconds = 1.0E9/_filterFrequency;
        
        // create timer
        dispatch_source_set_timer(_movingAverageTimer,
                                  dispatch_time(DISPATCH_TIME_NOW, 0),
                                  timerIntervalInNanoseconds,
                                  LEEWAY_PERCENTAGE * timerIntervalInNanoseconds );
        
        __weak RMCoreMovingAverageSimple *weakSelf = self;
        dispatch_source_set_event_handler(_movingAverageTimer, ^{
            [weakSelf updateFilter];
        });
        
        // allocate memory and enable the filter
        _data = (double *)malloc(_windowSize * sizeof(*_data));
        _moveBuffer = (double *)malloc(_windowSize * sizeof(*_moveBuffer));
        [self resetFilter];
        [self enableFilter];
        // NOTE: replace this group of code with call to [self newWindowSize];
        //       when that method is brought online
    }
    
    return self;
}

// deallocation
- (void) dealloc
{
    // release filter data memeory
    free(_data);
    _data = NULL;
    
    free(_moveBuffer);
    _moveBuffer = NULL;

    // make sure the timer is stopped
    dispatch_source_cancel(_movingAverageTimer);
}

#pragma mark - factory methods

// generate new filter instance (by external call)
+ (id) createFilterWithFrequency: (float)updateRate windowSize:(int)windowSize
             inputSource:(RMCoreMovingAverageInputSourceHandler)inputSourceHandler
{
    return [[RMCoreMovingAverageSimple alloc] initWithFrequency:updateRate
                                                 windowSize:windowSize
                                                inputSource:inputSourceHandler];
}

// activate filter
- (void) enableFilter
{
    if (!self.isEnabled)
    {
        // turn on timer that triggers data acquisition & filter update
        dispatch_resume(_movingAverageTimer);
        _enabled = YES;
    }
}

// deactivate filter
- (void) disableFilter
{
    if (self.isEnabled)
    {
        // turn off timer that triggers data acquisition & filter update
        dispatch_suspend(_movingAverageTimer);
        _enabled = NO;
    }
}

// flag to trigger filter history overwrite
- (void) resetFilter
{
    _filterReset = YES;
}

// NOTE: THIS METHOD NEEDS TO USE A LOCK TO PREVENT BAD DATA ACCESS FROM
//       updateFilter. I WILL TAKE CARE OF THIS IN VERSION 2 OF THIS CLASS
//
//- (void) newWindowSize:(int)windowSize
//{
//    [self disableFilter];
//
//    _windowSize = windowSize;
//
//    free(_data);
//    free(_moveBuffer);
//    
//    _data = (double *)malloc(_windowSize * sizeof(*_data));
//    _moveBuffer = (double *)malloc(_windowSize * sizeof(*_moveBuffer));
//
//    [self resetFilter];
//    [self enableFilter];
//}

// acquire and update the latest value of the filter
- (void) updateFilter
{
    double newData = _inputDataHandler();   // get new piece of data

    // set up to overwrite data bufefr
    if (_filterReset)
    {
        _dataFillCounter = 0;
        _filterReset = NO;
    }
    
    // initialize data buffer
    if (_dataFillCounter < _windowSize)
    {
        // perform straight average until buffer is full
        _filterValue = ((_filterValue * _dataFillCounter) + newData) /
                                                         (_dataFillCounter + 1);
        // load into data buffer
        *(_data + _dataFillCounter) = newData;

        // update index
        _dataFillCounter++;
    }
    // apply simple moving average filter
    else
    {
        // update filter value
        _filterValue = _filterValue + ((newData - *_data)/_windowSize);
        
        // convenience variables for enforcing FIFO buffer
        int lastIndex = _windowSize - 1;            // index of last data item
        int numBytes = lastIndex * sizeof(*_data);  // number of bytes to move
        
        // slide data over in FIFO fashion
        memcpy(_moveBuffer, (_data+1), numBytes);
        memcpy(_data, _moveBuffer, numBytes);
        
        // track on new piece of data
        *(_data + lastIndex) = newData;
    }
}

// give access to the most up-to-date data value
- (double) getFilterValue
{
    return _filterValue;
}

@end
