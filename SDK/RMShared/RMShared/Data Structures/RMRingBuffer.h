//
//  RMRingBuffer.h
//

#import <Foundation/Foundation.h>

/* --Constants-- */

/* --Data Types-- */

/* --Class Interface-- */
@interface RMRingBuffer : NSObject

/* --Public Properties-- */
@property (nonatomic, readonly) int numBufferElements; // size of buffer
@property (nonatomic, readonly) int bufferFillCount;   // how many items in buffer
@property (nonatomic, readonly) BOOL bufferFilled;     // marks full buffer

/* --Public Methods-- */
- (id) initWithCapacity:(int)numBufferElements;
- (void) addElement:(id)element;
- (id) getElement:(int)numStepsBack;   // number of steps back from newest item

@end
