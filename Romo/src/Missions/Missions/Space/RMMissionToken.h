//
//  RMMissionToken.h
//  Romo
//

#import <UIKit/UIKit.h>
#import "RMProgressManager.h"

@interface RMMissionToken : UIView

@property (nonatomic, readonly) NSInteger index;
@property (nonatomic, readonly) RMMissionStatus status;

- (id)initWithChapter:(RMChapter)chapter index:(NSInteger)index status:(RMMissionStatus)status;

- (void)startAnimating;
- (void)stopAnimating;

@end
