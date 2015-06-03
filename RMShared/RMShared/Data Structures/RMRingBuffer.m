//
//  RMRingBuffer.m
//  Romo
//

#import "RMRingBuffer.h"

/* --Private Interface-- */
@interface RMRingBuffer()

@property (nonatomic, strong) NSMutableArray *buffer;
@property (nonatomic) int currentIndex;   // marks freshest piece item
@property (nonatomic) int lastIndex;      // in linear memory (not dependent on
                                          // value of currentIndex)
@end

/* --Class Implementation-- */
@implementation RMRingBuffer

- (id) initWithCapacity:(int)numBufferElements
{
    // init superclass
    self = [super init];
    
    if (self)
    {
        _currentIndex = -1;
        _numBufferElements = numBufferElements;
        _lastIndex = numBufferElements - 1;
        _bufferFillCount = 0;
        _bufferFilled = NO;

        _buffer = [[NSMutableArray alloc] initWithCapacity:_numBufferElements];
    }
    
    return self;
}

#pragma mark - Data Access

// Add new item to buffer
- (void) addElement:(id)element
{
    // increment index w/ wrapping
    self.currentIndex++;
    if(self.currentIndex > self.lastIndex)
    {
        self.currentIndex = 0;
    }
    
    // add new data
    if(self.bufferFilled == NO)
    {
        [self.buffer setObject:element atIndexedSubscript:self.currentIndex];
    }
    else
    {
        [self.buffer replaceObjectAtIndex:self.currentIndex withObject:element];
    }

    // update data count (if necessary)
    if(_bufferFilled == NO)
    {
        _bufferFillCount++;
        if(self.bufferFillCount == self.numBufferElements)
        {
            _bufferFilled = YES;
        }
    }	
}

// Retrieve item numStepsBack from freshest item
// (note: numStepsBack should be a positive number)
- (id) getElement:(int)numStepsBack
{
    int index = self.currentIndex - numStepsBack;

    // wrap back past zero index
    while(index < 0)
    {
        index += self.numBufferElements;
    }
    
    if(index < self.bufferFillCount)
    {
        // return requested data
        return self.buffer[index];
    }
    else if(self.bufferFillCount == 0)
    {
        // ring buffer has no data
        return nil;
    }
    else
    {
        // ring buffer isn't filled enough yet, doesn't have the requested
        // piece of data; return the oldest data available instead
        return self.buffer[0];
    }
}

@end