//
//  RMDurationInputDigit.h
//  Romo
//

#import <UIKit/UIKit.h>

@protocol RMScrollingInputDelegate;

@interface RMScrollingInput : UIScrollView <UIScrollViewDelegate>

@property (nonatomic, weak) id<RMScrollingInputDelegate> inputDelegate;
@property (nonatomic, copy) NSArray *values;
@property (nonatomic) NSString *value;

@end

@protocol RMScrollingInputDelegate <NSObject>

- (void)digit:(RMScrollingInput *)digit didChangeToValue:(NSString *)value;

@end