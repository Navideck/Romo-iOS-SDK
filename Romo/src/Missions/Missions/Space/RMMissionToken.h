//
//  RMMissionToken.h
//  Romo
//

#import <UIKit/UIKit.h>
#import "RMProgressManager.h"

@interface RMMissionToken : UIView

@property (nonatomic, readonly) int index;
@property (nonatomic, readonly) RMMissionStatus status;

- (id)initWithChapter:(RMChapter)chapter index:(int)index status:(RMMissionStatus)status;

- (void)startAnimating;
- (void)stopAnimating;

@end
